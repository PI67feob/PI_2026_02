import 'package:caderno_fazenda/logica/alertas_operacionais.dart';
import 'package:caderno_fazenda/models/aplicacao.dart';
import 'package:caderno_fazenda/models/aplicacao_insumo.dart';

/// O que o serviço calculou para um insumo de uma aplicação.
class AvaliacaoInsumo {
  /// Insumo com as doses já na base do banco.
  final AplicacaoInsumo item;

  /// Quantidade de produto prevista: dose prevista x área (L ou kg).
  final double quantidadePrevista;

  /// Quantidade a comprar: a prevista vezes o fator de compra.
  final double quantidadeAComprar;

  /// Desperdício em % do previsto; nulo se a dose realizada não foi informada.
  final double? percentualDesperdicio;

  /// Status da sobredose; nulo se a dose realizada não foi informada.
  final StatusSobredose? statusSobredose;

  /// Cria a avaliação de um [item].
  const AvaliacaoInsumo({
    required this.item,
    required this.quantidadePrevista,
    required this.quantidadeAComprar,
    this.percentualDesperdicio,
    this.statusSobredose,
  });
}

/// Resultado de registrar uma aplicação: a aplicação gravada e os alertas.
class ResultadoAplicacao {
  /// Aplicação gravada, já com id.
  final Aplicacao aplicacao;

  /// Volume de calda, em litros (área x taxa); nulo se não há insumo líquido.
  final double? volumeCaldaL;

  /// Massa dos insumos sólidos, em kg; nula se não há insumo sólido.
  final double? massaProdutosKg;

  /// Decisão sobre reaplicar por causa da chuva; nula se a chuva não foi
  /// informada.
  final DecisaoChuva? chuva;

  /// Avaliação de cada insumo, na ordem em que foram informados.
  final List<AvaliacaoInsumo> insumos;

  /// Cria o resultado de uma [aplicacao].
  const ResultadoAplicacao({
    required this.aplicacao,
    required this.insumos,
    this.volumeCaldaL,
    this.massaProdutosKg,
    this.chuva,
  });
}
