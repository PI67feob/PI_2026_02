import 'dart:io';

import 'package:caderno_fazenda/cli/menu_caderno.dart';
import 'package:caderno_fazenda/cli/terminal.dart';
import 'package:caderno_fazenda/exceptions/agrogestor_exception.dart';
import 'package:caderno_fazenda/exceptions/persistencia_exception.dart';
import 'package:caderno_fazenda/repositories/configuracao_banco.dart';
import 'package:caderno_fazenda/repositories/mysql/conexao_mysql.dart';
import 'package:caderno_fazenda/repositories/repositorios.dart';

/// Menu interativo do Caderno de Campo.
///
/// Sem argumento (`dart run bin/caderno.dart`), usa os repositórios em memória:
/// não precisa de banco, mas tudo o que for cadastrado some quando o programa
/// termina. Com `--mysql` (`dart run bin/caderno.dart --mysql`), lê e grava no
/// MySQL da AWS: as variáveis `DB_*` precisam estar exportadas e o
/// `global-bundle.pem` na raiz do projeto (veja `.env.example` e o README).
///
/// Todo o menu está em `lib/cli/`. Este arquivo só escolhe de onde vêm os
/// dados, abre e fecha a conexão e entrega o teclado e a tela ao menu.
Future<void> main(List<String> argumentos) async {
  final desconhecidos = argumentos.where(
    (argumento) => !_argumentosConhecidos.contains(argumento),
  );
  if (desconhecidos.isNotEmpty) {
    stderr.writeln('Argumento desconhecido: ${desconhecidos.join(' ')}\n');
    stderr.writeln(_ajuda);
    exitCode = 64;
    return;
  }
  if (argumentos.contains('--ajuda') || argumentos.contains('-h')) {
    stdout.writeln(_ajuda);
    return;
  }

  const terminal = TerminalConsole();
  // A pausa "Aperte Enter" só faz sentido com uma pessoa na frente da tela:
  // com as respostas vindas de um arquivo ou de um pipe, ela só atrapalharia.
  final pausas = stdin.hasTerminal && !argumentos.contains('--sem-pausa');
  if (!argumentos.contains('--mysql')) {
    await MenuCaderno(
      Repositorios.memoria(),
      terminal,
      pausas: pausas,
    ).executar();
    return;
  }

  ConexaoMysql? banco;
  try {
    stdout.writeln('Conectando ao MySQL...');
    banco = await ConexaoMysql.abrir(ConfiguracaoBanco.doAmbiente());
    stdout.writeln('Conectado.\n');
    await MenuCaderno(
      Repositorios.mysql(banco),
      terminal,
      pausas: pausas,
    ).executar();
  } on PersistenciaException catch (erro) {
    stderr.writeln('\nFALHOU: ${erro.mensagem}');
    stderr.writeln('Causa técnica: ${erro.causa}');
    stderr.writeln(_dicaDeConexao);
    exitCode = 1;
  } on AgroGestorException catch (erro) {
    stderr.writeln('\nFALHOU: $erro');
    stderr.writeln(_dicaDeConexao);
    exitCode = 1;
  } finally {
    await banco?.fechar();
  }
}

const _argumentosConhecidos = {'--mysql', '--sem-pausa', '--ajuda', '-h'};

const _dicaDeConexao =
    'Confira as variáveis DB_HOST, DB_PORT, DB_NAME, DB_USER e DB_PASSWORD, '
    'o arquivo global-bundle.pem na raiz do projeto e se o seu IP está '
    'liberado no banco (README, "Rodando no MySQL").';

const _ajuda = '''
Menu do Caderno de Campo.

Uso:
  dart run bin/caderno.dart           dados em memória (somem ao sair)
  dart run bin/caderno.dart --mysql   dados no MySQL da AWS
  dart run bin/caderno.dart --ajuda   mostra esta mensagem

Opção extra:
  --sem-pausa   não espera o Enter depois de cada opção do menu

No menu, digite o número da opção e Enter. Em qualquer pergunta, Enter sem
escrever nada cancela ou pula o campo opcional. Depois de cada opção o
programa espera um Enter, para dar tempo de ler o resultado (só quando o
teclado está ligado; com as respostas vindas de um arquivo não espera).''';
