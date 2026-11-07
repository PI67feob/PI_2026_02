import 'package:caderno_fazenda/exceptions/agrogestor_exception.dart';

/// Lançada pelos repositórios quando falha a comunicação com o banco de dados.
///
/// Esconde o erro técnico do MySQL: a [mensagem] mostra só a operação que
/// falhou, e o erro original fica guardado em [causa] para log/depuração.
///
/// Mensagem: `Erro de persistência: <operação>`.
/// Exemplo: `Erro de persistência: salvar talhão`.
class PersistenciaException extends AgroGestorException {
  /// Operação que estava sendo feita no banco (ex.: `salvar talhão`).
  final String operacao;

  /// Erro técnico original (ex.: exceção do driver MySQL). Não aparece na
  /// mensagem para o usuário.
  final Object? causa;

  /// Cria a exceção com a [operacao] que falhou e, opcionalmente, a [causa]
  /// técnica.
  PersistenciaException(this.operacao, {this.causa})
    : super('Erro de persistência: $operacao');
}
