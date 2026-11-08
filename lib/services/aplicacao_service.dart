import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';
import 'package:caderno_fazenda/exceptions/dose_invalida_exception.dart';
import 'package:caderno_fazenda/logica/alertas_operacionais.dart';
import 'package:caderno_fazenda/logica/calculo_desperdicio.dart';
import 'package:caderno_fazenda/logica/calculos_calda.dart';
import 'package:caderno_fazenda/logica/normalizacao_dose.dart';
import 'package:caderno_fazenda/logica/totais_desperdicio.dart';
import 'package:caderno_fazenda/models/aplicacao.dart';
import 'package:caderno_fazenda/models/aplicacao_insumo.dart';
import 'package:caderno_fazenda/models/insumo.dart';
import 'package:caderno_fazenda/models/operacao.dart';
import 'package:caderno_fazenda/models/talhao.dart';
import 'package:caderno_fazenda/models/unidade_dose.dart';
import 'package:caderno_fazenda/repositories/interfaces/aplicacao_repository.dart';
import 'package:caderno_fazenda/repositories/interfaces/aplicador_repository.dart';
import 'package:caderno_fazenda/repositories/interfaces/insumo_repository.dart';
import 'package:caderno_fazenda/repositories/interfaces/operacao_repository.dart';
import 'package:caderno_fazenda/repositories/interfaces/repository.dart';
import 'package:caderno_fazenda/repositories/interfaces/talhao_repository.dart';
import 'package:caderno_fazenda/services/dose_informada.dart';
import 'package:caderno_fazenda/services/parametros_operacionais.dart';
import 'package:caderno_fazenda/services/resultado_aplicacao.dart';

/// Caso de uso principal do sistema: registrar uma aplicação.
///
/// É aqui que as camadas se encontram. O serviço busca os dados pelos
/// repositórios (que escondem o banco), chama as funções puras de
/// `lib/logica` para decidir e calcular, monta o objeto de domínio e só então
/// grava. É também o serviço quem lança as exceções de negócio: as funções de
/// lógica apenas devolvem o resultado, e aqui ele vira exceção ou alerta.
class AplicacaoService {
  final OperacaoRepository _operacoes;
  final AplicadorRepository _aplicadores;
  final TalhaoRepository _talhoes;
  final InsumoRepository _insumos;
  final AplicacaoRepository _aplicacoes;

  /// Valores das regras da fazenda (tolerância, limite da chuva, fator de
  /// compra).
  final ParametrosOperacionais parametros;

  /// Cria o serviço com os repositórios necessários e os [parametros] das
  /// regras.
  AplicacaoService(
    this._operacoes,
    this._aplicadores,
    this._talhoes,
    this._insumos,
    this._aplicacoes,
    this.parametros,
  );

  /// Registra uma aplicação e devolve o que foi calculado.
  ///
  /// Passos, na ordem em que acontecem (os mesmos do fluxograma em
  /// `docs/fluxograma/fluxo_dados.md`):
  /// 1. Confere a [taxaLitrosPorHa].
  /// 2. Busca operação, aplicador, talhões e insumos pelos ids.
  /// 3. Normaliza cada dose para L/ha (líquido) ou kg/ha (sólido).
  /// 4. Monta a aplicação, que garante as próprias regras.
  /// 5. Calcula o volume de calda (área x taxa) e a massa de produtos sólidos.
  /// 6. Calcula quantas viagens o aplicador faz para levar a calda e os
  ///    sólidos.
  /// 7. Aplica a regra da chuva, se [horasAteChuva] foi informada.
  /// 8. Calcula, por insumo, a quantidade prevista, a quantidade a comprar, o
  ///    desperdício e o status de sobredose.
  /// 9. Grava a aplicação.
  ///
  /// A capacidade do aplicador vale POR VIAGEM (voo do drone, enchida da bomba
  /// costal, carga do trator). Uma aplicação maior que a capacidade não é
  /// erro: ela é registrada inteira, como um lançamento só, e o resultado diz
  /// quantas viagens são necessárias. As viagens só são calculadas quando o
  /// aplicador tem a capacidade cadastrada (a do trator ainda não foi
  /// levantada); sem ela ficam nulas.
  ///
  /// Lança `RegistroNaoEncontradoException` para id que não existe,
  /// `DadoInvalidoException` para dado inválido (taxa, unidade, lista vazia,
  /// horas negativas...) e [DoseInvalidaException] para dose inválida. Nada é
  /// gravado se alguma delas for lançada.
  Future<ResultadoAplicacao> registrar({
    required DateTime data,
    required int operacaoId,
    required int aplicadorId,
    required List<int> talhaoIds,
    required List<DoseInformada> doses,
    required double taxaLitrosPorHa,
    double? horasAteChuva,
    String? observacao,
  }) async {
    _exigirTaxa(taxaLitrosPorHa);

    final operacao = await _operacoes.exigirPorId(operacaoId, 'operação');
    final aplicador = await _aplicadores.exigirPorId(aplicadorId, 'aplicador');
    final talhoes = await _buscarTalhoes(talhaoIds);
    final itens = await _montarItens(doses, taxaLitrosPorHa);

    final aplicacao = Aplicacao(
      data: data,
      operacao: operacao,
      aplicador: aplicador,
      talhoes: talhoes,
      insumos: itens,
      observacao: observacao,
    );

    final carga = _carga(aplicacao, taxaLitrosPorHa);

    DecisaoChuva? chuva;
    if (horasAteChuva != null) {
      chuva = _decidirChuva(horasAteChuva);
    }

    final avaliacoes = <AvaliacaoInsumo>[];
    for (final item in aplicacao.insumos) {
      avaliacoes.add(_avaliar(item, aplicacao.areaTotalHa));
    }

    await _aplicacoes.salvar(aplicacao);
    return ResultadoAplicacao(
      aplicacao: aplicacao,
      insumos: avaliacoes,
      volumeCaldaL: carga.volumeCaldaL,
      massaProdutosKg: carga.massaProdutosKg,
      viagensCalda: carga.viagensCalda,
      viagensSolidos: carga.viagensSolidos,
      chuva: chuva,
    );
  }

