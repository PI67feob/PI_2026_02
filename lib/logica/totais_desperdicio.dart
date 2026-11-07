/// Uma dose aplicada numa área, pronta para ser somada.
///
/// A dose já está na base do banco (`L/ha` ou `kg/ha`), e a [unidade] diz qual.
class DoseNaArea {
  /// Área em que a dose foi aplicada, em hectares.
  final double areaHa;

  /// Dose que o cálculo indicava, por hectare.
  final double dosePrevista;

  /// Dose realmente aplicada, por hectare; nula se a aplicação ainda não foi
  /// feita.
  final double? doseRealizada;

  /// Unidade base das duas doses: `L/ha` ou `kg/ha`.
  final String unidade;

  /// Cria a dose aplicada na [areaHa].
  const DoseNaArea({
    required this.areaHa,
    required this.dosePrevista,
    required this.unidade,
    this.doseRealizada,
  });
}

/// Totais de desperdício de uma unidade (litros ou quilos).
///
/// Os valores são quantidades de produto (dose por hectare vezes hectares),
/// em L quando a unidade é `L/ha` e em kg quando é `kg/ha`.
class TotaisDesperdicio {
  /// Unidade base dos totais: `L/ha` ou `kg/ha`.
  final String unidade;

  /// Quantidade de produto que o cálculo indicava.
  final double totalPrevisto;

  /// Quantidade de produto realmente aplicada.
  final double totalRealizado;

  /// Quantidade aplicada acima do previsto, somando só os excessos.
  final double volumeDesperdicado;

  /// Cria os totais de uma [unidade].
  const TotaisDesperdicio({
    required this.unidade,
    required this.totalPrevisto,
    required this.totalRealizado,
    required this.volumeDesperdicado,
  });

  /// Desperdício em % do previsto; zero quando não havia nada previsto.
  double get percentual {
    if (totalPrevisto <= 0) {
      return 0;
    }
    return volumeDesperdicado / totalPrevisto * 100;
  }
}

/// Soma previsto, realizado e desperdício, separando por unidade.
///
/// Litros e quilos nunca são somados juntos: o resultado tem uma entrada por
/// unidade (`L/ha` e `kg/ha`). Só entram doses que já têm dose realizada, para
/// que previsto e realizado sejam comparados sobre as mesmas aplicações.
///
/// Regras:
/// - Quantidade prevista = área x dose prevista; realizada = área x dose
///   realizada.
/// - Desperdício de cada dose = realizada menos prevista, só quando é positivo.
///   Aplicar menos que o previsto não é desperdício e não abate o excesso de
///   outra dose.
///
/// Devolve um mapa vazio quando nenhuma dose tem valor realizado.
Map<String, TotaisDesperdicio> totalizarPorUnidade(List<DoseNaArea> doses) {
  final porUnidade = <String, List<DoseNaArea>>{};
  for (final dose in doses) {
    if (dose.doseRealizada == null) {
      continue;
    }
    porUnidade.putIfAbsent(dose.unidade, () => []).add(dose);
  }

  final totais = <String, TotaisDesperdicio>{};
  for (final grupo in porUnidade.entries) {
    totais[grupo.key] = _somar(grupo.key, grupo.value);
  }
  return totais;
}

TotaisDesperdicio _somar(String unidade, List<DoseNaArea> doses) {
  var previsto = 0.0;
  var realizado = 0.0;
  var desperdicado = 0.0;
  for (final dose in doses) {
    final quantidadePrevista = dose.areaHa * dose.dosePrevista;
    final quantidadeRealizada = dose.areaHa * (dose.doseRealizada ?? 0);
    previsto += quantidadePrevista;
    realizado += quantidadeRealizada;
    if (quantidadeRealizada > quantidadePrevista) {
      desperdicado += quantidadeRealizada - quantidadePrevista;
    }
  }
  return TotaisDesperdicio(
    unidade: unidade,
    totalPrevisto: previsto,
    totalRealizado: realizado,
    volumeDesperdicado: desperdicado,
  );
}
