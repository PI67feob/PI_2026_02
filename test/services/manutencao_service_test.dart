import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';
import 'package:caderno_fazenda/exceptions/dose_invalida_exception.dart';
import 'package:caderno_fazenda/exceptions/exclusao_negada_exception.dart';
import 'package:caderno_fazenda/exceptions/persistencia_exception.dart';
import 'package:caderno_fazenda/models/aplicacao.dart';
import 'package:caderno_fazenda/models/area.dart';
import 'package:caderno_fazenda/models/drone.dart';
import 'package:caderno_fazenda/models/insumo.dart';
import 'package:caderno_fazenda/models/operacao.dart';
import 'package:caderno_fazenda/models/talhao.dart';
import 'package:caderno_fazenda/models/trator.dart';
import 'package:caderno_fazenda/repositories/memoria/repositorios_memoria.dart';
import 'package:caderno_fazenda/services/aplicacao_service.dart';
import 'package:caderno_fazenda/services/dose_informada.dart';
import 'package:caderno_fazenda/services/manutencao_service.dart';
import 'package:caderno_fazenda/services/parametros_operacionais.dart';
import 'package:test/test.dart';

import '../ajuda/erros.dart';

/// Repositório de áreas que nunca consegue remover: imita o registro que
/// sumiu entre a conferência e a exclusão.
class _AreaQueNaoRemove extends AreaRepositoryMemoria {
  @override
  Future<bool> remover(int id) async => false;
}

