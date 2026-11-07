import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';
import 'package:caderno_fazenda/exceptions/talhao_invalido_exception.dart';
import 'package:caderno_fazenda/models/area.dart';
import 'package:caderno_fazenda/models/talhao.dart';
import 'package:caderno_fazenda/repositories/memoria/repositorios_memoria.dart';
import 'package:caderno_fazenda/services/talhao_service.dart';
import 'package:test/test.dart';

import '../ajuda/erros.dart';

void main() {
  late TalhaoRepositoryMemoria talhoes;
  late TalhaoService servico;
  late int idSede;
  late int idFundos;

  Future<Talhao> cadastrar(String nome, {int? area, double hectares = 2}) {
    return servico.cadastrar(
      areaId: area ?? idSede,
      nome: nome,
      hectares: hectares,
    );
  }

  setUp(() async {
    var areas = AreaRepositoryMemoria();
    talhoes = TalhaoRepositoryMemoria();
    servico = TalhaoService(areas, talhoes);
    var sede = await areas.salvar(Area(nome: 'Sede'));
    var fundos = await areas.salvar(Area(nome: 'Fundos'));
    idSede = sede.id!;
    idFundos = fundos.id!;
  });

  group('cadastrar', () {
    test('grava o talhao e devolve com id', () async {
      var talhao = await cadastrar('Chico1', hectares: 2.8);

      expect(talhao.id, 1);
      expect(talhao.hectares, 2.8);
      expect(talhao.area.nome, 'Sede');
      expect(await talhoes.buscarPorId(1), same(talhao));
    });

    test('area que nao existe lanca RegistroNaoEncontrado', () async {
      var mensagem = await mensagemDoErroAsync(() {
        return cadastrar('Chico1', area: 99);
      });

      expect(mensagem, 'Registro não encontrado: área 99');
    });

    test('nome repetido na mesma area e recusado', () async {
      await cadastrar('Chico1');

      var mensagem = await mensagemDoErroAsync(() {
        return cadastrar('CHICO1');
      });

      expect(mensagem, 'Talhão inválido: CHICO1 (já existe nesta área)');
      expect((await talhoes.listarTodos()).length, 1);
    });

    test('o mesmo nome em outra area e aceito', () async {
      await cadastrar('Chico1');
      await cadastrar('Chico1', area: idFundos);

      expect((await talhoes.listarTodos()).length, 2);
    });

    test('hectares invalidos lancam TalhaoInvalidoException', () async {
      for (var hectares in [0.0, -1.0, double.nan]) {
        await expectLater(
          cadastrar('Chico1', hectares: hectares),
          throwsA(isA<TalhaoInvalidoException>()),
        );
      }
      expect(await talhoes.listarTodos(), isEmpty);
    });

    test('nome vazio lanca DadoInvalidoException', () async {
      await expectLater(cadastrar('  '), throwsA(isA<DadoInvalidoException>()));
    });

    test('banco fora do ar vira PersistenciaException', () async {
      talhoes.bancoIndisponivel = true;

      var mensagem = await mensagemDoErroAsync(() {
        return cadastrar('Chico1');
      });

      expect(mensagem, 'Erro de persistência: buscar talhão');
    });
  });

  group('listarPorArea', () {
    test('devolve so os talhoes da area', () async {
      await cadastrar('Chico1');
      await cadastrar('Chico2');
      await cadastrar('Fundo1', area: idFundos);

      var daSede = await servico.listarPorArea(idSede);
      var dosFundos = await servico.listarPorArea(idFundos);

      expect(daSede.length, 2);
      expect(dosFundos.length, 1);
      expect(dosFundos.first.nome, 'Fundo1');
    });

    test('area que nao existe lanca RegistroNaoEncontrado', () async {
      var mensagem = await mensagemDoErroAsync(() {
        return servico.listarPorArea(99);
      });

      expect(mensagem, 'Registro não encontrado: área 99');
    });
  });

  group('corrigirHectares', () {
    test('atualiza o talhao gravado', () async {
      var talhao = await cadastrar('Chico1', hectares: 2.8);

      await servico.corrigirHectares(talhao.id!, 3.1);

      var gravado = await talhoes.buscarPorId(talhao.id!);
      expect(gravado?.hectares, 3.1);
    });

    test('valor invalido mantem o antigo', () async {
      var talhao = await cadastrar('Chico1', hectares: 2.8);

      await expectLater(
        servico.corrigirHectares(talhao.id!, 0),
        throwsA(isA<TalhaoInvalidoException>()),
      );

      expect(talhao.hectares, 2.8);
    });

    test('talhao que nao existe lanca RegistroNaoEncontrado', () async {
      var mensagem = await mensagemDoErroAsync(() {
        return servico.corrigirHectares(99, 2);
      });

      expect(mensagem, 'Registro não encontrado: talhão 99');
    });
  });
}
