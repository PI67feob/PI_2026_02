/// Alertas e regras operacionais da fazenda (PI-016).
///
/// A fazenda tem três regras claras, e cada uma virou uma função pura: ela
/// DECIDE e devolve o resultado, sem lançar exceção de negócio. Quem lança
/// exceção é o serviço (`AplicacaoService`), que transforma o resultado em erro
/// ou em alerta para o usuário.
///
/// Regras:
/// 1. Chuva ([avaliarChuva]): se chover em menos de 3 horas depois da
///    aplicação, reaplica. O limite de 3 horas é parâmetro.
/// 2. Capacidade ([avaliarCapacidade]): a calda não pode passar da capacidade
///    máxima do aplicador.
/// 3. Sobredose ([avaliarSobredose]): aplicar mais que o previsto é sobredose.
///    A tolerância, em %, é parâmetro: quem define o valor aceitável é o
///    agrônomo, por isso ele não está escrito fixo aqui.
///
/// Entrada inválida (horas negativas, capacidade zero, dose negativa, NaN...)
/// não lança exceção: cada função devolve o valor `entradaInvalida` do seu
/// resultado, e o serviço decide o que fazer com ele.
///
/// PENDENTE de confirmação com a fazenda: chuva em EXATAMENTE 3 horas.
/// A regra da fazenda diz "menos de 3 horas" para reaplicar e a conversa não
/// definiu o limite exato. Comportamento escolhido: no limite exato NÃO
/// reaplicar, porque 3 horas não é "menos de 3 horas" (leitura literal da
/// regra) e porque reaplicar sem necessidade é justamente o desperdício que o
/// projeto quer reduzir. Se a fazenda responder o contrário, basta passar
/// `reaplicarNoLimite: true` ([avaliarChuva]); não é preciso mudar o código.
///
/// Sobre a sobredose: a tolerância separa `atencao` de `critico`. Dose abaixo
/// do previsto não é sobredose e dá `ok`. Aplicar mais que o previsto já é
/// sobredose, então dá `atencao` até a tolerância e `critico` acima dela.
library;

import 'package:caderno_fazenda/logica/calculo_desperdicio.dart';

/// Limite padrão, em horas, entre a aplicação e a chuva (regra da fazenda).
const double limiteChuvaPadraoHoras = 3;

/// Resultado da regra da chuva.
enum DecisaoChuva {
  /// Choveu antes do limite: a calda foi lavada e a aplicação deve ser refeita.
  reaplicar,

  /// A chuva veio depois do limite (ou no limite exato, ver PENDENTE).
  naoReaplicar,

  /// As horas ou o limite não fazem sentido (negativo, zero ou NaN).
  entradaInvalida,
}

/// Resultado da regra da capacidade.
enum ResultadoCapacidade {
  /// O volume cabe no aplicador, inclusive quando é igual à capacidade.
  dentroDaCapacidade,

  /// O volume passou da capacidade máxima do aplicador.
  excedeu,

  /// Volume negativo, ou capacidade zero, negativa ou NaN.
  entradaInvalida,
}

/// Resultado da regra da sobredose.
enum StatusSobredose {
  /// Aplicou o previsto ou menos.
  ok,

  /// Aplicou mais que o previsto, mas dentro da tolerância.
  atencao,

  /// Aplicou mais que o previsto e passou da tolerância.
  critico,

  /// Dose prevista zero ou negativa, dose realizada negativa, tolerância
  /// negativa ou algum valor que não é número.
  entradaInvalida,
}

