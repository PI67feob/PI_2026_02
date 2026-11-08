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

/// O que uma aplicação leva de calda e de produtos sólidos, e quantas viagens
/// o aplicador precisa fazer para levar tudo.
///
/// A capacidade do aplicador vale por viagem (voo do drone, enchida da bomba
/// costal, carga do trator): passar dela não é erro, só pede mais viagens.
class CargaAplicacao {
  /// Volume de calda, em litros (área x taxa); nulo se não há insumo líquido.
  final double? volumeCaldaL;

  /// Massa dos insumos sólidos, em kg; nula se não há insumo sólido.
  final double? massaProdutosKg;

  /// Viagens para levar a calda; nulo se não há calda ou se o aplicador não
  /// tem capacidade em litros cadastrada.
  final int? viagensCalda;

  /// Viagens para levar os sólidos; nulo se não há sólido ou se o aplicador
  /// não tem capacidade em kg cadastrada.
  final int? viagensSolidos;

  /// Cria a carga de uma aplicação.
  const CargaAplicacao({
    this.volumeCaldaL,
    this.massaProdutosKg,
    this.viagensCalda,
    this.viagensSolidos,
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

  /// Viagens do aplicador para levar a calda; nulo se não há calda ou se a
  /// capacidade em litros do aplicador não foi cadastrada.
  final int? viagensCalda;

  /// Viagens do aplicador para levar os sólidos; nulo se não há sólido ou se
  /// a capacidade em kg do aplicador não foi cadastrada.
  final int? viagensSolidos;

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
    this.viagensCalda,
    this.viagensSolidos,
    this.chuva,
  });
}
