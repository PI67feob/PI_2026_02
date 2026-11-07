import 'package:caderno_fazenda/exceptions/agrogestor_exception.dart';

/// Lançada quando um registro pedido pelo id não existe (por exemplo, uma
/// aplicação que aponta para um talhão que não foi cadastrado).
///
/// Mensagem: `Registro não encontrado: <entidade> <id>`.
/// Exemplo: `Registro não encontrado: talhão 99`.
class RegistroNaoEncontradoException extends AgroGestorException {
  /// Nome da entidade procurada (ex.: `talhão`, `insumo`).
  final String entidade;

  /// Id que não foi encontrado.
  final int id;

  /// Cria a exceção com a [entidade] procurada e o [id] que não existe.
  RegistroNaoEncontradoException(this.entidade, this.id)
    : super('Registro não encontrado: $entidade $id');
}
