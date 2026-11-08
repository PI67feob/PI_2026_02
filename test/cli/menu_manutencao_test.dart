import 'package:caderno_fazenda/cli/dados_exemplo.dart';
import 'package:caderno_fazenda/cli/menu_caderno.dart';
import 'package:caderno_fazenda/models/aplicacao.dart';
import 'package:caderno_fazenda/models/area.dart';
import 'package:caderno_fazenda/models/operacao.dart';
import 'package:caderno_fazenda/repositories/memoria/repositorios_memoria.dart';
import 'package:caderno_fazenda/repositories/repositorios.dart';
import 'package:caderno_fazenda/services/aplicacao_service.dart';
import 'package:caderno_fazenda/services/dose_informada.dart';
import 'package:caderno_fazenda/services/parametros_operacionais.dart';
import 'package:test/test.dart';

import '../ajuda/terminal_simulado.dart';

/// O que sobrou de uma sessão do menu: o texto da tela e quantas respostas
/// ficaram sem uso.
class _Sessao {
  final String saida;
  final int respostasRestantes;

  const _Sessao(this.saida, this.respostasRestantes);
}

/// Roda o menu principal com as [respostas] prontas, em memória e com a data
/// fixada em 07/11/2026.
Future<_Sessao> _rodar(
  List<String> respostas,
  Repositorios repositorios,
) async {
  final terminal = TerminalSimulado(respostas);
  final menu = MenuCaderno(
    repositorios,
    terminal,
    agora: () => DateTime(2026, 11, 7),
  );
  await menu.executar();
  return _Sessao(terminal.saida, terminal.respostasRestantes);
}

/// Abre "Corrigir um registro" (opção 8), escolhe a [opcao], dá as [respostas]
/// e sai: volta do submenu (0) e sai do programa (0).
Future<_Sessao> _corrigir(
  Repositorios repositorios,
  String opcao,
  List<String> respostas,
) {
  return _rodar(['8', opcao, ...respostas, '0', '0'], repositorios);
}

/// Abre "Excluir um registro" (opção 9), escolhe a [opcao], dá as [respostas]
/// e sai.
Future<_Sessao> _excluir(
  Repositorios repositorios,
  String opcao,
  List<String> respostas,
) {
  return _rodar(['9', opcao, ...respostas, '0', '0'], repositorios);
}

/// Repositórios em memória com os cadastros de exemplo (ids: área 1, talhões 1
/// e 2, drone 1, operação 1, insumos 1 = Orkestra SC e 2 = Boro Super).
Future<Repositorios> _comExemplo() async {
  final repos = Repositorios.memoria();
  await garantirDadosExemplo(repos);
  return repos;
}

/// Os cadastros de exemplo mais uma aplicação (id 1) nos dois talhões, com
/// Orkestra SC (300 mL/ha = 0,3 L/ha) e Boro Super (20 kg/ha), sem dose
/// realizada.
Future<Repositorios> _comAplicacao() async {
  final repos = await _comExemplo();
  final servico = AplicacaoService(
    repos.operacoes,
    repos.aplicadores,
    repos.talhoes,
    repos.insumos,
    repos.aplicacoes,
    ParametrosOperacionais(toleranciaSobredosePercentual: 10),
  );
  await servico.registrar(
    data: DateTime(2026, 11, 7),
    operacaoId: 1,
    aplicadorId: 1,
    talhaoIds: [1, 2],
    doses: [
      DoseInformada(insumoId: 1, dosePrevista: 300, unidade: 'mL/ha'),
      DoseInformada(insumoId: 2, dosePrevista: 20, unidade: 'kg/ha'),
    ],
    taxaLitrosPorHa: 10,
  );
  return repos;
}

/// Repositórios que se dizem persistentes (como o MySQL), mas guardam na
/// memória, para ver o aviso de que a exclusão atinge o banco da equipe.
Repositorios _compartilhado() {
  return Repositorios(
    origem: 'banco de teste',
    persistente: true,
    areas: AreaRepositoryMemoria(),
    talhoes: TalhaoRepositoryMemoria(),
    insumos: InsumoRepositoryMemoria(),
    aplicadores: AplicadorRepositoryMemoria(),
    operacoes: OperacaoRepositoryMemoria(),
    aplicacoes: AplicacaoRepositoryMemoria(),
  );
}

Future<Aplicacao> _aplicacao(Repositorios repos) async {
  final aplicacao = await repos.aplicacoes.buscarPorId(1);
  return aplicacao!;
}

