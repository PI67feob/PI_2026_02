import 'package:caderno_fazenda/exceptions/capacidade_excedida_exception.dart';
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

/// Mostra 70 em vez de 70.0 quando o número não tem casas decimais.
num _limpo(double valor) {
  return valor == valor.truncateToDouble() ? valor.toInt() : valor;
}

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
  /// 6. Aplica a regra da capacidade do aplicador.
  /// 7. Aplica a regra da chuva, se [horasAteChuva] foi informada.
  /// 8. Calcula, por insumo, a quantidade prevista, a quantidade a comprar, o
  ///    desperdício e o status de sobredose.
  /// 9. Grava a aplicação.
  ///
  /// Cada aplicação representa uma carga: o volume de calda dela tem de caber
  /// no aplicador. A capacidade do aplicador só é conferida quando foi
  /// cadastrada (a do trator ainda não foi levantada). PENDENTE de confirmação
  /// com a fazenda: como lançar uma aplicação que precisa de mais de uma carga.
  ///
  /// Lança `RegistroNaoEncontradoException` para id que não existe,
  /// `DadoInvalidoException` para dado inválido (taxa, unidade, lista vazia,
  /// horas negativas...), [DoseInvalidaException] para dose inválida e
  /// [CapacidadeExcedidaException] quando a calda (ou a massa) passa da
  /// capacidade do aplicador. Nada é gravado se alguma delas for lançada.
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
    final talhoes = <Talhao>[];
    for (final id in talhaoIds) {
      talhoes.add(await _talhoes.exigirPorId(id, 'talhão'));
    }
    final itens = <AplicacaoInsumo>[];
    for (final dose in doses) {
      final insumo = await _insumos.exigirPorId(dose.insumoId, 'insumo');
      itens.add(_montarItem(insumo, dose, taxaLitrosPorHa));
    }

    final aplicacao = Aplicacao(
      data: data,
      operacao: operacao,
      aplicador: aplicador,
      talhoes: talhoes,
      insumos: itens,
      observacao: observacao,
    );

    final volume = _volumeDaCalda(aplicacao, taxaLitrosPorHa);
    final massa = _massaDeSolidos(aplicacao);
    final capacidadeL = aplicador.capacidadeMaximaL;
    if (volume != null && capacidadeL != null) {
      _exigirDentro(volume, capacidadeL, 'L');
    }
    final capacidadeKg = aplicador.capacidadeMaximaKg;
    if (massa != null && capacidadeKg != null) {
      _exigirDentro(massa, capacidadeKg, 'kg');
    }

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
      volumeCaldaL: volume,
      massaProdutosKg: massa,
      chuva: chuva,
    );
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

  /// Passo 6: transforma o resultado da regra da capacidade em exceção.
  void _exigirDentro(double quantidade, double capacidade, String unidade) {
    switch (avaliarCapacidade(quantidade, capacidade)) {
      case ResultadoCapacidade.dentroDaCapacidade:
        return;
      case ResultadoCapacidade.excedeu:
        throw CapacidadeExcedidaException(
          _limpo(quantidade),
          _limpo(capacidade),
          unidade,
        );
      case ResultadoCapacidade.entradaInvalida:
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