void main() {
  late AreaRepositoryMemoria areas;
  late TalhaoRepositoryMemoria talhoes;
  late InsumoRepositoryMemoria insumos;
  late AplicadorRepositoryMemoria aplicadores;
  late OperacaoRepositoryMemoria operacoes;
  late AplicacaoRepositoryMemoria aplicacoes;
  late ManutencaoService servico;
  late AplicacaoService registro;

  late Area sede;
  late Talhao chico1;
  late Talhao chico2;
  late Insumo orkestra;
  late Insumo boro;
  late Drone drone;
  late Trator trator;
  late Operacao pulverizacao;

  var recusaDado = throwsA(isA<DadoInvalidoException>());
  var recusaExclusao = throwsA(isA<ExclusaoNegadaException>());

  ManutencaoService criar(AreaRepositoryMemoria areasUsadas) {
    return ManutencaoService(
      areasUsadas,
      talhoes,
      insumos,
      aplicadores,
      operacoes,
      aplicacoes,
    );
  }

  // Registra uma aplicacao real, pelo servico, para os testes de exclusao e
  // de correcao partirem de dados como os do sistema.
  Future<Aplicacao> registrar({
    Talhao? talhao,
    Insumo? insumo,
    Operacao? operacao,
    Drone? aplicador,
    double? real,
  }) {
    var usado = insumo ?? orkestra;
    return registro
        .registrar(
          data: DateTime(2026, 11, 6),
          operacaoId: (operacao ?? pulverizacao).id!,
          aplicadorId: (aplicador ?? drone).id!,
          talhaoIds: [(talhao ?? chico1).id!],
          doses: [
            DoseInformada(
              insumoId: usado.id!,
              dosePrevista: 300,
              doseRealizada: real,
              unidade: usado == orkestra ? 'mL/ha' : 'g/ha',
            ),
          ],
          taxaLitrosPorHa: 10,
          observacao: 'primeira',
        )
        .then((resultado) => resultado.aplicacao);
  }

  setUp(() async {
    areas = AreaRepositoryMemoria();
    talhoes = TalhaoRepositoryMemoria();
    insumos = InsumoRepositoryMemoria();
    aplicadores = AplicadorRepositoryMemoria();
    operacoes = OperacaoRepositoryMemoria();
    aplicacoes = AplicacaoRepositoryMemoria();
    servico = criar(areas);
    registro = AplicacaoService(
      operacoes,
      aplicadores,
      talhoes,
      insumos,
      aplicacoes,
      ParametrosOperacionais(toleranciaSobredosePercentual: 10),
    );

    sede = await areas.salvar(Area(nome: 'Sede'));
    chico1 = await talhoes.salvar(
      Talhao(nome: 'Chico1', hectares: 2.8, area: sede),
    );
    chico2 = await talhoes.salvar(
      Talhao(nome: 'Chico2', hectares: 3.8, area: sede),
    );
    orkestra = await insumos.salvar(
      Insumo(nome: 'Orkestra SC', tipo: 'Fungicida'),
    );
    boro = await insumos.salvar(
      Insumo(nome: 'Boro Super', tipo: 'Fertilizante'),
    );
    drone = await aplicadores.salvar(
      Drone(modelo: 'DJI', capacidadeMaximaL: 70),
    ) as Drone;
    trator = await aplicadores.salvar(Trator()) as Trator;
    pulverizacao = await operacoes.salvar(Operacao(descricao: 'Pulverização'));
  });

  group('corrigirArea', () {
    test('troca o nome e grava', () async {
      var corrigida = await servico.corrigirArea(sede.id!, nome: 'Sede Nova');

      expect(corrigida.nome, 'Sede Nova');
      expect((await areas.buscarPorId(sede.id!))?.nome, 'Sede Nova');
    });

    test('mudar so as maiusculas da propria area e aceito', () async {
      var corrigida = await servico.corrigirArea(sede.id!, nome: 'SEDE');

      expect(corrigida.nome, 'SEDE');
    });

    test('nome vazio e recusado e o antigo fica', () async {
      await expectLater(servico.corrigirArea(sede.id!, nome: '  '), recusaDado);

      expect(sede.nome, 'Sede');
    });

    test('nome de outra area e recusado', () async {
      var fundos = await areas.salvar(Area(nome: 'Fundos'));

      var mensagem = await mensagemDoErroAsync(() {
        return servico.corrigirArea(fundos.id!, nome: 'sede');
      });

      expect(mensagem, 'Dado inválido: nome da área (já existe a área "Sede")');
      expect(fundos.nome, 'Fundos');
    });

    test('area que nao existe', () async {
      var mensagem = await mensagemDoErroAsync(() {
        return servico.corrigirArea(99, nome: 'X');
      });

      expect(mensagem, 'Registro não encontrado: área 99');
    });
  });

  group('corrigirInsumo', () {
    test('troca nome, tipo e marca', () async {
      var corrigido = await servico.corrigirInsumo(
        orkestra.id!,
        nome: 'Orkestra Ultra',
        tipo: 'Inseticida',
        marca: 'BASF',
      );

      expect(corrigido.nome, 'Orkestra Ultra');
      expect(corrigido.tipo, 'Inseticida');
      expect(corrigido.marca, 'BASF');
      expect((await insumos.buscarPorId(orkestra.id!))?.marca, 'BASF');
    });

    test('marca vazia tira a marca', () async {
      await servico.corrigirInsumo(
        orkestra.id!,
        nome: 'Orkestra SC',
        tipo: 'Fungicida',
        marca: 'BASF',
      );

      var corrigido = await servico.corrigirInsumo(
        orkestra.id!,
        nome: 'Orkestra SC',
        tipo: 'Fungicida',
      );

      expect(corrigido.marca, isNull);
    });

    test('nome ou tipo vazio e recusado e nada muda', () async {
      await expectLater(
        servico.corrigirInsumo(orkestra.id!, nome: '', tipo: 'Fungicida'),
        recusaDado,
      );
      await expectLater(
        servico.corrigirInsumo(orkestra.id!, nome: 'Novo', tipo: ' '),
        recusaDado,
      );

      expect(orkestra.nome, 'Orkestra SC');
      expect(orkestra.tipo, 'Fungicida');
    });

    test('mesmo nome e tipo de outro insumo e recusado', () async {
      var mensagem = await mensagemDoErroAsync(() {
        return servico.corrigirInsumo(
          boro.id!,
          nome: 'orkestra sc',
          tipo: 'fungicida',
        );
      });

      expect(
        mensagem,
        'Dado inválido: insumo (já existe "Orkestra SC" do tipo Fungicida)',
      );
      expect(boro.nome, 'Boro Super');
      expect(boro.tipo, 'Fertilizante');
    });

    test('mesmo nome em outro tipo e aceito', () async {
      var corrigido = await servico.corrigirInsumo(
        boro.id!,
        nome: 'Orkestra SC',
        tipo: 'Fertilizante',
      );

      expect(corrigido.nome, 'Orkestra SC');
    });

    test('insumo que nao existe', () async {
      var mensagem = await mensagemDoErroAsync(() {
        return servico.corrigirInsumo(99, nome: 'X', tipo: 'Y');
      });

      expect(mensagem, 'Registro não encontrado: insumo 99');
    });
  });

  group('corrigirAplicador', () {
    test('troca modelo e capacidades e mantem o tipo', () async {
      var corrigido = await servico.corrigirAplicador(
        drone.id!,
        modelo: 'Agras',
        capacidadeMaximaL: 40,
        capacidadeMaximaKg: 50,
      );

      expect(corrigido, isA<Drone>());
      expect(corrigido.modelo, 'Agras');
      expect(corrigido.capacidadeMaximaL, 40);
      expect(corrigido.capacidadeMaximaKg, 50);
    });

    test('null tira o modelo e as capacidades', () async {
      var corrigido = await servico.corrigirAplicador(drone.id!);

      expect(corrigido.modelo, isNull);
      expect(corrigido.capacidadeMaximaL, isNull);
      expect(corrigido.capacidadeMaximaKg, isNull);
    });

    test('capacidade zero ou negativa e recusada e nada muda', () async {
      await expectLater(
        servico.corrigirAplicador(
          drone.id!,
          modelo: 'Outro',
          capacidadeMaximaL: 0,
        ),
        recusaDado,
      );
      await expectLater(
        servico.corrigirAplicador(drone.id!, capacidadeMaximaKg: -3),
        recusaDado,
      );

      expect(drone.modelo, 'DJI');
      expect(drone.capacidadeMaximaL, 70);
    });

    test('trator ganha capacidade', () async {
      var corrigido = await servico.corrigirAplicador(
        trator.id!,
        capacidadeMaximaL: 600,
      );

      expect(corrigido, isA<Trator>());
      expect(corrigido.capacidadeMaximaL, 600);
    });

    test('aplicador que nao existe', () async {
      var mensagem = await mensagemDoErroAsync(() {
        return servico.corrigirAplicador(99);
      });

      expect(mensagem, 'Registro não encontrado: aplicador 99');
    });
  });

  group('corrigirOperacao', () {
    test('troca a descricao', () async {
      var corrigida = await servico.corrigirOperacao(
        pulverizacao.id!,
        descricao: 'Adubação',
      );

      expect(corrigida.descricao, 'Adubação');
      expect(
        (await operacoes.buscarPorId(pulverizacao.id!))?.descricao,
        'Adubação',
      );
    });

    test('descricao vazia ou de outra operacao e recusada', () async {
      var capina = await operacoes.salvar(Operacao(descricao: 'Capina'));

      await expectLater(
        servico.corrigirOperacao(capina.id!, descricao: ' '),
        recusaDado,
      );
      var mensagem = await mensagemDoErroAsync(() {
        return servico.corrigirOperacao(capina.id!, descricao: 'pulverização');
      });

      expect(
        mensagem,
        'Dado inválido: descrição da operação (já existe a operação "Pulverização")',
      );
      expect(capina.descricao, 'Capina');
    });

    test('operacao que nao existe', () async {
      var mensagem = await mensagemDoErroAsync(() {
        return servico.corrigirOperacao(99, descricao: 'X');
      });

      expect(mensagem, 'Registro não encontrado: operação 99');
    });
  });

  group('corrigirAplicacao', () {
    test('troca data, observacao e dose realizada', () async {
      var aplicacao = await registrar();

      var corrigida = await servico.corrigirAplicacao(
        aplicacao.id!,
        data: DateTime(2026, 11, 7, 15, 30),
        observacao: 'revisada',
        dosesRealizadas: {orkestra.id!: 0.345},
      );

      expect(corrigida.data, DateTime(2026, 11, 7));
      expect(corrigida.observacao, 'revisada');
      expect(corrigida.insumos.first.doseRealizada, 0.345);
      var gravada = await aplicacoes.buscarPorId(aplicacao.id!);
      expect(gravada?.insumos.first.doseRealizada, 0.345);
    });

    test('sem doses novas, as doses ficam como estao', () async {
      var aplicacao = await registrar(real: 310);

      var corrigida = await servico.corrigirAplicacao(
        aplicacao.id!,
        data: DateTime(2026, 11, 6),
        observacao: 'primeira',
      );

      expect(corrigida.insumos.first.doseRealizada, closeTo(0.31, 1e-9));
      expect(corrigida.insumos.first.dosePrevista, closeTo(0.3, 1e-9));
    });

    test('observacao nula tira o texto', () async {
      var aplicacao = await registrar();

      var corrigida = await servico.corrigirAplicacao(
        aplicacao.id!,
        data: DateTime(2026, 11, 6),
      );

      expect(corrigida.observacao, isNull);
    });

    test('dose realizada zero e aceita', () async {
      var aplicacao = await registrar();

      var corrigida = await servico.corrigirAplicacao(
        aplicacao.id!,
        data: DateTime(2026, 11, 6),
        dosesRealizadas: {orkestra.id!: 0},
      );

      expect(corrigida.insumos.first.doseRealizada, 0);
    });

    test('dose negativa e recusada e nada muda, nem a data', () async {
      var aplicacao = await registrar(real: 310);

      var mensagem = await mensagemDoErroAsync(() {
        return servico.corrigirAplicacao(
          aplicacao.id!,
          data: DateTime(2030, 1, 1),
          observacao: 'nao deveria gravar',
          dosesRealizadas: {orkestra.id!: -1},
        );
      });

      expect(mensagem, 'Dose inválida: -1.0 L/ha');
      expect(aplicacao.data, DateTime(2026, 11, 6));
      expect(aplicacao.observacao, 'primeira');
      expect(aplicacao.insumos.first.doseRealizada, closeTo(0.31, 1e-9));
    });

    test('dose invalida e recusada como DoseInvalidaException', () async {
      var aplicacao = await registrar();

      await expectLater(
        servico.corrigirAplicacao(
          aplicacao.id!,
          data: DateTime(2026, 11, 6),
          dosesRealizadas: {orkestra.id!: double.nan},
        ),
        throwsA(isA<DoseInvalidaException>()),
      );
    });

    test('insumo que nao faz parte da aplicacao e recusado', () async {
      var aplicacao = await registrar();

      var mensagem = await mensagemDoErroAsync(() {
        return servico.corrigirAplicacao(
          aplicacao.id!,
          data: DateTime(2026, 11, 6),
          dosesRealizadas: {boro.id!: 1},
        );
      });

      expect(
        mensagem,
        'Dado inválido: insumos (o insumo ${boro.id} não faz parte da aplicação)',
      );
    });

    test('aplicacao que nao existe', () async {
      var mensagem = await mensagemDoErroAsync(() {
        return servico.corrigirAplicacao(99, data: DateTime(2026, 11, 6));
      });

      expect(mensagem, 'Registro não encontrado: aplicação 99');
    });

    test('banco fora do ar ao gravar vira PersistenciaException', () async {
      var aplicacao = await registrar();
      aplicacoes.bancoIndisponivel = true;

      await expectLater(
        servico.corrigirAplicacao(aplicacao.id!, data: DateTime(2026, 11, 7)),
        throwsA(isA<PersistenciaException>()),
      );
    });
  });

  group('excluirArea', () {
    test('area sem talhoes e excluida', () async {
      var fundos = await areas.salvar(Area(nome: 'Fundos'));

      var excluida = await servico.excluirArea(fundos.id!);

      expect(excluida.nome, 'Fundos');
      expect(await areas.buscarPorId(fundos.id!), isNull);
    });

    test('area com um talhao e recusada', () async {
      var fundos = await areas.salvar(Area(nome: 'Fundos'));
      await talhoes.salvar(Talhao(nome: 'Brejo', hectares: 1, area: fundos));

      var mensagem = await mensagemDoErroAsync(() {
        return servico.excluirArea(fundos.id!);
      });

      expect(
        mensagem,
        'Exclusão negada: área Fundos (tem o talhão Brejo; exclua-o antes)',
      );
      expect(await areas.buscarPorId(fundos.id!), isNotNull);
    });

    test('area com varios talhoes lista todos', () async {
      var mensagem = await mensagemDoErroAsync(() {
        return servico.excluirArea(sede.id!);
      });

      expect(
        mensagem,
        'Exclusão negada: área Sede '
        '(tem os talhões Chico1 e Chico2; exclua-os antes)',
      );
    });

    test('com muitos talhoes, mostra cinco e conta o resto', () async {
      for (var i = 3; i <= 8; i++) {
        await talhoes.salvar(Talhao(nome: 'Chico$i', hectares: 1, area: sede));
      }

      var mensagem = await mensagemDoErroAsync(() {
        return servico.excluirArea(sede.id!);
      });

      expect(
        mensagem,
        'Exclusão negada: área Sede (tem os talhões '
        'Chico1, Chico2, Chico3, Chico4, Chico5 e mais 3; exclua-os antes)',
      );
    });

    test('apenasConferir nao exclui', () async {
      var fundos = await areas.salvar(Area(nome: 'Fundos'));

      await servico.excluirArea(fundos.id!, apenasConferir: true);

      expect(await areas.buscarPorId(fundos.id!), isNotNull);
    });

    test('registro que sumiu entre a conferencia e a exclusao', () async {
      var sumida = _AreaQueNaoRemove();
      var area = await sumida.salvar(Area(nome: 'Fantasma', id: 50));

      var mensagem = await mensagemDoErroAsync(() {
        return criar(sumida).excluirArea(area.id!);
      });

      expect(mensagem, 'Registro não encontrado: área ${area.id}');
    });
  });

  group('excluirTalhao', () {
    test('talhao sem aplicacao e excluido', () async {
      var excluido = await servico.excluirTalhao(chico2.id!);

      expect(excluido.nome, 'Chico2');
      expect(await talhoes.buscarPorId(chico2.id!), isNull);
      expect(await talhoes.buscarPorId(chico1.id!), isNotNull);
    });

    test('talhao usado em uma aplicacao e recusado', () async {
      var aplicacao = await registrar(talhao: chico1);

      var mensagem = await mensagemDoErroAsync(() {
        return servico.excluirTalhao(chico1.id!);
      });

      expect(
        mensagem,
        'Exclusão negada: talhão Chico1 '
        '(usado na aplicação ${aplicacao.id}; exclua-a antes)',
      );
      expect(await talhoes.buscarPorId(chico1.id!), isNotNull);
    });

    test('talhao usado em varias aplicacoes lista os ids', () async {
      var a1 = await registrar(talhao: chico1);
      var a2 = await registrar(talhao: chico1);
      var a3 = await registrar(talhao: chico1);

      var mensagem = await mensagemDoErroAsync(() {
        return servico.excluirTalhao(chico1.id!);
      });

      expect(
        mensagem,
        'Exclusão negada: talhão Chico1 (usado nas aplicações '
        '${a1.id}, ${a2.id} e ${a3.id}; exclua-as antes)',
      );
    });

    test('depois de excluir a aplicacao, o talhao pode ser excluido', () async {
      var aplicacao = await registrar(talhao: chico1);
      await expectLater(servico.excluirTalhao(chico1.id!), recusaExclusao);

      await servico.excluirAplicacao(aplicacao.id!);
      await servico.excluirTalhao(chico1.id!);

      expect(await talhoes.buscarPorId(chico1.id!), isNull);
    });

    test('apenasConferir nao exclui', () async {
      await servico.excluirTalhao(chico2.id!, apenasConferir: true);

      expect(await talhoes.buscarPorId(chico2.id!), isNotNull);
    });
  });

  group('excluirInsumo', () {
    test('insumo sem aplicacao e excluido', () async {
      var excluido = await servico.excluirInsumo(boro.id!);

      expect(excluido.nome, 'Boro Super');
      expect(await insumos.buscarPorId(boro.id!), isNull);
    });

    test('insumo usado e recusado e o outro insumo nao atrapalha', () async {
      var aplicacao = await registrar(insumo: orkestra);

      var mensagem = await mensagemDoErroAsync(() {
        return servico.excluirInsumo(orkestra.id!);
      });

      expect(
        mensagem,
        'Exclusão negada: insumo Orkestra SC '
        '(usado na aplicação ${aplicacao.id}; exclua-a antes)',
      );
      await servico.excluirInsumo(boro.id!);
    });
  });

  group('excluirAplicador', () {
    test('aplicador sem aplicacao e excluido', () async {
      var excluido = await servico.excluirAplicador(trator.id!);

      expect(excluido, isA<Trator>());
      expect(await aplicadores.buscarPorId(trator.id!), isNull);
    });

    test('aplicador usado e recusado', () async {
      var aplicacao = await registrar();

      var mensagem = await mensagemDoErroAsync(() {
        return servico.excluirAplicador(drone.id!);
      });

      expect(
        mensagem,
        'Exclusão negada: aplicador drone DJI '
        '(usado na aplicação ${aplicacao.id}; exclua-a antes)',
      );
    });

    test('aplicador sem modelo aparece pelo id', () async {
      var semModelo = await _outroDrone(aplicadores);
      await registrar(aplicador: semModelo);

      var mensagem = await mensagemDoErroAsync(() {
        return servico.excluirAplicador(semModelo.id!);
      });

      expect(mensagem, startsWith('Exclusão negada: aplicador drone '));
      expect(mensagem, contains('aplicador drone ${semModelo.id} (usado'));
    });
  });

  group('excluirOperacao', () {
    test('operacao sem aplicacao e excluida', () async {
      var capina = await operacoes.salvar(Operacao(descricao: 'Capina'));

      var excluida = await servico.excluirOperacao(capina.id!);

      expect(excluida.descricao, 'Capina');
      expect(await operacoes.buscarPorId(capina.id!), isNull);
    });

    test('operacao usada e recusada no feminino', () async {
      var aplicacao = await registrar();

      var mensagem = await mensagemDoErroAsync(() {
        return servico.excluirOperacao(pulverizacao.id!);
      });

      expect(
        mensagem,
        'Exclusão negada: operação Pulverização '
        '(usada na aplicação ${aplicacao.id}; exclua-a antes)',
      );
    });
  });

  group('excluirAplicacao', () {
    test('exclui a aplicacao e mantem os cadastros', () async {
      var aplicacao = await registrar();

      var excluida = await servico.excluirAplicacao(aplicacao.id!);

      expect(excluida.id, aplicacao.id);
      expect(await aplicacoes.listarTodos(), isEmpty);
      expect(await talhoes.buscarPorId(chico1.id!), isNotNull);
      expect(await insumos.buscarPorId(orkestra.id!), isNotNull);
      expect(await aplicadores.buscarPorId(drone.id!), isNotNull);
      expect(await operacoes.buscarPorId(pulverizacao.id!), isNotNull);
    });

    test('apenasConferir nao exclui', () async {
      var aplicacao = await registrar();

      await servico.excluirAplicacao(aplicacao.id!, apenasConferir: true);

      expect(await aplicacoes.listarTodos(), hasLength(1));
    });
  });

  group('registros que nao existem', () {
    test('toda exclusao avisa que o id nao existe', () async {
      var mensagens = [
        await mensagemDoErroAsync(() => servico.excluirArea(99)),
        await mensagemDoErroAsync(() => servico.excluirTalhao(99)),
        await mensagemDoErroAsync(() => servico.excluirInsumo(99)),
        await mensagemDoErroAsync(() => servico.excluirAplicador(99)),
        await mensagemDoErroAsync(() => servico.excluirOperacao(99)),
        await mensagemDoErroAsync(() => servico.excluirAplicacao(99)),
      ];

      expect(mensagens, [
        'Registro não encontrado: área 99',
        'Registro não encontrado: talhão 99',
        'Registro não encontrado: insumo 99',
        'Registro não encontrado: aplicador 99',
        'Registro não encontrado: operação 99',
        'Registro não encontrado: aplicação 99',
      ]);
    });
  });

  group('falhas do banco', () {
    test(
      'banco fora do ar na conferencia vira PersistenciaException',
      () async {
        aplicacoes.bancoIndisponivel = true;

        await expectLater(
          servico.excluirTalhao(chico1.id!),
          throwsA(isA<PersistenciaException>()),
        );
        expect(await talhoes.buscarPorId(chico1.id!), isNotNull);
      },
    );
  });
}

Future<Drone> _outroDrone(AplicadorRepositoryMemoria repositorio) async {
  return await repositorio.salvar(Drone(capacidadeMaximaL: 20)) as Drone;
}
