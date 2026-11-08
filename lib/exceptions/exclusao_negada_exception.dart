import 'package:caderno_fazenda/exceptions/agrogestor_exception.dart';

/// Lançada quando um registro não pode ser excluído porque outros registros
/// dependem dele (por exemplo, um talhão que já foi usado numa aplicação, ou
/// uma área que ainda tem talhões).
///
/// Excluir assim deixaria aplicações apontando para algo que não existe mais.
/// Por isso o sistema recusa e diz o que precisa ser excluído antes.
///
/// Mensagem: `Exclusão negada: <registro> (<motivo>)`.
/// Exemplo: `Exclusão negada: talhão Chico1 (usado na aplicação 3; exclua-a
/// antes)`.
class ExclusaoNegadaException extends AgroGestorException {
  /// O registro que não pôde ser excluído (ex.: `talhão Chico1`).
  final String registro;

  /// Por que a exclusão foi recusada.
  final String motivo;

  /// Cria a exceção com o [registro] que seria excluído e o [motivo] da
  /// recusa.
  ExclusaoNegadaException(this.registro, this.motivo)
    : super('Exclusão negada: $registro ($motivo)');
}
