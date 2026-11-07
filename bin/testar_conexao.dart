import 'dart:io';

import 'package:caderno_fazenda/exceptions/agrogestor_exception.dart';
import 'package:caderno_fazenda/exceptions/persistencia_exception.dart';
import 'package:caderno_fazenda/repositories/configuracao_banco.dart';
import 'package:caderno_fazenda/repositories/mysql/conexao_mysql.dart';

/// Testa só a conexão com o MySQL, sem tocar em nenhum dado.
///
/// Antes de rodar, exporte as variáveis do `.env` e deixe o
/// `global-bundle.pem` na raiz do projeto:
///
/// ```
/// set -a; source .env; set +a
/// dart run bin/testar_conexao.dart
/// ```
///
/// Se der certo, mostra a versão do servidor, o usuário e as tabelas que ele
/// enxerga. Se falhar, mostra o erro técnico (que a aplicação normal esconde).
Future<void> main() async {
  ConexaoMysql? banco;
  try {
    final config = ConfiguracaoBanco.doAmbiente();
    print('Conectando: $config');

    banco = await ConexaoMysql.abrir(config);
    print('Conexão aberta com TLS.');

    await banco.usar('consultar o servidor', (conexao) async {
      final info = await conexao.execute(
        'SELECT VERSION() AS versao, CURRENT_USER() AS usuario, '
        'DATABASE() AS banco',
      );
      for (final linha in info.rows) {
        print('Servidor: ${linha.assoc()}');
      }

      final tabelas = await conexao.execute(
        'SELECT COUNT(1) AS tabelas FROM information_schema.tables '
        'WHERE table_schema = DATABASE()',
      );
      for (final linha in tabelas.rows) {
        print('Tabelas no schema: ${linha.assoc()} (esperado: 11)');
      }
    });
    print('OK: tudo certo com a conexão.');
  } on PersistenciaException catch (erro) {
    stderr.writeln('FALHOU: ${erro.mensagem}');
    stderr.writeln('Erro técnico: ${erro.causa}');
    exitCode = 1;
  } on AgroGestorException catch (erro) {
    stderr.writeln('FALHOU: ${erro.mensagem}');
    exitCode = 1;
  } finally {
    await banco?.fechar();
  }
}
