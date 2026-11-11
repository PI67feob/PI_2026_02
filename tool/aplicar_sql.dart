import 'dart:io';

import 'package:caderno_fazenda/exceptions/agrogestor_exception.dart';
import 'package:caderno_fazenda/exceptions/persistencia_exception.dart';
import 'package:caderno_fazenda/repositories/configuracao_banco.dart';
import 'package:caderno_fazenda/repositories/mysql/conexao_mysql.dart';

/// Executa um arquivo `.sql` no MySQL da AWS, comando por comando.
///
/// Serve para o que o Workbench não roda bem, como os triggers (que usam
/// `DELIMITER`). Entende `DELIMITER`, comentários (`--`, `#` e `/* */`) e
/// textos entre aspas, então roda o arquivo do jeito que ele está.
///
/// Criar triggers e tabelas exige mais permissões do que o usuário do
/// aplicativo tem. Por isso o script conecta como administrador (`admin`, ou o
/// que estiver em `DB_ADMIN_USER`) e pede a senha no terminal, sem mostrá-la.
/// A senha não é gravada em lugar nenhum. Host, porta e nome do banco vêm das
/// mesmas variáveis `DB_*` do `.env`.
///
/// Uso, na raiz do projeto e com as variáveis do `.env` exportadas:
///
/// ```
/// dart run tool/aplicar_sql.dart triggers.local.sql
/// ```
///
/// O arquivo roda até o primeiro erro e para. Comandos `DROP DATABASE` e
/// `DROP SCHEMA` são recusados, a menos que se passe `--permitir-drop-database`.
Future<void> main(List<String> argumentos) async {
  final permitirDrop = argumentos.contains('--permitir-drop-database');
  final caminhos = argumentos.where((a) => !a.startsWith('--')).toList();
  if (caminhos.length != 1) {
    stderr.writeln(
      'Uso: dart run tool/aplicar_sql.dart <arquivo.sql> '
      '[--permitir-drop-database]',
    );
    exitCode = 64;
    return;
  }
  final arquivo = File(caminhos.single);
  if (!arquivo.existsSync()) {
    stderr.writeln('Arquivo não encontrado: ${arquivo.path}');
    exitCode = 66;
    return;
  }

  final comandos = _dividirSql(arquivo.readAsStringSync());
  if (comandos.isEmpty) {
    stderr.writeln('O arquivo não tem nenhum comando SQL.');
    exitCode = 65;
    return;
  }
  if (!permitirDrop && comandos.any(_dropBanco.hasMatch)) {
    stderr.writeln(
      'Recusado: o arquivo tem DROP DATABASE ou DROP SCHEMA, que apagaria o '
      'banco inteiro. Nada foi executado.\n'
      'Se é isso mesmo que você quer, rode de novo com '
      '--permitir-drop-database.',
    );
    exitCode = 1;
    return;
  }

  ConexaoMysql? banco;
  try {
    final base = ConfiguracaoBanco.doAmbiente();
    final usuario = Platform.environment['DB_ADMIN_USER'] ?? 'admin';
    final senha = _pedirSenha(usuario);
    if (senha.isEmpty) {
      stderr.writeln('Senha vazia. Nada foi executado.');
      exitCode = 1;
      return;
    }

    banco = await ConexaoMysql.abrir(
      ConfiguracaoBanco(
        host: base.host,
        porta: base.porta,
        nomeBanco: base.nomeBanco,
        usuario: usuario,
        senha: senha,
      ),
    );
    stdout.writeln(
      'Conectado como $usuario em ${base.host}. '
      '${comandos.length} comandos para executar.\n',
    );

    for (var i = 0; i < comandos.length; i++) {
      final comando = comandos[i];
      stdout.writeln('[${i + 1}/${comandos.length}] ${_resumo(comando)}');
      try {
        await banco.usar(
          'executar o comando ${i + 1}',
          (conexao) => conexao.execute(comando),
        );
      } on PersistenciaException catch (erro) {
        stderr.writeln('\nFALHOU no comando ${i + 1}: ${erro.causa}');
        exitCode = 1;
        return;
      }
    }

    await banco.usar('conferir os triggers', (conexao) async {
      final resultado = await conexao.execute(
        'SELECT COUNT(1) AS triggers FROM information_schema.triggers '
        'WHERE trigger_schema = DATABASE()',
      );
      for (final linha in resultado.rows) {
        final total = linha.assoc()['triggers'];
        stdout.writeln('\nOK. Triggers no schema ${base.nomeBanco}: $total');
      }
    });
  } on PersistenciaException catch (erro) {
    stderr.writeln('\nFALHOU: ${erro.mensagem}');
    stderr.writeln('Causa técnica: ${erro.causa}');
    exitCode = 1;
  } on AgroGestorException catch (erro) {
    stderr.writeln('\nFALHOU: $erro');
    exitCode = 1;
  } finally {
    await banco?.fechar();
  }
}

