import 'package:caderno_fazenda/exceptions/persistencia_exception.dart';
import 'package:caderno_fazenda/models/aplicacao.dart';
import 'package:caderno_fazenda/models/aplicacao_insumo.dart';
import 'package:caderno_fazenda/models/area.dart';
import 'package:caderno_fazenda/models/bomba_costal.dart';
import 'package:caderno_fazenda/models/drone.dart';
import 'package:caderno_fazenda/models/insumo.dart';
import 'package:caderno_fazenda/models/operacao.dart';
import 'package:caderno_fazenda/models/talhao.dart';
import 'package:caderno_fazenda/models/unidade_dose.dart';
import 'package:caderno_fazenda/repositories/interfaces/repository.dart';
import 'package:caderno_fazenda/repositories/memoria/repositorios_memoria.dart';
import 'package:test/test.dart';

import '../ajuda/erros.dart';

void main() {
  group('RepositoryMemoria (testado pelas areas)', () {
    late AreaRepositoryMemoria repositorio;

    setUp(() {
      repositorio = AreaRepositoryMemoria();
    });

    test('salvar gera ids em sequencia', () async {
      var sede = Area(nome: 'Sede');
      var fundos = Area(nome: 'Fundos');

      var salva = await repositorio.salvar(sede);
      await repositorio.salvar(fundos);

      expect(salva, same(sede));
      expect(sede.id, 1);
      expect(fundos.id, 2);
    });

    test('salvar respeita o id informado e continua depois dele', () async {
      await repositorio.salvar(Area(nome: 'Sede', id: 10));
      var nova = await repositorio.salvar(Area(nome: 'Fundos'));

      expect(nova.id, 11);
    });

    test('salvar de novo atualiza em vez de duplicar', () async {
      var sede = Area(nome: 'Sede');
      await repositorio.salvar(sede);

      sede.nome = 'Sede nova';
      await repositorio.salvar(sede);

      var todas = await repositorio.listarTodos();
      expect(todas.length, 1);
      expect(todas.first.nome, 'Sede nova');
    });

    test('buscarPorId devolve nulo quando nao existe', () async {
      expect(await repositorio.buscarPorId(99), isNull);
    });

    test('listarTodos vem em ordem crescente de id', () async {
      await repositorio.salvar(Area(nome: 'C', id: 3));
      await repositorio.salvar(Area(nome: 'A', id: 1));
      await repositorio.salvar(Area(nome: 'B', id: 2));

      var todas = await repositorio.listarTodos();
      var ids = todas.map((area) => area.id).toList();

      expect(ids, [1, 2, 3]);
    });

    test('remover diz se o registro existia', () async {
      await repositorio.salvar(Area(nome: 'Sede'));

      expect(await repositorio.remover(1), isTrue);
      expect(await repositorio.remover(1), isFalse);
      expect(await repositorio.buscarPorId(1), isNull);
    });

    test('exigirPorId devolve o registro quando existe', () async {
      var sede = await repositorio.salvar(Area(nome: 'Sede'));

      expect(await repositorio.exigirPorId(1, 'área'), same(sede));
    });

    test('exigirPorId lanca quando o registro nao existe', () async {
      var mensagem = await mensagemDoErroAsync(() {
        return repositorio.exigirPorId(99, 'área');
      });

      expect(mensagem, 'Registro não encontrado: área 99');
    });

    test('buscarPorNome ignora maiusculas e espacos', () async {
      await repositorio.salvar(Area(nome: 'Sede'));

      var achada = await repositorio.buscarPorNome(' SEDE ');

      expect(achada?.nome, 'Sede');
      expect(await repositorio.buscarPorNome('Fundos'), isNull);
    });
  });

  group('TalhaoRepositoryMemoria', () {
    var sede = Area(nome: 'Sede', id: 1);
    var fundos = Area(nome: 'Fundos', id: 2);
    late TalhaoRepositoryMemoria repositorio;

    Talhao talhao(String nome, Area area) {
      return Talhao(nome: nome, hectares: 2, area: area);
    }

    setUp(() {
      repositorio = TalhaoRepositoryMemoria();
    });

    test('nao aceita o mesmo nome na mesma area', () async {
      await repositorio.salvar(talhao('Chico1', sede));

      var mensagem = await mensagemDoErroAsync(() {
        return repositorio.salvar(talhao('Chico1', sede));
      });

      expect(mensagem, 'Erro de persistência: salvar talhão');
    });

    test('compara o nome sem diferenciar maiusculas', () async {
      await repositorio.salvar(talhao('Chico1', sede));

      await expectLater(
        repositorio.salvar(talhao(' chico1 ', sede)),
        throwsA(isA<PersistenciaException>()),
      );
    });

    test('aceita o mesmo nome em areas diferentes', () async {
      await repositorio.salvar(talhao('Chico1', sede));
      await repositorio.salvar(talhao('Chico1', fundos));

      expect((await repositorio.listarTodos()).length, 2);
    });

    test('salvar o mesmo talhao de novo nao conflita', () async {
      var chico = talhao('Chico1', sede);
      await repositorio.salvar(chico);

      chico.hectares = 5;
      await repositorio.salvar(chico);

      expect((await repositorio.listarTodos()).length, 1);
    });

    test('buscarPorAreaENome e listarPorArea', () async {
      await repositorio.salvar(talhao('Chico1', sede));
      await repositorio.salvar(talhao('Chico2', sede));
      await repositorio.salvar(talhao('Chico1', fundos));

      var achado = await repositorio.buscarPorAreaENome(1, 'CHICO2');
      var daSede = await repositorio.listarPorArea(1);

      expect(achado?.nome, 'Chico2');
      expect(await repositorio.buscarPorAreaENome(2, 'Chico2'), isNull);
      expect(daSede.length, 2);
      expect(await repositorio.listarPorArea(99), isEmpty);
    });
  });

  test('insumos: listarPorTipo ignora maiusculas', () async {
    var repositorio = InsumoRepositoryMemoria();
    await repositorio.salvar(Insumo(nome: 'Orkestra SC', tipo: 'Fungicida'));
    await repositorio.salvar(Insumo(nome: 'Roundup', tipo: 'Herbicida'));

    var fungicidas = await repositorio.listarPorTipo('fungicida');

    expect(fungicidas.length, 1);
    expect(fungicidas.first.nome, 'Orkestra SC');
  });

  test('aplicadores: listarPorTipo usa o tipo da subclasse', () async {
    var repositorio = AplicadorRepositoryMemoria();
    await repositorio.salvar(Drone(modelo: 'DJI'));
    await repositorio.salvar(BombaCostal(modelo: 'Jacto'));
    await repositorio.salvar(BombaCostal(modelo: 'Jacto'));

    expect((await repositorio.listarPorTipo('bomba costal')).length, 2);
    expect((await repositorio.listarPorTipo('drone')).length, 1);
    expect(await repositorio.listarPorTipo('trator'), isEmpty);
  });

  test('operacoes: buscarPorDescricao ignora maiusculas', () async {
    var repositorio = OperacaoRepositoryMemoria();
    await repositorio.salvar(Operacao(descricao: 'Pulverização'));

    var achada = await repositorio.buscarPorDescricao(' pulverização ');

    expect(achada?.descricao, 'Pulverização');
    expect(await repositorio.buscarPorDescricao('Adubação'), isNull);
  });

  group('AplicacaoRepositoryMemoria', () {
    var sede = Area(nome: 'Sede', id: 1);
    var chico1 = Talhao(nome: 'Chico1', hectares: 2.8, area: sede, id: 1);
    var chico2 = Talhao(nome: 'Chico2', hectares: 3.8, area: sede, id: 2);
    var operacao = Operacao(descricao: 'Pulverização', id: 1);
    var drone = Drone(modelo: 'DJI', id: 1);
    var orkestra = Insumo(nome: 'Orkestra SC', tipo: 'Fungicida', id: 1);
    late AplicacaoRepositoryMemoria repositorio;

    Aplicacao aplicacao(Talhao talhao, DateTime data) {
      var item = AplicacaoInsumo(
        insumo: orkestra,
        unidade: UnidadeDose.litrosPorHectare,
        dosePrevista: 0.3,
      );
      return Aplicacao(
        data: data,
        operacao: operacao,
        aplicador: drone,
        talhoes: [talhao],
        insumos: [item],
      );
    }

    setUp(() {
      repositorio = AplicacaoRepositoryMemoria();
    });

    test('listarPorTalhao acha as aplicacoes que usaram o talhao', () async {
      await repositorio.salvar(aplicacao(chico1, DateTime(2026, 11, 1)));
      await repositorio.salvar(aplicacao(chico2, DateTime(2026, 11, 2)));
      await repositorio.salvar(aplicacao(chico1, DateTime(2026, 11, 3)));

      expect((await repositorio.listarPorTalhao(1)).length, 2);
      expect((await repositorio.listarPorTalhao(2)).length, 1);
      expect(await repositorio.listarPorTalhao(9), isEmpty);
    });

    test('listarPorPeriodo inclui os dois extremos', () async {
      await repositorio.salvar(aplicacao(chico1, DateTime(2026, 11, 1)));
      await repositorio.salvar(aplicacao(chico1, DateTime(2026, 11, 5)));
      await repositorio.salvar(aplicacao(chico1, DateTime(2026, 11, 9)));

      var achadas = await repositorio.listarPorPeriodo(
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 5),
      );

      expect(achadas.length, 2);
    });
  });

  group('banco fora do ar', () {
    test('toda operacao falha com PersistenciaException', () async {
      var repositorio = AreaRepositoryMemoria();
      var sede = await repositorio.salvar(Area(nome: 'Sede'));
      var recusa = throwsA(isA<PersistenciaException>());

      repositorio.bancoIndisponivel = true;

      await expectLater(repositorio.salvar(Area(nome: 'Nova')), recusa);
      await expectLater(repositorio.buscarPorId(1), recusa);
      await expectLater(repositorio.buscarPorNome('Sede'), recusa);
      await expectLater(repositorio.listarTodos(), recusa);
      await expectLater(repositorio.remover(1), recusa);

      repositorio.bancoIndisponivel = false;

      expect(await repositorio.buscarPorId(1), same(sede));
    });

    test('a mensagem nao mostra a causa tecnica', () async {
      var repositorio = AreaRepositoryMemoria();
      repositorio.bancoIndisponivel = true;

      var mensagem = await mensagemDoErroAsync(() {
        return repositorio.listarTodos();
      });

      expect(mensagem, 'Erro de persistência: listar área');
    });
  });
}