  /// Calcula, sem gravar nada, o que a aplicação leva de calda e de sólidos e
  /// quantas viagens o aplicador faz.
  ///
  /// Serve para conferir antes de [registrar]. Como a capacidade do aplicador
  /// vale por viagem, uma taxa digitada errada não é mais barrada por um erro
  /// de capacidade: ela aparece aqui como um volume (ou um número de viagens)
  /// fora do esperado, e dá tempo de corrigir.
  ///
  /// Usa os mesmos dados e as mesmas regras de [registrar] que mexem na
  /// carga, então os números são os mesmos que ele vai devolver. Lança
  /// `RegistroNaoEncontradoException` para id que não existe,
  /// `DadoInvalidoException` para dado inválido (taxa, unidade, lista vazia,
  /// talhão ou insumo repetido) e [DoseInvalidaException] para dose inválida.
  Future<CargaAplicacao> calcularCarga({
    required int aplicadorId,
    required List<int> talhaoIds,
    required List<DoseInformada> doses,
    required double taxaLitrosPorHa,
  }) async {
    _exigirTaxa(taxaLitrosPorHa);
    final aplicador = await _aplicadores.exigirPorId(aplicadorId, 'aplicador');
    final talhoes = await _buscarTalhoes(talhaoIds);
    final itens = await _montarItens(doses, taxaLitrosPorHa);

    // A aplicação provisória só existe para reaproveitar as regras do modelo
    // (ao menos um talhão e um insumo, sem repetidos). Nada dela é gravado.
    final provisoria = Aplicacao(
      data: DateTime(2000),
      operacao: Operacao(descricao: 'Prévia da carga'),
      aplicador: aplicador,
      talhoes: talhoes,
      insumos: itens,
    );
    return _carga(provisoria, taxaLitrosPorHa);
  }

  /// Soma previsto, realizado e desperdício de todas as aplicações já
  /// gravadas, separando litros de quilos.
  ///
  /// É o equivalente em Dart das medidas do BI (Total Previsto, Total
  /// Realizado, Volume Desperdiçado e % Desperdício). Só entram os insumos
  /// que já têm dose realizada. A chave do mapa é a unidade (`L/ha` ou
  /// `kg/ha`).
  Future<Map<String, TotaisDesperdicio>> resumoDesperdicio() async {
    final todas = await _aplicacoes.listarTodos();
    final doses = <DoseNaArea>[];
    for (final aplicacao in todas) {
      final area = aplicacao.areaTotalHa;
      for (final item in aplicacao.insumos) {
        final dose = DoseNaArea(
          areaHa: area,
          dosePrevista: item.dosePrevista,
          doseRealizada: item.doseRealizada,
          unidade: item.unidade.texto,
        );
        doses.add(dose);
      }
    }
    return totalizarPorUnidade(doses);
  }

  void _exigirTaxa(double taxa) {
    if (!taxa.isFinite || taxa <= 0) {
      throw DadoInvalidoException('taxa (L/ha)', 'deve ser maior que zero');
    }
  }

  Future<List<Talhao>> _buscarTalhoes(List<int> ids) async {
    final talhoes = <Talhao>[];
    for (final id in ids) {
      talhoes.add(await _talhoes.exigirPorId(id, 'talhão'));
    }
    return talhoes;
  }

  Future<List<AplicacaoInsumo>> _montarItens(
    List<DoseInformada> doses,
    double taxa,
  ) async {
    final itens = <AplicacaoInsumo>[];
    for (final dose in doses) {
      final insumo = await _insumos.exigirPorId(dose.insumoId, 'insumo');
      itens.add(_montarItem(insumo, dose, taxa));
    }
    return itens;
  }

