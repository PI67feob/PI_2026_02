import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';
import 'package:caderno_fazenda/logica/alertas_operacionais.dart';
import 'package:caderno_fazenda/models/area.dart';
import 'package:caderno_fazenda/models/drone.dart';
import 'package:caderno_fazenda/models/insumo.dart';
import 'package:caderno_fazenda/models/operacao.dart';
import 'package:caderno_fazenda/models/talhao.dart';
import 'package:caderno_fazenda/models/trator.dart';
import 'package:caderno_fazenda/models/unidade_dose.dart';
import 'package:caderno_fazenda/repositories/memoria/repositorios_memoria.dart';
import 'package:caderno_fazenda/services/aplicacao_service.dart';
import 'package:caderno_fazenda/services/dose_informada.dart';
import 'package:caderno_fazenda/services/parametros_operacionais.dart';
import 'package:caderno_fazenda/services/resultado_aplicacao.dart';
import 'package:test/test.dart';

import '../ajuda/erros.dart';

void main() {
  late TalhaoRepositoryMemoria talhoes;
  late InsumoRepositoryMemoria insumos;
  late AplicadorRepositoryMemoria aplicadores;
  late OperacaoRepositoryMemoria operacoes;
  late AplicacaoRepositoryMemoria aplicacoes;
  late AplicacaoService servico;
  late int idOperacao;
  late int idDrone;
  late int idTrator;
  late int idChico1;
  late int idChico2;
  late int idOrkestra;
  late int idBoro;
  var recusaDado = throwsA(isA<DadoInvalidoException>());

  AplicacaoService criarServico({
    double tolerancia = 10,
    double limiteChuva = 3,
    double fator = 0.95,
  }) {
    var parametros = ParametrosOperacionais(
      toleranciaSobredosePercentual: tolerancia,
      limiteChuvaHoras: limiteChuva,
      fatorCompra: fator,
    );
    return AplicacaoService(
      operacoes,
      aplicadores,
      talhoes,
      insumos,
      aplicacoes,
      parametros,
    );
  }

  // Orkestra SC (liquido): previsto 300 mL/ha = 0,3 L/ha.
  DoseInformada liquida({double? real}) {
    return DoseInformada(
      insumoId: idOrkestra,
      dosePrevista: 300,
      doseRealizada: real,
      unidade: 'mL/ha',
    );
  }

  // Boro Super (solido): previsto 500 g/ha = 0,5 kg/ha.
  DoseInformada solida({double? real}) {
    return DoseInformada(
      insumoId: idBoro,
      dosePrevista: 500,
      doseRealizada: real,
      unidade: 'g/ha',
    );
  }

  // Padrao: os dois talhoes (6,6 ha), o drone, taxa de 10 L/ha, e as doses
  // 345 mL/ha (liquido) e 450 g/ha (solido) realizadas.
  Future<ResultadoAplicacao> registrar({
    double comTaxa = 10,
    List<DoseInformada>? comDoses,
    List<int>? comTalhoes,
    int? comAplicador,
    int? comOperacao,
    double? comChuva,
  }) {
    return servico.registrar(
      data: DateTime(2026, 11, 6),
      operacaoId: comOperacao ?? idOperacao,
      aplicadorId: comAplicador ?? idDrone,
      talhaoIds: comTalhoes ?? [idChico1, idChico2],
      doses: comDoses ?? [liquida(real: 345), solida(real: 450)],
      taxaLitrosPorHa: comTaxa,
      horasAteChuva: comChuva,
    );
  }

  setUp(() async {
    var areas = AreaRepositoryMemoria();
    talhoes = TalhaoRepositoryMemoria();
    insumos = InsumoRepositoryMemoria();
    aplicadores = AplicadorRepositoryMemoria();
    operacoes = OperacaoRepositoryMemoria();
    aplicacoes = AplicacaoRepositoryMemoria();
    servico = criarServico();

    var sede = await areas.salvar(Area(nome: 'Sede'));
    var chico1 = Talhao(nome: 'Chico1', hectares: 2.8, area: sede);
    var chico2 = Talhao(nome: 'Chico2', hectares: 3.8, area: sede);
    await talhoes.salvar(chico1);
    await talhoes.salvar(chico2);
    var drone = Drone(
      modelo: 'DJI',
      capacidadeMaximaL: 70,
      capacidadeMaximaKg: 70,
    );
    await aplicadores.salvar(drone);
    var trator = Trator(id: 50);
    await aplicadores.salvar(trator);
    var operacao = Operacao(descricao: 'Pulverização');
    await operacoes.salvar(operacao);
    var orkestra = Insumo(nome: 'Orkestra SC', tipo: 'Fungicida');
    await insumos.salvar(orkestra);
    var boro = Insumo(nome: 'Boro Super', tipo: 'Fertilizante');
    await insumos.salvar(boro);

    idOperacao = operacao.id!;
    idDrone = drone.id!;
    idTrator = trator.id!;
    idChico1 = chico1.id!;
    idChico2 = chico2.id!;
    idOrkestra = orkestra.id!;
    idBoro = boro.id!;
  });

  group('registrar - fluxo principal', () {
    test('grava a aplicacao e devolve o resultado', () async {
      var resultado = await registrar();

      expect(resultado.aplicacao.id, 1);
      expect(resultado.aplicacao.areaTotalHa, closeTo(6.6, 1e-9));
      expect(resultado.aplicacao.talhoes.length, 2);
      expect((await aplicacoes.listarTodos()).length, 1);
      expect((await aplicacoes.listarPorTalhao(idChico2)).length, 1);
    });

    test('converte as doses para a base do banco', () async {
      var resultado = await registrar();
      var liquido = resultado.insumos[0].item;
      var solido = resultado.insumos[1].item;

      expect(liquido.unidade, UnidadeDose.litrosPorHectare);
      expect(liquido.dosePrevista, closeTo(0.3, 1e-9));
      expect(liquido.doseRealizada, closeTo(0.345, 1e-9));
      expect(solido.unidade, UnidadeDose.quilosPorHectare);
      expect(solido.dosePrevista, closeTo(0.5, 1e-9));
      expect(solido.doseRealizada, closeTo(0.45, 1e-9));
    });

    test('dose em L/1000L usa a taxa de aplicacao', () async {
      var dose = DoseInformada(
        insumoId: idOrkestra,
        dosePrevista: 2,
        unidade: 'L/1000L',
      );

      var resultado = await registrar(comDoses: [dose]);

      expect(resultado.insumos[0].item.dosePrevista, closeTo(0.02, 1e-9));
    });

    test('calcula o volume de calda e a massa de solidos', () async {
      var resultado = await registrar();

      expect(resultado.volumeCaldaL, closeTo(66, 1e-9));
      expect(resultado.massaProdutosKg, closeTo(3.3, 1e-9));
    });

    test('so liquidos: nao ha massa de solidos', () async {
      var resultado = await registrar(comDoses: [liquida()]);

      expect(resultado.volumeCaldaL, closeTo(66, 1e-9));
      expect(resultado.massaProdutosKg, isNull);
    });

    test('so solidos: nao ha volume de calda', () async {
      var resultado = await registrar(comDoses: [solida()]);

      expect(resultado.volumeCaldaL, isNull);
      expect(resultado.massaProdutosKg, closeTo(3.3, 1e-9));
    });

    test('calcula a quantidade prevista e a quantidade a comprar', () async {
      var resultado = await registrar();
      var liquido = resultado.insumos[0];
      var solido = resultado.insumos[1];

      expect(liquido.quantidadePrevista, closeTo(1.98, 1e-9));
      expect(liquido.quantidadeAComprar, closeTo(1.881, 1e-9));
      expect(solido.quantidadePrevista, closeTo(3.3, 1e-9));
      expect(solido.quantidadeAComprar, closeTo(3.135, 1e-9));
    });

    test('o fator de compra vem dos parametros', () async {
      servico = criarServico(fator: 0.9);

      var resultado = await registrar();

      expect(resultado.insumos[0].quantidadeAComprar, closeTo(1.782, 1e-9));
    });

    test('calcula o desperdicio e o status de sobredose', () async {
      var resultado = await registrar();
      var liquido = resultado.insumos[0];
      var solido = resultado.insumos[1];

      expect(liquido.percentualDesperdicio, closeTo(15, 1e-9));
      expect(liquido.statusSobredose, StatusSobredose.critico);
      expect(solido.percentualDesperdicio, closeTo(0, 1e-9));
      expect(solido.statusSobredose, StatusSobredose.ok);
    });

    test('a tolerancia vem dos parametros', () async {
      servico = criarServico(tolerancia: 25);

      var resultado = await registrar();

      expect(resultado.insumos[0].statusSobredose, StatusSobredose.atencao);
    });

    test('sem dose realizada nao ha desperdicio nem status', () async {
      var resultado = await registrar(comDoses: [liquida()]);
      var avaliacao = resultado.insumos[0];

      expect(avaliacao.item.doseRealizada, isNull);
      expect(avaliacao.percentualDesperdicio, isNull);
      expect(avaliacao.statusSobredose, isNull);
    });
  });

  group('registrar - chuva', () {
    test('sem informar a chuva, a decisao fica nula', () async {
      var resultado = await registrar();

      expect(resultado.chuva, isNull);
    });

    test('menos de 3 horas manda reaplicar', () async {
      var resultado = await registrar(comChuva: 2.5);

      expect(resultado.chuva, DecisaoChuva.reaplicar);
    });

    test('mais de 3 horas nao manda reaplicar', () async {
      var resultado = await registrar(comChuva: 4);

      expect(resultado.chuva, DecisaoChuva.naoReaplicar);
    });

    test('exatamente 3 horas nao reaplica (PENDENTE com a fazenda)', () async {
      var resultado = await registrar(comChuva: 3);

      expect(resultado.chuva, DecisaoChuva.naoReaplicar);
    });

    test('o limite vem dos parametros', () async {
      servico = criarServico(limiteChuva: 6);

      var resultado = await registrar(comChuva: 5);

      expect(resultado.chuva, DecisaoChuva.reaplicar);
    });

    test('horas negativas sao recusadas e nada e gravado', () async {
      await expectLater(registrar(comChuva: -1), recusaDado);

      expect(await aplicacoes.listarTodos(), isEmpty);
    });
  });

  group('registrar - capacidade do aplicador', () {
    test('calda acima da capacidade e recusada', () async {
      var mensagem = await mensagemDoErroAsync(() {
        return registrar(comTaxa: 20);
      });

      expect(mensagem, 'Capacidade excedida: 132 L (máximo 70 L)');
      expect(await aplicacoes.listarTodos(), isEmpty);
    });

    test('volume igual a capacidade cabe', () async {
      var exato = Drone(capacidadeMaximaL: 66);
      await aplicadores.salvar(exato);

      var resultado = await registrar(comAplicador: exato.id);

      expect(resultado.volumeCaldaL, closeTo(66, 1e-9));
    });

    test('massa de solidos acima da capacidade em kg e recusada', () async {
      var dose = DoseInformada(
        insumoId: idBoro,
        dosePrevista: 20000,
        unidade: 'g/ha',
      );

      var mensagem = await mensagemDoErroAsync(() {
        return registrar(comDoses: [dose]);
      });

      expect(mensagem, 'Capacidade excedida: 132 kg (máximo 70 kg)');
    });

    test('aplicador sem capacidade (trator) nao e conferido', () async {
      var resultado = await registrar(comTaxa: 100, comAplicador: idTrator);

      expect(resultado.volumeCaldaL, closeTo(660, 1e-9));
    });
  });

  group('registrar - dados invalidos (nada e gravado)', () {
    test('taxa zero, negativa ou invalida', () async {
      for (var taxa in [0.0, -5.0, double.nan, double.infinity]) {
        await expectLater(registrar(comTaxa: taxa), recusaDado);
      }

      expect(await aplicacoes.listarTodos(), isEmpty);
    });

    test('operacao que nao existe', () async {
      var mensagem = await mensagemDoErroAsync(() {
        return registrar(comOperacao: 99);
      });

      expect(mensagem, 'Registro não encontrado: operação 99');
    });

    test('aplicador que nao existe', () async {
      var mensagem = await mensagemDoErroAsync(() {
        return registrar(comAplicador: 99);
      });

      expect(mensagem, 'Registro não encontrado: aplicador 99');
    });

    test('talhao que nao existe', () async {
      var mensagem = await mensagemDoErroAsync(() {
        return registrar(comTalhoes: [idChico1, 99]);
      });

      expect(mensagem, 'Registro não encontrado: talhão 99');
    });

    test('insumo que nao existe', () async {
      var dose = DoseInformada(insumoId: 99, dosePrevista: 1, unidade: 'L/ha');

      var mensagem = await mensagemDoErroAsync(() {
        return registrar(comDoses: [dose]);
      });

      expect(mensagem, 'Registro não encontrado: insumo 99');
    });

    test('lista de talhoes ou de doses vazia', () async {
      await expectLater(registrar(comTalhoes: []), recusaDado);
      await expectLater(registrar(comDoses: []), recusaDado);
    });

    test('talhao ou insumo repetido', () async {
      var talhoesRepetidos = [idChico1, idChico1];
      var dosesRepetidas = [liquida(), liquida()];

      await expectLater(registrar(comTalhoes: talhoesRepetidos), recusaDado);
      await expectLater(registrar(comDoses: dosesRepetidas), recusaDado);
    });

    test('unidade desconhecida', () async {
      var dose = DoseInformada(
        insumoId: idOrkestra,
        dosePrevista: 1,
        unidade: 'caixa/ha',
      );

      var mensagem = await mensagemDoErroAsync(() {
        return registrar(comDoses: [dose]);
      });

      expect(
        mensagem,
        'Dado inválido: unidade da dose (Unidade desconhecida: caixa/ha)',
      );
    });

    test('unidade por 1000 L de produto solido ainda e recusada', () async {
      var dose = DoseInformada(
        insumoId: idBoro,
        dosePrevista: 100,
        unidade: 'g/1000L',
      );

      await expectLater(registrar(comDoses: [dose]), recusaDado);
    });

    test('dose prevista zero ou negativa', () async {
      var zero = DoseInformada(
        insumoId: idOrkestra,
        dosePrevista: 0,
        unidade: 'L/ha',
      );
      var negativa = DoseInformada(
        insumoId: idOrkestra,
        dosePrevista: -1,
        unidade: 'mL/ha',
      );

      var mensagemZero = await mensagemDoErroAsync(() {
        return registrar(comDoses: [zero]);
      });
      var mensagemNegativa = await mensagemDoErroAsync(() {
        return registrar(comDoses: [negativa]);
      });

      expect(mensagemZero, 'Dose inválida: 0.0 L/ha');
      expect(mensagemNegativa, 'Dose inválida: -1.0 mL/ha');
    });

    test('dose realizada negativa', () async {
      var mensagem = await mensagemDoErroAsync(() {
        return registrar(comDoses: [liquida(real: -5)]);
      });

      expect(mensagem, 'Dose inválida: -5.0 mL/ha');
    });
  });

  group('registrar - falhas do banco', () {
    test('banco fora do ar ao gravar vira PersistenciaException', () async {
      aplicacoes.bancoIndisponivel = true;

      var mensagem = await mensagemDoErroAsync(() {
        return registrar();
      });

      aplicacoes.bancoIndisponivel = false;
      expect(mensagem, 'Erro de persistência: salvar aplicação');
      expect(await aplicacoes.listarTodos(), isEmpty);
    });

    test('banco fora do ar ao buscar vira PersistenciaException', () async {
      talhoes.bancoIndisponivel = true;

      var mensagem = await mensagemDoErroAsync(() {
        return registrar();
      });

      expect(mensagem, 'Erro de persistência: buscar talhão');
    });
  });

  group('resumoDesperdicio', () {
    test('sem aplicacoes devolve mapa vazio', () async {
      expect(await servico.resumoDesperdicio(), isEmpty);
    });

    test('sem dose realizada nada entra no resumo', () async {
      await registrar(comDoses: [liquida()]);

      expect(await servico.resumoDesperdicio(), isEmpty);
    });

    test('soma as aplicacoes gravadas, separando litros de quilos', () async {
      await registrar();
      await registrar(comTalhoes: [idChico1]);

      var resumo = await servico.resumoDesperdicio();
      var litros = resumo['L/ha']!;
      var quilos = resumo['kg/ha']!;

      expect(litros.totalPrevisto, closeTo(2.82, 1e-9));
      expect(litros.totalRealizado, closeTo(3.243, 1e-9));
      expect(litros.volumeDesperdicado, closeTo(0.423, 1e-9));
      expect(litros.percentual, closeTo(15, 1e-9));
      expect(quilos.totalPrevisto, closeTo(4.7, 1e-9));
      expect(quilos.totalRealizado, closeTo(4.23, 1e-9));
      expect(quilos.volumeDesperdicado, closeTo(0, 1e-9));
    });
  });
}
