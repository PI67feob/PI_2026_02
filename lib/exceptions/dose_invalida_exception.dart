import 'package:caderno_fazenda/exceptions/agrogestor_exception.dart';

/// Lançada quando a dose informada de um insumo não é aceita pela regra de
/// negócio (por exemplo, dose negativa ou zero).
///
/// Mensagem: `Dose inválida: <dose> <unidade>`. Exemplo: `Dose inválida: -2 L/ha`.
class DoseInvalidaException extends AgroGestorException {
  /// Valor da dose recebida.
  final num dose;

  /// Unidade da dose recebida (ex.: `L/ha`, `kg/ha`, `mL/ha`).
  final String unidade;

  /// Cria a exceção com a [dose] e a [unidade] recebidas.
  DoseInvalidaException(this.dose, this.unidade)
    : super('Dose inválida: $dose $unidade');
}