final _dropBanco = RegExp(r'^DROP\s+(DATABASE|SCHEMA)\b', caseSensitive: false);

/// Primeira linha do [comando], cortada para caber na tela.
String _resumo(String comando) {
  final primeira = comando.split('\n').first.trim();
  return primeira.length > 70 ? '${primeira.substring(0, 67)}...' : primeira;
}

/// Lê a senha no terminal sem mostrar o que é digitado.
String _pedirSenha(String usuario) {
  stdout.write('Senha do usuário $usuario (não aparece ao digitar): ');
  final temTerminal = stdin.hasTerminal;
  try {
    if (temTerminal) {
      stdin.echoMode = false;
    }
    return stdin.readLineSync() ?? '';
  } finally {
    if (temTerminal) {
      stdin.echoMode = true;
    }
    stdout.writeln();
  }
}

/// Divide o texto de um arquivo SQL em comandos.
///
/// Respeita o comando `DELIMITER` (usado nos triggers), textos entre aspas
/// simples, duplas ou crases, e remove os comentários. Comandos vazios são
/// descartados.
List<String> _dividirSql(String texto) {
  final comandos = <String>[];
  final atual = StringBuffer();
  final fimDoTexto = texto.length;
  final comandoDelimiter = RegExp(r'delimiter[ \t]', caseSensitive: false);
  var delimitador = ';';
  var i = 0;

  void fecharComando() {
    final comando = atual.toString().trim();
    if (comando.isNotEmpty) {
      comandos.add(comando);
    }
    atual.clear();
  }

  // Verdadeiro se, da última quebra de linha até a posição i, só há espaços.
  bool noInicioDaLinha(int posicao) {
    for (var k = posicao - 1; k >= 0 && texto[k] != '\n'; k--) {
      if (texto[k] != ' ' && texto[k] != '\t' && texto[k] != '\r') {
        return false;
      }
    }
    return true;
  }

  while (i < fimDoTexto) {
    final c = texto[i];

    // "DELIMITER $$": comando do cliente, não vai para o servidor.
    if ((c == 'd' || c == 'D') &&
        atual.toString().trim().isEmpty &&
        noInicioDaLinha(i) &&
        texto.startsWith(comandoDelimiter, i)) {
      var fimDaLinha = texto.indexOf('\n', i);
      if (fimDaLinha == -1) {
        fimDaLinha = fimDoTexto;
      }
      final novo = texto.substring(i + 'delimiter'.length, fimDaLinha).trim();
      if (novo.isNotEmpty) {
        delimitador = novo;
      }
      i = fimDaLinha;
      continue;
    }

    // Comentário de linha: "-- " (com espaço ou fim de linha depois) ou "#".
    final doisTracos =
        c == '-' &&
        texto.startsWith('--', i) &&
        (i + 2 >= fimDoTexto || ' \t\r\n'.contains(texto[i + 2]));
    if (c == '#' || doisTracos) {
      var fimDaLinha = texto.indexOf('\n', i);
      if (fimDaLinha == -1) {
        fimDaLinha = fimDoTexto;
      }
      i = fimDaLinha;
      continue;
    }

    // Comentário de bloco (menos os executáveis, que começam com "/*!").
    if (c == '/' && texto.startsWith('/*', i) && !texto.startsWith('/*!', i)) {
      final fim = texto.indexOf('*/', i + 2);
      i = fim == -1 ? fimDoTexto : fim + 2;
      atual.write(' ');
      continue;
    }

    // Texto entre aspas: copia inteiro, sem procurar o delimitador dentro.
    if (c == "'" || c == '"' || c == '`') {
      var j = i + 1;
      while (j < fimDoTexto) {
        final d = texto[j];
        if (d == r'\' && c != '`') {
          j += 2;
          continue;
        }
        if (d == c) {
          if (j + 1 < fimDoTexto && texto[j + 1] == c) {
            j += 2;
            continue;
          }
          break;
        }
        j++;
      }
      final fim = j < fimDoTexto ? j + 1 : fimDoTexto;
      atual.write(texto.substring(i, fim));
      i = fim;
      continue;
    }

    if (texto.startsWith(delimitador, i)) {
      fecharComando();
      i += delimitador.length;
      continue;
    }

    atual.write(c);
    i++;
  }
  fecharComando();
  return comandos;
}
