import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';

/// Unidades em que a dose de um insumo é guardada no banco.
///
/// Só existem duas bases, uma para cada tipo de produto. Litros e quilos nunca
/// se misturam, porque converter um no outro exigiria a densidade do produto,
/// que a fazenda não tem.
enum UnidadeDose {
  /// Produto líquido, em litros por hectare.
  litrosPorHectare('L/ha'),

  /// Produto sólido, em quilos por hectare.
  quilosPorHectare('kg/ha');

  /// Texto gravado no banco e mostrado ao usuário.
  final String texto;

  const UnidadeDose(this.texto);

  /// Converte o texto do banco (`L/ha` ou `kg/ha`) na unidade correspondente.
  ///
  /// Lança [DadoInvalidoException] para qualquer outro texto.
  static UnidadeDose deTexto(String texto) {
    for (final unidade in UnidadeDose.values) {
      if (unidade.texto == texto.trim()) {
        return unidade;
      }
    }
    throw DadoInvalidoException(
      'unidade da dose',
      'use L/ha ou kg/ha (recebido: $texto)',
    );
  }
}