  /// Passo 3: converte a dose da ficha para a base do banco.
  AplicacaoInsumo _montarItem(Insumo insumo, DoseInformada dose, double taxa) {
    final previsto = _normalizar(dose.dosePrevista, dose.unidade, taxa);
    final informada = dose.doseRealizada;
    double? realizado;
    if (informada != null) {
      realizado = _normalizar(informada, dose.unidade, taxa).valor;
    }
    return AplicacaoInsumo(
      insumo: insumo,
      unidade: UnidadeDose.deTexto(previsto.unidade),
      dosePrevista: previsto.valor,
      doseRealizada: realizado,
    );
  }

  /// Traduz os erros da família `CaldaException` (lib/logica) para as
  /// exceções do domínio.
  DoseNormalizada _normalizar(double dose, String unidade, double taxa) {
    try {
      return normalizarDoseInformada(dose, unidade, taxa);
    } on UnidadeDesconhecidaException catch (e) {
      throw DadoInvalidoException('unidade da dose', e.message);
    } on CaldaException {
      throw DoseInvalidaException(dose, unidade);
    }
  }

  /// Passo 5: volume de calda = área x taxa. Só existe calda quando há insumo
  /// líquido; para aplicação só de sólidos o volume é nulo.
  double? _volumeDaCalda(Aplicacao aplicacao, double taxaLitrosPorHa) {
    var temLiquido = false;
    for (final item in aplicacao.insumos) {
      if (item.unidade == UnidadeDose.litrosPorHectare) {
        temLiquido = true;
      }
    }
    if (!temLiquido) {
      return null;
    }
    return volumeCalda(aplicacao.areaTotalHa, taxaLitrosPorHa);
  }

  /// Passo 5: massa total, em kg, dos insumos sólidos; nula se não há sólido.
  double? _massaDeSolidos(Aplicacao aplicacao) {
    final area = aplicacao.areaTotalHa;
    var massa = 0.0;
    var temSolido = false;
    for (final item in aplicacao.insumos) {
      if (item.unidade == UnidadeDose.quilosPorHectare) {
        temSolido = true;
        massa += quantidadeProdutoPorHa(area, item.dosePrevista);
      }
    }
    return temSolido ? massa : null;
  }

  /// Passos 5 e 6: o que a aplicação leva e quantas viagens isso dá.
  CargaAplicacao _carga(Aplicacao aplicacao, double taxaLitrosPorHa) {
    final volume = _volumeDaCalda(aplicacao, taxaLitrosPorHa);
    final massa = _massaDeSolidos(aplicacao);
    final aplicador = aplicacao.aplicador;
    return CargaAplicacao(
      volumeCaldaL: volume,
      massaProdutosKg: massa,
      viagensCalda: _viagens(volume, aplicador.capacidadeMaximaL, 'L'),
      viagensSolidos: _viagens(massa, aplicador.capacidadeMaximaKg, 'kg'),
    );
  }

  /// Passo 6: quantas viagens o aplicador faz para levar a [quantidade]. É
  /// nulo quando não há o que levar ou quando o aplicador não tem a
  /// [capacidade] cadastrada, porque aí não dá para calcular.
  int? _viagens(double? quantidade, double? capacidade, String unidade) {
    if (quantidade == null || capacidade == null) {
      return null;
    }
    try {
      return viagensNecessarias(quantidade, capacidade);
    } on CaldaException {
      throw DadoInvalidoException('capacidade ($unidade)', 'valor inválido');
    }
  }

  /// Passo 7: aplica a regra da chuva com o limite configurado.
  DecisaoChuva _decidirChuva(double horas) {
    final limite = parametros.limiteChuvaHoras;
    final decisao = avaliarChuva(horas, limiteHoras: limite);
    if (decisao == DecisaoChuva.entradaInvalida) {
      throw DadoInvalidoException('chuva (horas)', 'não pode ser negativa');
    }
    return decisao;
  }

  /// Passo 8: números de um insumo (previsto, a comprar, desperdício e
  /// status de sobredose).
  AvaliacaoInsumo _avaliar(AplicacaoInsumo item, double areaHa) {
    final prevista = quantidadeProdutoPorHa(areaHa, item.dosePrevista);
    final fator = parametros.fatorCompra;
    final compra = quantidadeAComprar(prevista, fator: fator);

    double? percentual;
    StatusSobredose? status;
    final realizada = item.doseRealizada;
    if (realizada != null) {
      percentual = percentualDesperdicio(item.dosePrevista, realizada);
      status = avaliarSobredose(
        item.dosePrevista,
        realizada,
        toleranciaPercentual: parametros.toleranciaSobredosePercentual,
      );
    }
    return AvaliacaoInsumo(
      item: item,
      quantidadePrevista: prevista,
      quantidadeAComprar: compra,
      percentualDesperdicio: percentual,
      statusSobredose: status,
    );
  }
}
