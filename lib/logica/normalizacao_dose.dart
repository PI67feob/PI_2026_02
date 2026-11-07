import 'package:caderno_fazenda/logica/calculos_calda.dart';

/// Dose já convertida para a base do banco.
///
/// A base depende do tipo do produto: `L/ha` para líquido e `kg/ha` para
/// sólido. Litros e quilos nunca se misturam.
class DoseNormalizada {
  /// Valor da dose, na [unidade] base.
  final double valor;

  /// Unidade base: `L/ha` (produto líquido) ou `kg/ha` (produto sólido).
  final String unidade;

  /// Cria a dose com o [valor] já convertido para a [unidade] base.
  const DoseNormalizada(this.valor, this.unidade);
}

/// Unidades que medem volume (produto líquido), em minúsculas.
const Set<String> _unidadesDeVolume = {'l/ha', 'ml/ha', 'l/1000l'};

/// Unidades que medem massa (produto sólido), em minúsculas.
const Set<String> _unidadesDeMassa = {'kg/ha', 'g/ha', 'kg/1000l', 'g/1000l'};

/// Decide se a dose é de produto líquido ou sólido e converte para a base.
///
/// Esta é a decisão "dose em qual unidade? líquido ou sólido?" do fluxo de
/// dados: a ficha de papel traz a dose em unidades variadas, e o banco só
/// aceita `L/ha` e `kg/ha`.
///
/// - Unidade de volume (`L/ha`, `mL/ha`, `L/1000L`): converte com
///   `normalizarDose` e devolve em `L/ha`.
/// - Unidade de massa (`kg/ha`, `g/ha`): converte com `normalizarDoseMassa` e
///   devolve em `kg/ha`.
/// - Qualquer outra: lança [UnidadeDesconhecidaException].
///
/// Entrada:
/// - [dose]: valor da dose, não negativo.
/// - [unidadeDose]: unidade em que a dose foi anotada.
/// - [taxaLitrosPorHa]: taxa de aplicação, em L/ha. Só é usada na conversão de
///   `L/1000L`; mesmo assim deve ser maior que zero.
///
/// Erros (ficam na família `CaldaException`, e o serviço faz a tradução):
/// - [CaldaException] para dose negativa ou taxa menor ou igual a zero.
/// - [UnidadeDesconhecidaException] para unidade desconhecida. Isso inclui
///   `kg/1000L` e `g/1000L`, que continuam PENDENTES de conferência com o
///   agrônomo (ver `normalizarDoseMassa`).
DoseNormalizada normalizarDoseInformada(
  double dose,
  String unidadeDose,
  double taxaLitrosPorHa,
) {
  final unidade = unidadeDose.toLowerCase().trim();
  if (_unidadesDeVolume.contains(unidade)) {
    final valor = normalizarDose(dose, unidadeDose, taxaLitrosPorHa);
    return DoseNormalizada(valor, 'L/ha');
  }
  if (_unidadesDeMassa.contains(unidade)) {
    final valor = normalizarDoseMassa(dose, unidadeDose);
    return DoseNormalizada(valor, 'kg/ha');
  }
  throw UnidadeDesconhecidaException(unidadeDose);
}