/// Regra da chuva: diz se a aplicação precisa ser refeita.
///
/// Entrada:
/// - [horasAteChuva]: horas entre o fim da aplicação e o começo da chuva. Pode
///   ser fracionada (2h59 = 2 + 59 / 60).
/// - [limiteHoras]: limite da fazenda, em horas. Padrão:
///   [limiteChuvaPadraoHoras] (3).
/// - [reaplicarNoLimite]: o que fazer quando a chuva vem EXATAMENTE no limite.
///   Padrão `false` (não reaplicar). PENDENTE de confirmação com a fazenda.
///
/// Saída:
/// - [DecisaoChuva.reaplicar] se [horasAteChuva] for menor que [limiteHoras].
/// - [DecisaoChuva.naoReaplicar] se for maior.
/// - No limite exato, depende de [reaplicarNoLimite].
/// - [DecisaoChuva.entradaInvalida] se as horas forem negativas ou o limite não
///   for maior que zero. Não lança exceção.
DecisaoChuva avaliarChuva(
  double horasAteChuva, {
  double limiteHoras = limiteChuvaPadraoHoras,
  bool reaplicarNoLimite = false,
}) {
  if (!horasAteChuva.isFinite || horasAteChuva < 0) {
    return DecisaoChuva.entradaInvalida;
  }
  if (!limiteHoras.isFinite || limiteHoras <= 0) {
    return DecisaoChuva.entradaInvalida;
  }
  if (horasAteChuva < limiteHoras) {
    return DecisaoChuva.reaplicar;
  }
  if (horasAteChuva == limiteHoras && reaplicarNoLimite) {
    return DecisaoChuva.reaplicar;
  }
  return DecisaoChuva.naoReaplicar;
}

/// Regra da capacidade: diz se a calda passou da capacidade do aplicador.
///
/// Entrada:
/// - [volume]: volume de calda (ou massa de produto), na mesma unidade da
///   capacidade.
/// - [capacidade]: capacidade máxima do aplicador. Deve ser maior que zero.
///
/// Saída:
/// - [ResultadoCapacidade.excedeu] se [volume] for maior que [capacidade].
/// - [ResultadoCapacidade.dentroDaCapacidade] se for menor ou igual: volume
///   igual à capacidade ainda cabe.
/// - [ResultadoCapacidade.entradaInvalida] se o volume for negativo ou a
///   capacidade não for maior que zero. Não lança exceção.
///
/// Quem lança `CapacidadeExcedidaException` é o serviço.
ResultadoCapacidade avaliarCapacidade(double volume, double capacidade) {
  if (!volume.isFinite || volume < 0) {
    return ResultadoCapacidade.entradaInvalida;
  }
  if (!capacidade.isFinite || capacidade <= 0) {
    return ResultadoCapacidade.entradaInvalida;
  }
  if (volume > capacidade) {
    return ResultadoCapacidade.excedeu;
  }
  return ResultadoCapacidade.dentroDaCapacidade;
}

/// Regra da sobredose: classifica a dose realizada contra a dose prevista.
///
/// Importante: [dosePrevista] e [doseRealizada] precisam estar na MESMA
/// unidade base (L/ha ou kg/ha). Converta antes com `normalizarDose` ou
/// `normalizarDoseMassa`.
///
/// Entrada:
/// - [dosePrevista]: dose que o cálculo indicava. Deve ser maior que zero.
/// - [doseRealizada]: dose realmente aplicada. Não pode ser negativa.
/// - [toleranciaPercentual]: excesso aceito acima do previsto, em %. É
///   obrigatória e não tem valor padrão: quem define é o agrônomo. Zero
///   significa nenhuma tolerância.
///
/// Saída:
/// - [StatusSobredose.ok] se [doseRealizada] for menor ou igual ao previsto.
/// - [StatusSobredose.atencao] se passou do previsto, mas o excesso (em % do
///   previsto) é menor ou igual à tolerância.
/// - [StatusSobredose.critico] se o excesso passou da tolerância.
/// - [StatusSobredose.entradaInvalida] para valor negativo, previsto zero ou
///   algo que não é número. Não lança exceção.
///
/// O excesso é calculado por `percentualDesperdicio`, a mesma conta usada no
/// cálculo de desperdício.
StatusSobredose avaliarSobredose(
  double dosePrevista,
  double doseRealizada, {
  required double toleranciaPercentual,
}) {
  if (!dosePrevista.isFinite || dosePrevista <= 0) {
    return StatusSobredose.entradaInvalida;
  }
  if (!doseRealizada.isFinite || doseRealizada < 0) {
    return StatusSobredose.entradaInvalida;
  }
  if (!toleranciaPercentual.isFinite || toleranciaPercentual < 0) {
    return StatusSobredose.entradaInvalida;
  }
  if (doseRealizada <= dosePrevista) {
    return StatusSobredose.ok;
  }
  final excesso = percentualDesperdicio(dosePrevista, doseRealizada);
  if (excesso <= toleranciaPercentual) {
    return StatusSobredose.atencao;
  }
  return StatusSobredose.critico;
}