void main() {
  group('no menu principal', () {
    test('as opções 8 e 9 abrem corrigir e excluir', () async {
      final sessao = await _rodar([
        '8',
        '0',
        '9',
        '0',
        '0',
      ], Repositorios.memoria());
      expect(sessao.saida, contains('8. Corrigir um registro'));
      expect(sessao.saida, contains('9. Excluir um registro'));
      expect(sessao.saida, contains('=== CORRIGIR UM REGISTRO ==='));
      expect(sessao.saida, contains('=== EXCLUIR UM REGISTRO ==='));
      expect(sessao.respostasRestantes, 0);
    });

    test('os números antigos do menu continuam os mesmos', () async {
      final sessao = await _rodar(['0'], Repositorios.memoria());
      expect(sessao.saida, contains('1. Cadastros'));
      expect(sessao.saida, contains('2. Registrar aplicação'));
      expect(sessao.saida, contains('5. Calculadora'));
      expect(sessao.saida, contains('7. Carregar dados de exemplo'));
    });
  });

  group('corrigir - menu', () {
    test('lista os seis tipos de registro', () async {
      final sessao = await _rodar(['8', '0', '0'], Repositorios.memoria());
      expect(sessao.saida, contains('1. Área (nome)'));
      expect(sessao.saida, contains('2. Talhão (nome e hectares)'));
      expect(sessao.saida, contains('3. Insumo (nome, tipo e marca)'));
      expect(sessao.saida, contains('4. Aplicador (modelo e capacidades)'));
      expect(sessao.saida, contains('5. Operação (descrição)'));
      expect(
        sessao.saida,
        contains('6. Aplicação (data, observação e dose realizada)'),
      );
      expect(sessao.saida, contains('Enter mantém o valor atual'));
    });

    test('avisa quando não há nada cadastrado para corrigir', () async {
      final sessao = await _rodar([
        '8', '1', '2', '3', '4', '5', '6', '0', '0', //
      ], Repositorios.memoria());
      expect(sessao.saida, contains('Nenhuma área cadastrada.'));
      expect(sessao.saida, contains('Nenhum talhão cadastrado.'));
      expect(sessao.saida, contains('Nenhum insumo cadastrado.'));
      expect(sessao.saida, contains('Nenhum aplicador cadastrado.'));
      expect(sessao.saida, contains('Nenhuma operação cadastrada.'));
      expect(sessao.saida, contains('Nenhuma aplicação registrada.'));
      expect(sessao.respostasRestantes, 0);
    });

    test('Enter na hora de escolher o id volta sem mudar nada', () async {
      final repos = await _comExemplo();
      final sessao = await _corrigir(repos, '1', ['']);
      expect(sessao.saida, isNot(contains('Vai mudar')));
      expect(sessao.respostasRestantes, 0);
    });

    test('id que não está na lista é perguntado de novo', () async {
      final repos = await _comExemplo();
      final sessao = await _corrigir(repos, '1', ['99', '']);
      expect(sessao.saida, contains('Esse id não está na lista'));
    });
  });

  group('corrigir - área', () {
    test('troca o nome', () async {
      final repos = await _comExemplo();
      final sessao = await _corrigir(repos, '1', ['1', 'Fazenda Sede', '']);
      expect(sessao.saida, contains('nome: Sede -> Fazenda Sede'));
      expect(sessao.saida, contains('Área corrigida: [1] Fazenda Sede'));
      expect((await repos.areas.buscarPorId(1))?.nome, 'Fazenda Sede');
    });

    test('Enter em tudo não muda nada', () async {
      final repos = await _comExemplo();
      final sessao = await _corrigir(repos, '1', ['1', '']);
      expect(sessao.saida, contains('Nada foi alterado.'));
      expect(sessao.saida, isNot(contains('Salvar a correção?')));
      expect((await repos.areas.buscarPorId(1))?.nome, 'Sede');
    });

    test('responder não na confirmação não grava', () async {
      final repos = await _comExemplo();
      final sessao = await _corrigir(repos, '1', ['1', 'Outra', 'n']);
      expect(sessao.saida, contains('Cancelado. Nada foi alterado.'));
      expect((await repos.areas.buscarPorId(1))?.nome, 'Sede');
    });

    test('recusa o nome de outra área e continua no menu', () async {
      final repos = await _comExemplo();
      await repos.areas.salvar(Area(nome: 'Norte'));
      final sessao = await _corrigir(repos, '1', ['2', 'sede', '']);
      expect(sessao.saida, contains('Não foi possível concluir:'));
      expect(sessao.saida, contains('já existe a área "Sede"'));
      expect((await repos.areas.buscarPorId(2))?.nome, 'Norte');
      expect(sessao.respostasRestantes, 0);
    });
  });

  group('corrigir - talhão', () {
    test('troca o nome e os hectares', () async {
      final repos = await _comExemplo();
      final sessao = await _corrigir(repos, '2', ['1', 'Chico1A', '3,1', '']);
      expect(sessao.saida, contains('nome: Chico1 -> Chico1A'));
      expect(sessao.saida, contains('hectares: 2,8 -> 3,1'));
      expect(
        sessao.saida,
        contains('Talhão corrigido: [1] Sede / Chico1A - 3,10 ha'),
      );
      final talhao = await repos.talhoes.buscarPorId(1);
      expect(talhao?.nome, 'Chico1A');
      expect(talhao?.hectares, 3.1);
    });

    test('diz que a área do talhão não muda', () async {
      final repos = await _comExemplo();
      final sessao = await _corrigir(repos, '2', ['1', '']);
      expect(sessao.saida, contains('A área do talhão (Sede) não muda aqui.'));
    });

    test('mudar só o nome não mexe nos hectares', () async {
      final repos = await _comExemplo();
      await _corrigir(repos, '2', ['2', 'Chico2B', '', '']);
      final talhao = await repos.talhoes.buscarPorId(2);
      expect(talhao?.nome, 'Chico2B');
      expect(talhao?.hectares, 3.8);
    });

    test(
      'repete a pergunta dos hectares até receber um valor válido',
      () async {
        final repos = await _comExemplo();
        final sessao = await _corrigir(repos, '2', [
          '1', '', '0', 'muito', '2,9', '', //
        ]);
        expect(sessao.saida, contains('O valor precisa ser maior que 0.'));
        expect(sessao.saida, contains('Número inválido.'));
        expect((await repos.talhoes.buscarPorId(1))?.hectares, 2.9);
      },
    );

    test('recusa o nome de outro talhão da mesma área', () async {
      final repos = await _comExemplo();
      final sessao = await _corrigir(repos, '2', ['1', 'Chico2', '', '']);
      expect(sessao.saida, contains('já existe nesta área'));
      expect((await repos.talhoes.buscarPorId(1))?.nome, 'Chico1');
    });

    test('avisa quando aplicações já registradas usam o talhão', () async {
      final repos = await _comAplicacao();
      final sessao = await _corrigir(repos, '2', ['1', '', '3,1', '']);
      expect(
        sessao.saida,
        contains(
          'Atenção: 1 aplicação já registrada usa este talhão: a área e as '
          'quantidades dela passam a ser calculadas com o novo tamanho.',
        ),
      );
      expect((await repos.talhoes.buscarPorId(1))?.hectares, 3.1);
      expect((await _aplicacao(repos)).areaTotalHa, closeTo(6.9, 1e-9));
    });

    test('no plural, o aviso fala de todas as aplicações', () async {
      final repos = await _comAplicacao();
      final servico = AplicacaoService(
        repos.operacoes,
        repos.aplicadores,
        repos.talhoes,
        repos.insumos,
        repos.aplicacoes,
        ParametrosOperacionais(toleranciaSobredosePercentual: 10),
      );
      await servico.registrar(
        data: DateTime(2026, 11, 8),
        operacaoId: 1,
        aplicadorId: 1,
        talhaoIds: [1],
        doses: [
          DoseInformada(insumoId: 1, dosePrevista: 300, unidade: 'mL/ha'),
        ],
        taxaLitrosPorHa: 10,
      );
      final sessao = await _corrigir(repos, '2', ['1', '', '3,1', '']);
      expect(
        sessao.saida,
        contains(
          'Atenção: 2 aplicações já registradas usam este talhão: a área e as '
          'quantidades delas passam a ser calculadas com o novo tamanho.',
        ),
      );
    });

    test('mudar só o nome não dá aviso', () async {
      final repos = await _comAplicacao();
      final sessao = await _corrigir(repos, '2', ['1', 'Chico1A', '', '']);
      expect(sessao.saida, isNot(contains('passam a ser calculadas')));
      expect((await repos.talhoes.buscarPorId(1))?.nome, 'Chico1A');
    });

    test('sem aplicações, mudar os hectares também não dá aviso', () async {
      final repos = await _comExemplo();
      final sessao = await _corrigir(repos, '2', ['1', '', '3,1', '']);
      expect(sessao.saida, isNot(contains('passam a ser calculadas')));
    });
  });

  group('corrigir - insumo', () {
    test('troca nome, tipo e marca', () async {
      final repos = await _comExemplo();
      final sessao = await _corrigir(repos, '3', [
        '1', 'Orkestra Plus', 'Fungicida sistêmico', 'BASF', '', //
      ]);
      expect(sessao.saida, contains('nome: Orkestra SC -> Orkestra Plus'));
      expect(sessao.saida, contains('marca: (vazio) -> BASF'));
      expect(
        sessao.saida,
        contains(
          'Insumo corrigido: [1] Orkestra Plus (Fungicida sistêmico, BASF)',
        ),
      );
      final insumo = await repos.insumos.buscarPorId(1);
      expect(insumo?.nome, 'Orkestra Plus');
      expect(insumo?.tipo, 'Fungicida sistêmico');
      expect(insumo?.marca, 'BASF');
    });

    test('um traço apaga a marca', () async {
      final repos = await _comExemplo();
      await _corrigir(repos, '3', ['1', '', '', 'BASF', '']);
      final sessao = await _corrigir(repos, '3', ['1', '', '', '-', '']);
      expect(sessao.saida, contains('marca: BASF -> (vazio)'));
      expect((await repos.insumos.buscarPorId(1))?.marca, isNull);
    });

    test('recusa um insumo igual a outro (mesmo nome e tipo)', () async {
      final repos = await _comExemplo();
      final sessao = await _corrigir(repos, '3', [
        '2', 'orkestra sc', 'Fungicida', '', '', //
      ]);
      expect(sessao.saida, contains('Não foi possível concluir:'));
      expect(sessao.saida, contains('já existe "Orkestra SC" do tipo'));
      expect((await repos.insumos.buscarPorId(2))?.nome, 'Boro Super');
    });

    test('o mesmo nome em outro tipo é aceito', () async {
      final repos = await _comExemplo();
      await _corrigir(repos, '3', ['2', 'Orkestra SC', '', '', '']);
      expect((await repos.insumos.buscarPorId(2))?.nome, 'Orkestra SC');
    });
  });

  group('corrigir - aplicador', () {
    test('troca o modelo e as capacidades', () async {
      final repos = await _comExemplo();
      final sessao = await _corrigir(repos, '4', [
        '1',
        'DJI T50',
        '80',
        '75',
        '',
      ]);
      expect(sessao.saida, contains('modelo: DJI -> DJI T50'));
      expect(sessao.saida, contains('capacidade (L): 70 -> 80'));
      expect(sessao.saida, contains('capacidade (kg): 70 -> 75'));
      final drone = await repos.aplicadores.buscarPorId(1);
      expect(drone?.modelo, 'DJI T50');
      expect(drone?.capacidadeMaximaL, 80);
      expect(drone?.capacidadeMaximaKg, 75);
    });

    test('um traço tira uma capacidade', () async {
      final repos = await _comExemplo();
      final sessao = await _corrigir(repos, '4', ['1', '', '', '-', '']);
      expect(sessao.saida, contains('capacidade (kg): 70 -> (vazio)'));
      final drone = await repos.aplicadores.buscarPorId(1);
      expect(drone?.capacidadeMaximaKg, isNull);
      expect(drone?.capacidadeMaximaL, 70);
    });

    test('diz que o tipo não muda e explica o que fazer', () async {
      final repos = await _comExemplo();
      final sessao = await _corrigir(repos, '4', ['1', '']);
      expect(sessao.saida, contains('O tipo (drone) não muda.'));
      expect(sessao.saida, contains('exclua e cadastre outro'));
    });

    test('capacidade zero é recusada na hora e a pergunta se repete', () async {
      final repos = await _comExemplo();
      final sessao = await _corrigir(repos, '4', [
        '1', '', '0', '75', '', '', //
      ]);
      expect(sessao.saida, contains('O valor precisa ser maior que 0.'));
      expect((await repos.aplicadores.buscarPorId(1))?.capacidadeMaximaL, 75);
    });

    test('reduzir a capacidade não afeta aplicações já registradas', () async {
      final repos = await _comAplicacao();
      await _corrigir(repos, '4', ['1', '', '10', '', '']);
      expect((await repos.aplicadores.buscarPorId(1))?.capacidadeMaximaL, 10);
      // A aplicação continua registrada: a capacidade vale por viagem.
      expect(await repos.aplicacoes.listarTodos(), hasLength(1));
    });
  });

  group('corrigir - operação', () {
    test('troca a descrição', () async {
      final repos = await _comExemplo();
      final sessao = await _corrigir(repos, '5', ['1', 'Adubação', '']);
      expect(sessao.saida, contains('descrição: Pulverização -> Adubação'));
      expect(sessao.saida, contains('Operação corrigida: [1] Adubação'));
      expect((await repos.operacoes.buscarPorId(1))?.descricao, 'Adubação');
    });

    test('recusa a descrição de outra operação', () async {
      final repos = await _comExemplo();
      await repos.operacoes.salvar(Operacao(descricao: 'Adubação'));
      final sessao = await _corrigir(repos, '5', ['2', 'pulverização', '']);
      expect(sessao.saida, contains('Não foi possível concluir:'));
      expect(sessao.saida, contains('já existe a operação "Pulverização"'));
      expect((await repos.operacoes.buscarPorId(2))?.descricao, 'Adubação');
    });
  });

  group('corrigir - aplicação', () {
    test('mostra a aplicação e explica o que não muda', () async {
      final repos = await _comAplicacao();
      final sessao = await _corrigir(repos, '6', ['1']);
      expect(sessao.saida, contains('=== APLICAÇÃO 1 ==='));
      expect(sessao.saida, contains('Aqui dá para mudar a data'));
      expect(sessao.saida, contains('exclua a aplicação e registre outra'));
    });

    test('troca a data e a observação', () async {
      final repos = await _comAplicacao();
      final sessao = await _corrigir(repos, '6', [
        '1', '15/11/2026', 'Revisada', 'n', 'n', '', //
      ]);
      expect(sessao.saida, contains('data: 07/11/2026 -> 15/11/2026'));
      expect(sessao.saida, contains('observação: (vazio) -> Revisada'));
      expect(sessao.saida, contains('Aplicação corrigida:'));
      final aplicacao = await _aplicacao(repos);
      expect(aplicacao.data, DateTime(2026, 11, 15));
      expect(aplicacao.observacao, 'Revisada');
    });

    test('um traço apaga a observação', () async {
      final repos = await _comAplicacao();
      await _corrigir(repos, '6', ['1', '', 'Revisada', 'n', 'n', '']);
      final sessao = await _corrigir(repos, '6', ['1', '', '-', 'n', 'n', '']);
      expect(sessao.saida, contains('observação: Revisada -> (vazio)'));
      expect((await _aplicacao(repos)).observacao, isNull);
    });

    test('data que não existe é perguntada de novo', () async {
      final repos = await _comAplicacao();
      final sessao = await _corrigir(repos, '6', [
        '1', '31/02/2026', '15/11/2026', '', 'n', 'n', '', //
      ]);
      expect(sessao.saida, contains('Data inválida.'));
      expect((await _aplicacao(repos)).data, DateTime(2026, 11, 15));
    });

    test('a dose realizada em mL/ha vira L/ha', () async {
      final repos = await _comAplicacao();
      final sessao = await _corrigir(repos, '6', [
        '1', '', '', 's', '1', '345', 'n', '', //
      ]);
      expect(
        sessao.saida,
        contains(
          'dose realizada de Orkestra SC: ainda não informada -> '
          '0,345 L/ha (anotada como 345 mL/ha)',
        ),
      );
      final aplicacao = await _aplicacao(repos);
      expect(aplicacao.insumos[0].doseRealizada, closeTo(0.345, 1e-9));
      expect(aplicacao.insumos[1].doseRealizada, isNull);
      // A tela final já traz o desperdício calculado com a dose nova.
      expect(sessao.saida, contains('sobredose:'));
    });

    test('a dose realizada em L/ha fica como foi digitada', () async {
      final repos = await _comAplicacao();
      final sessao = await _corrigir(repos, '6', [
        '1', '', '', 's', '2', '0,31', 'n', '', //
      ]);
      expect(sessao.saida, contains('ainda não informada -> 0,31 L/ha'));
      expect(sessao.saida, isNot(contains('anotada como')));
      expect(
        (await _aplicacao(repos)).insumos[0].doseRealizada,
        closeTo(0.31, 1e-9),
      );
    });

    test('sólido: g/ha vira kg/ha', () async {
      final repos = await _comAplicacao();
      final sessao = await _corrigir(repos, '6', [
        '1', '', '', 'n', 's', '1', '21000', '', //
      ]);
      expect(
        sessao.saida,
        contains(
          'dose realizada de Boro Super: ainda não informada -> '
          '21 kg/ha (anotada como 21000 g/ha)',
        ),
      );
      expect(
        (await _aplicacao(repos)).insumos[1].doseRealizada,
        closeTo(21, 1e-9),
      );
    });

    test('só oferece as unidades do tipo do insumo', () async {
      final repos = await _comAplicacao();
      final sessao = await _corrigir(repos, '6', [
        '1', '', '', 's', '', 's', '', '', //
      ]);
      expect(sessao.saida, contains('1. mL/ha'));
      expect(sessao.saida, contains('2. L/ha'));
      expect(sessao.saida, contains('1. g/ha'));
      expect(sessao.saida, contains('2. kg/ha'));
      expect(sessao.saida, isNot(contains('L/1000L')));
      expect(sessao.saida, contains('Nada foi alterado.'));
    });

    test('corrige a dose de dois insumos de uma vez', () async {
      final repos = await _comAplicacao();
      await _corrigir(repos, '6', [
        '1', '', '', 's', '1', '330', 's', '2', '22', '', //
      ]);
      final aplicacao = await _aplicacao(repos);
      expect(aplicacao.insumos[0].doseRealizada, closeTo(0.33, 1e-9));
      expect(aplicacao.insumos[1].doseRealizada, closeTo(22, 1e-9));
    });

    test(
      'dose muito acima da prevista dá aviso e a confirmação é "não"',
      () async {
        final repos = await _comAplicacao();
        final sessao = await _corrigir(repos, '6', [
          '1', '', '', 's', '1', '3450', 'n', '', //
        ]);
        expect(
          sessao.saida,
          contains(
            'Atenção: a dose realizada de Orkestra SC (3,45 L/ha) é mais de 10 '
            'vezes a prevista (0,3 L/ha). Confira a unidade.',
          ),
        );
        expect(sessao.saida, contains('Salvar a correção? (s/N)'));
        expect(sessao.saida, contains('Cancelado. Nada foi alterado.'));
        expect((await _aplicacao(repos)).insumos[0].doseRealizada, isNull);
      },
    );

    test('mesmo com o aviso, responder sim grava', () async {
      final repos = await _comAplicacao();
      await _corrigir(repos, '6', ['1', '', '', 's', '1', '3450', 'n', 's']);
      expect(
        (await _aplicacao(repos)).insumos[0].doseRealizada,
        closeTo(3.45, 1e-9),
      );
    });

    test('dose normal confirma com Enter (padrão sim)', () async {
      final repos = await _comAplicacao();
      final sessao = await _corrigir(repos, '6', [
        '1', '', '', 's', '1', '310', 'n', '', //
      ]);
      expect(sessao.saida, contains('Salvar a correção? (S/n)'));
      expect(sessao.saida, isNot(contains('Confira a unidade')));
    });

    test('responder não em "mudar a dose" mantém a dose', () async {
      final repos = await _comAplicacao();
      await _corrigir(repos, '6', ['1', '', '', 's', '1', '310', 'n', '']);
      final sessao = await _corrigir(repos, '6', ['1', '', '', 'n', 'n']);
      expect(sessao.saida, contains('Nada foi alterado.'));
      expect(
        (await _aplicacao(repos)).insumos[0].doseRealizada,
        closeTo(0.31, 1e-9),
      );
    });

    test('Enter na unidade ou no número não muda a dose', () async {
      final repos = await _comAplicacao();
      await _corrigir(repos, '6', ['1', '', '', 's', '', 's', '2', '']);
      expect((await _aplicacao(repos)).insumos[0].doseRealizada, isNull);
      expect((await _aplicacao(repos)).insumos[1].doseRealizada, isNull);
    });

    test('dose negativa é perguntada de novo', () async {
      final repos = await _comAplicacao();
      final sessao = await _corrigir(repos, '6', [
        '1', '', '', 's', '2', '-1', '0,3', 'n', '', //
      ]);
      expect(sessao.saida, contains('O valor precisa ser pelo menos 0.'));
      expect(
        (await _aplicacao(repos)).insumos[0].doseRealizada,
        closeTo(0.3, 1e-9),
      );
    });

    test('responder não na confirmação não grava nada', () async {
      final repos = await _comAplicacao();
      await _corrigir(repos, '6', [
        '1', '15/11/2026', 'Revisada', 's', '1', '310', 'n', 'n', //
      ]);
      final aplicacao = await _aplicacao(repos);
      expect(aplicacao.data, DateTime(2026, 11, 7));
      expect(aplicacao.observacao, isNull);
      expect(aplicacao.insumos[0].doseRealizada, isNull);
    });
  });

  group('corrigir - erros do sistema', () {
    test('banco fora do ar: mostra a causa e o menu continua', () async {
      final repos = await _comExemplo();
      (repos.areas as AreaRepositoryMemoria).bancoIndisponivel = true;
      final sessao = await _corrigir(repos, '1', []);
      expect(sessao.saida, contains('Não foi possível acessar os dados:'));
      expect(sessao.saida, contains('banco fora do ar'));
      expect(sessao.respostasRestantes, 0);
    });
  });

  group('excluir - menu', () {
    test('lista os seis tipos de registro', () async {
      final sessao = await _rodar(['9', '0', '0'], Repositorios.memoria());
      expect(sessao.saida, contains('1. Área'));
      expect(sessao.saida, contains('2. Talhão'));
      expect(sessao.saida, contains('3. Insumo'));
      expect(sessao.saida, contains('4. Aplicador'));
      expect(sessao.saida, contains('5. Operação'));
      expect(sessao.saida, contains('6. Aplicação'));
      expect(
        sessao.saida,
        contains('Só dá para excluir o que não está em uso'),
      );
    });

    test('avisa quando não há nada cadastrado para excluir', () async {
      final sessao = await _rodar([
        '9', '1', '2', '3', '4', '5', '6', '0', '0', //
      ], Repositorios.memoria());
      expect(sessao.saida, contains('Nenhuma área cadastrada.'));
      expect(sessao.saida, contains('Nenhum talhão cadastrado.'));
      expect(sessao.saida, contains('Nenhum insumo cadastrado.'));
      expect(sessao.saida, contains('Nenhum aplicador cadastrado.'));
      expect(sessao.saida, contains('Nenhuma operação cadastrada.'));
      expect(sessao.saida, contains('Nenhuma aplicação registrada.'));
      expect(sessao.respostasRestantes, 0);
    });

    test('Enter na hora de escolher o id volta sem excluir', () async {
      final repos = await _comExemplo();
      final sessao = await _excluir(repos, '3', ['']);
      expect(sessao.saida, isNot(contains('Excluir mesmo?')));
      expect(await repos.insumos.listarTodos(), hasLength(2));
    });

    test('id que não está na lista é perguntado de novo', () async {
      final repos = await _comExemplo();
      final sessao = await _excluir(repos, '3', ['99', '']);
      expect(sessao.saida, contains('Esse id não está na lista'));
    });
  });

  group('excluir - o que está em uso é recusado antes de perguntar', () {
    test('área com talhões', () async {
      final repos = await _comExemplo();
      final sessao = await _excluir(repos, '1', ['1']);
      expect(
        sessao.saida,
        contains(
          'Exclusão negada: área Sede (tem os talhões Chico1 e Chico2; '
          'exclua-os antes)',
        ),
      );
      expect(sessao.saida, isNot(contains('Excluir mesmo?')));
      expect(await repos.areas.listarTodos(), hasLength(1));
    });

    test('talhão usado numa aplicação', () async {
      final repos = await _comAplicacao();
      final sessao = await _excluir(repos, '2', ['1']);
      expect(
        sessao.saida,
        contains(
          'Exclusão negada: talhão Chico1 (usado na aplicação 1; exclua-a '
          'antes)',
        ),
      );
      expect(sessao.saida, isNot(contains('Excluir mesmo?')));
      expect(await repos.talhoes.listarTodos(), hasLength(2));
    });

    test('insumo usado numa aplicação', () async {
      final repos = await _comAplicacao();
      final sessao = await _excluir(repos, '3', ['2']);
      expect(
        sessao.saida,
        contains('Exclusão negada: insumo Boro Super (usado na aplicação 1'),
      );
      expect(await repos.insumos.listarTodos(), hasLength(2));
    });

    test('aplicador usado numa aplicação', () async {
      final repos = await _comAplicacao();
      final sessao = await _excluir(repos, '4', ['1']);
      expect(
        sessao.saida,
        contains('Exclusão negada: aplicador drone DJI (usado na aplicação 1'),
      );
      expect(await repos.aplicadores.listarTodos(), hasLength(1));
    });

    test('operação usada numa aplicação', () async {
      final repos = await _comAplicacao();
      final sessao = await _excluir(repos, '5', ['1']);
      expect(
        sessao.saida,
        contains(
          'Exclusão negada: operação Pulverização (usada na aplicação 1',
        ),
      );
      expect(await repos.operacoes.listarTodos(), hasLength(1));
    });
  });

  group('excluir - confirmação', () {
    test('Enter na confirmação cancela (o padrão é não)', () async {
      final repos = await _comAplicacao();
      final sessao = await _excluir(repos, '6', ['1', '']);
      expect(sessao.saida, contains('Excluir mesmo? (s/N)'));
      expect(sessao.saida, contains('Cancelado. Nada foi excluído.'));
      expect(await repos.aplicacoes.listarTodos(), hasLength(1));
    });

    test('responder não também cancela', () async {
      final repos = await _comAplicacao();
      final sessao = await _excluir(repos, '6', ['1', 'n']);
      expect(sessao.saida, contains('Cancelado. Nada foi excluído.'));
      expect(await repos.aplicacoes.listarTodos(), hasLength(1));
    });

    test('mostra o que vai acontecer antes de perguntar', () async {
      final repos = await _comAplicacao();
      final sessao = await _excluir(repos, '6', ['1', '']);
      expect(sessao.saida, contains('Vai excluir: aplicação 07/11/2026'));
      expect(
        sessao.saida,
        contains(
          'A aplicação e as doses dela serão apagadas. Talhões, insumos, '
          'aplicador e operação continuam cadastrados.',
        ),
      );
      expect(sessao.saida, contains('Excluir não pode ser desfeito.'));
    });

    test('não avisa do banco quando os dados são só da memória', () async {
      final repos = await _comExemplo();
      final sessao = await _excluir(repos, '3', ['2', 'n']);
      expect(sessao.saida, isNot(contains('apaga do banco de dados')));
    });

    test('avisa que apaga do banco quando os dados são do banco', () async {
      final repos = _compartilhado();
      await garantirDadosExemplo(repos);
      final sessao = await _excluir(repos, '3', ['2', 'n']);
      expect(
        sessao.saida,
        contains('Atenção: isto apaga do banco de dados, que a equipe usa.'),
      );
      expect(await repos.insumos.listarTodos(), hasLength(2));
    });
  });

  group('excluir - o que acontece de verdade', () {
    test('exclui a aplicação e deixa os cadastros', () async {
      final repos = await _comAplicacao();
      final sessao = await _excluir(repos, '6', ['1', 's']);
      expect(sessao.saida, contains('Excluído: aplicação 07/11/2026'));
      expect(await repos.aplicacoes.listarTodos(), isEmpty);
      expect(await repos.talhoes.listarTodos(), hasLength(2));
      expect(await repos.insumos.listarTodos(), hasLength(2));
      expect(await repos.aplicadores.listarTodos(), hasLength(1));
      expect(await repos.operacoes.listarTodos(), hasLength(1));
    });

    test('depois de excluir a aplicação, o resto fica livre', () async {
      final repos = await _comAplicacao();
      final sessao = await _rodar([
        '9', //
        '6', '1', 's', // a aplicação
        '2', '1', 's', // Chico1
        '2', '2', 's', // Chico2
        '1', '1', 's', // a área Sede
        '3', '1', 's', // Orkestra SC
        '3', '2', 's', // Boro Super
        '4', '1', 's', // o drone
        '5', '1', 's', // a operação
        '0', '0', //
      ], repos);
      expect(sessao.saida, contains('Excluído: talhão Sede / Chico1'));
      expect(sessao.saida, contains('Excluído: talhão Sede / Chico2'));
      expect(sessao.saida, contains('Excluído: área Sede'));
      expect(sessao.saida, contains('Excluído: insumo Orkestra SC'));
      expect(sessao.saida, contains('Excluído: insumo Boro Super'));
      expect(sessao.saida, contains('Excluído: aplicador Drone DJI'));
      expect(sessao.saida, contains('Excluído: operação Pulverização'));
      expect(sessao.saida, isNot(contains('Exclusão negada')));
      expect(sessao.respostasRestantes, 0);
      expect(await repos.areas.listarTodos(), isEmpty);
      expect(await repos.talhoes.listarTodos(), isEmpty);
      expect(await repos.insumos.listarTodos(), isEmpty);
      expect(await repos.aplicadores.listarTodos(), isEmpty);
      expect(await repos.operacoes.listarTodos(), isEmpty);
    });

    test('um talhão que ninguém usa pode sair, e a área segue', () async {
      final repos = await _comExemplo();
      await _excluir(repos, '2', ['2', 's']);
      expect(await repos.talhoes.listarTodos(), hasLength(1));
      expect((await repos.talhoes.listarTodos()).first.nome, 'Chico1');
      expect(await repos.areas.listarTodos(), hasLength(1));
    });

    test('depois de excluir, o id some da lista', () async {
      final repos = await _comExemplo();
      final sessao = await _rodar([
        '9', '3', '1', 's', '3', '', '0', '0', //
      ], repos);
      final aposExcluir = sessao.saida.split('Excluído: insumo Orkestra SC')[1];
      expect(aposExcluir, contains('[2] insumo Boro Super'));
      expect(aposExcluir, isNot(contains('[1] insumo Orkestra SC')));
    });

    test(
      'depois de uma recusa o menu continua e dá para tentar outro',
      () async {
        final repos = await _comAplicacao();
        final sessao = await _rodar([
          '9', '2', '1', // Chico1: recusado
          '6', '1', 's', // exclui a aplicação
          '2', '1', 's', // agora o Chico1 sai
          '0', '0', //
        ], repos);
        expect(sessao.saida, contains('Exclusão negada: talhão Chico1'));
        expect(sessao.saida, contains('Excluído: talhão Sede / Chico1'));
        expect(sessao.respostasRestantes, 0);
      },
    );
  });

  group('excluir - erros do sistema', () {
    test('banco fora do ar: mostra a causa e nada é excluído', () async {
      final repos = await _comExemplo();
      (repos.insumos as InsumoRepositoryMemoria).bancoIndisponivel = true;
      final sessao = await _excluir(repos, '3', []);
      expect(sessao.saida, contains('Não foi possível acessar os dados:'));
      expect(sessao.saida, contains('banco fora do ar'));
      expect(sessao.respostasRestantes, 0);
      (repos.insumos as InsumoRepositoryMemoria).bancoIndisponivel = false;
      expect(await repos.insumos.listarTodos(), hasLength(2));
    });
  });
}
