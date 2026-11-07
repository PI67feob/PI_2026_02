import 'package:caderno_fazenda/exceptions/agrogestor_exception.dart';

/// Lançada quando o volume (ou a massa) pedido passa da capacidade máxima do
/// aplicador.
///
/// Mensagem:
/// `Capacidade excedida: <valor> <unidade> (máximo <capacidade> <unidade>)`.
/// Exemplo: `Capacidade excedida: 2500 L (máximo 2000 L)`.
class CapacidadeExcedidaException extends AgroGestorException {
  /// Valor recebido que passou do limite.
  final num valor;

  /// Capacidade máxima do aplicador.
  final num capacidadeMaxima;

  /// Unidade do valor e da capacidade (ex.: `L`, `kg`).
  final String unidade;

  /// Cria a exceção com o [valor] recebido, a [capacidadeMaxima] do aplicador
  /// e a [unidade] de ambos.
  CapacidadeExcedidaException(this.valor, this.capacidadeMaxima, this.unidade)
    : super(
        'Capacidade excedida: $valor $unidade '
        '(máximo $capacidadeMaxima $unidade)',
      );
}
