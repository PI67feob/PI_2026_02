import 'package:caderno_fazenda/exceptions/agrogestor_exception.dart';

/// Lançada quando um dado do talhão não é aceito pela regra de negócio (por
/// exemplo, área em hectares negativa ou zero, ou talhão inexistente).
///
/// Mensagem: `Talhão inválido: <valor>` ou, com motivo,
/// `Talhão inválido: <valor> (<motivo>)`.
/// Exemplo: `Talhão inválido: -3 ha (área deve ser maior que zero)`.
class TalhaoInvalidoException extends AgroGestorException {
  /// Valor recebido que tornou o talhão inválido.
  final Object? valor;

  /// Explicação opcional do motivo.
  final String? motivo;

  /// Cria a exceção com o [valor] recebido e, opcionalmente, o [motivo].
  TalhaoInvalidoException(this.valor, {this.motivo})
    : super(
        motivo == null
            ? 'Talhão inválido: $valor'
            : 'Talhão inválido: $valor ($motivo)',
      );
}
