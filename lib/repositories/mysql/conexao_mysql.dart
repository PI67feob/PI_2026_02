import 'dart:io';

import 'package:caderno_fazenda/exceptions/agrogestor_exception.dart';
import 'package:caderno_fazenda/exceptions/persistencia_exception.dart';
import 'package:caderno_fazenda/repositories/configuracao_banco.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';

/// Conexão com o MySQL (AWS RDS) compartilhada pelos repositórios MySQL.
///
/// Abre a conexão com TLS, conferindo o certificado do servidor contra o
/// `global-bundle.pem` (a lista pública de certificados da AWS). Os dados de
/// acesso vêm de [ConfiguracaoBanco], que lê só variáveis de ambiente: nenhuma
/// senha fica escrita no código.
///
/// Todo erro do driver vira [PersistenciaException]. O erro técnico original
/// fica em `causa`, para depuração, e não aparece na mensagem.
class ConexaoMysql {
  final MySQLConnection _conexao;

  ConexaoMysql._(this._conexao);

  /// Caminho padrão do certificado, relativo à pasta de onde o programa roda
  /// (a raiz do projeto, com `dart run`).
  static const certificadoPadrao = 'global-bundle.pem';

  /// Abre a conexão com o banco descrito em [config].
  ///
  /// O [certificado] é o arquivo PEM com as autoridades certificadoras da AWS.
  /// Lança [PersistenciaException] se o arquivo não existir, se o servidor não
  /// responder (IP não liberado no security group, por exemplo) ou se o
  /// usuário/senha forem recusados.
  static Future<ConexaoMysql> abrir(
    ConfiguracaoBanco config, {
    String certificado = certificadoPadrao,
  }) async {
    try {
      final contexto = SecurityContext()..setTrustedCertificates(certificado);
      final conexao = await MySQLConnection.createConnection(
        host: config.host,
        port: config.porta,
        userName: config.usuario,
        password: config.senha,
        databaseName: config.nomeBanco,
        securityContext: contexto,
      );
      await conexao.connect();
      return ConexaoMysql._(conexao);
    } catch (erro) {
      throw PersistenciaException('conectar ao banco', causa: erro);
    }
  }

  /// Roda [acao] com a conexão aberta e traduz os erros do driver.
  ///
  /// [operacao] diz o que estava sendo feito (ex.: `salvar área`) e vai para a
  /// mensagem da [PersistenciaException]. Exceções do próprio projeto
  /// ([AgroGestorException], como `RegistroNaoEncontradoException`) passam
  /// sem alteração.
  Future<T> usar<T>(
    String operacao,
    Future<T> Function(MySQLConnection conexao) acao,
  ) async {
    try {
      return await acao(_conexao);
    } on AgroGestorException {
      rethrow;
    } catch (erro) {
      throw PersistenciaException(operacao, causa: erro);
    }
  }

  /// Fecha a conexão. Chame ao terminar o programa.
  Future<void> fechar() async {
    try {
      await _conexao.close();
    } catch (erro) {
      throw PersistenciaException('fechar a conexão', causa: erro);
    }
  }
}
