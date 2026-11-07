/// Uma dose como foi anotada na ficha de papel, antes de qualquer conversão.
///
/// A ficha traz a dose em unidades variadas (`L/ha`, `mL/ha`, `L/1000L`,
/// `kg/ha`, `g/ha`). O serviço converte para a base do banco antes de gravar.
class DoseInformada {
  /// Id do insumo aplicado.
  final int insumoId;

  /// Dose prevista, na [unidade] anotada.
  final double dosePrevista;

  /// Dose realmente aplicada, na [unidade] anotada; nula se ainda não foi
  /// aplicada.
  final double? doseRealizada;

  /// Unidade anotada na ficha, como `L/ha` ou `g/ha`.
  final String unidade;

  /// Cria a dose anotada para o insumo [insumoId].
  const DoseInformada({
    required this.insumoId,
    required this.dosePrevista,
    required this.unidade,
    this.doseRealizada,
  });
}
