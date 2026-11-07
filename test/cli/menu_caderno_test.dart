import 'package:caderno_fazenda/cli/dados_exemplo.dart';
import 'package:caderno_fazenda/cli/menu_caderno.dart';
import 'package:caderno_fazenda/repositories/memoria/repositorios_memoria.dart';
import 'package:caderno_fazenda/repositories/repositorios.dart';
import 'package:test/test.dart';

import '../ajuda/terminal_simulado.dart';

/// O que sobrou de uma sessão do menu: os repositórios (para conferir o que
/// foi gravado), o texto da tela e quantas respostas ficaram sem uso.
class _Sessao {
  final Repositorios repositorios;
  final String saida;
  final int respostasRestantes;

  const _Sessao(this.repositorios, this.saida, this.respostasRestantes);
}

/// Roda o menu com as [respostas] prontas, em memória e com a data fixada em
/// 07/11/2026. Passe [repositorios] para começar de dados já cadastrados.
Future<_Sessao> _rodar(
  List<String> respostas, {
  Repositorios? repositorios,
}) async {
  final repos = repositorios ?? Repositorios.memoria();
  final terminal = TerminalSimulado(respostas);
  final menu = MenuCaderno(repos, terminal, agora: () => DateTime(2026, 11, 7));
  await menu.executar();
  return _Sessao(repos, terminal.saida, terminal.respostasRestantes);
}

/// Repositórios em memória que já têm os cadastros de exemplo.
Future<Repositorios> _comExemplo() async {
  final repos = Repositorios.memoria();
  await garantirDadosExemplo(repos);
  return repos;
}

/// Respostas que registram a aplicação da demonstração: Orkestra SC
/// (300 mL/ha previstos, 345 realizados) e Boro Super (500 g/ha previstos, 450
/// realizados) nos talhões Chico1 e Chico2, com chuva 2,5 h depois.
List<String> _registrarDemonstracao({
  String taxa = '10',
  String confirmar = '',
}) {
  return [
    '2', // Registrar aplicação
    '1', // operação: Pulverização
    '1', // aplicador: Drone DJI
    '1,2', // talhões: Chico1 e Chico2
    '', // data: hoje
    taxa, // taxa de aplicação, em L/ha
    '1', '1', '300', '345', 's', // Orkestra SC em mL/ha
    '2', '4', '500', '450', 'n', // Boro Super em g/ha
    '2,5', // horas até a chuva
    'Teste do menu', // observação
    confirmar, // Enter confirma
  ];
}

void main() {
  group('abertura e encerramento', () {
    test('a opção 0 sai do programa', () async {
      final sessao = await _rodar(['0']);
      expect(sessao.saida, contains('=== MENU PRINCIPAL ==='));
      expect(sessao.saida, contains('Até logo!'));
      expect(sessao.respostasRestantes, 0);
    });

    test('mostra de onde vêm os dados e avisa que a memória some', () async {
      final sessao = await _rodar(['0']);
      expect(sessao.saida, contains('Dados: dados em memória'));
      expect(sessao.saida, contains('nada fica salvo'));
    });

    test('encerra com educação quando a entrada de texto acaba', () async {
      final sessao = await _rodar([]);
      expect(sessao.saida, contains('A entrada de texto acabou. Até logo!'));
    });

    test(
      'encerra com educação se a entrada acaba no meio de uma pergunta',
      () async {
        final sessao = await _rodar(['1', '1']);
        expect(sessao.saida, contains('Nome da área'));
        expect(sessao.saida, contains('A entrada de texto acabou. Até logo!'));
      },
    );

    test('avisa quando a opção não existe e continua', () async {
      final sessao = await _rodar(['9', 'abc', '', '0']);
      expect(sessao.saida, contains('Opção inválida.'));
      expect(sessao.saida, contains('Até logo!'));
    });
  });

  group('cadastros', () {
    test('cadastra área, talhão, insumo, aplicador e operação', () async {
      final sessao = await _rodar([
        '1', // Cadastros
        '1', 'Sede', // nova área
        '2', '1', 'Chico1', '2,8', // novo talhão na área 1
        '3', 'Orkestra SC', 'Fungicida', '', // novo insumo, sem marca
        '4', '2', 'DJI', '70', '70', // novo aplicador: drone
        '5', 'Pulverização', // nova operação
        '0', // voltar
        '0', // sair
      ]);
      final saida = sessao.saida;
      expect(saida, contains('Área cadastrada: [1] Sede'));
      expect(
        saida,
        contains('Talhão cadastrado: nome:Chico1 - id:1 - hectares:2.8'),
      );
      expect(saida, contains('Insumo cadastrado: [1] Orkestra SC (Fungicida)'));
      expect(
        saida,
        contains(
          'Aplicador cadastrado: [1] Drone DJI: até 70 L / 70 kg por voo',
        ),
      );
      expect(saida, contains('Operação cadastrada: [1] Pulverização'));
      expect(sessao.respostasRestantes, 0);

      final repos = sessao.repositorios;
      expect((await repos.areas.listarTodos()).length, 1);
      final talhoes = await repos.talhoes.listarTodos();
      expect(talhoes.length, 1);
      expect(talhoes.first.hectares, 2.8);
      expect(talhoes.first.area.nome, 'Sede');
      final aplicadores = await repos.aplicadores.listarTodos();
      expect(aplicadores.first.tipo, 'drone');
      expect(aplicadores.first.capacidadeMaximaL, 70.0);
      expect((await repos.insumos.listarTodos()).length, 1);
      expect((await repos.operacoes.listarTodos()).length, 1);
    });

    test('guarda a marca do insumo quando ela é informada', () async {
      final sessao = await _rodar([
        '1',
        '3',
        'Boro Super',
        'Fertilizante',
        'Nutrição Verde',
        '0',
        '0',
      ]);
      expect(
        sessao.saida,
        contains('[1] Boro Super (Fertilizante, Nutrição Verde)'),
      );
      final insumo = (await sessao.repositorios.insumos.listarTodos()).first;
      expect(insumo.marca, 'Nutrição Verde');
    });

    test(
      'cria a subclasse certa de aplicador e cada uma responde do seu jeito',
      () async {
        final sessao = await _rodar([
          '1',
          '4', '1', 'John Deere', '2000', '', // trator
          '4', '3', '', '20', '', // bomba costal sem modelo
          '0',
          '3', '3', // Consultas > Aplicadores
          '0',
          '0',
        ]);
        final saida = sessao.saida;
        expect(
          saida,
          contains('Trator John Deere: compartimento de até 2000 L'),
        );
        expect(
          saida,
          contains(
            'Bomba costal 2: reservatório de até 20 L nas costas do operador',
          ),
        );
        expect(saida, contains('registro: ficha de papel'));
        final tipos = (await sessao.repositorios.aplicadores.listarTodos())
            .map((a) => a.tipo)
            .toList();
        expect(tipos, ['trator', 'bomba costal']);
      },
    );

    test('recusa cadastro repetido, sem diferenciar maiúsculas', () async {
      final repos = await _comExemplo();
      final sessao = await _rodar([
        '1',
        '1', 'sede', // área repetida
        '2', '1', 'CHICO1', '3', // talhão repetido na mesma área
        '3', 'orkestra sc', 'Fungicida', '', // insumo repetido
        '5', 'pulverização', // operação repetida
        '0',
        '0',
      ], repositorios: repos);
      final saida = sessao.saida;
      expect(saida, contains('Já existe a área "Sede" (id 1).'));
      expect(
        saida,
        contains(
          'Não foi possível concluir: Talhão inválido: CHICO1 (já existe nesta área)',
        ),
      );
      expect(saida, contains('Já existe o insumo "Orkestra SC" (id 1).'));
      expect(saida, contains('Já existe a operação "Pulverização" (id 1).'));
      expect(sessao.respostasRestantes, 0);

      expect((await repos.areas.listarTodos()).length, 1);
      expect((await repos.talhoes.listarTodos()).length, 2);
      expect((await repos.insumos.listarTodos()).length, 2);
      expect((await repos.operacoes.listarTodos()).length, 1);
    });

    test('Enter em branco cancela sem cadastrar nada', () async {
      final sessao = await _rodar(['1', '1', '', '3', '', '5', '', '0', '0']);
      expect(await sessao.repositorios.areas.listarTodos(), isEmpty);
      expect(await sessao.repositorios.insumos.listarTodos(), isEmpty);
      expect(await sessao.repositorios.operacoes.listarTodos(), isEmpty);
      expect(sessao.respostasRestantes, 0);
    });

    test('pede uma área antes de criar o talhão', () async {
      final sessao = await _rodar(['1', '2', '0', '0']);
      expect(
        sessao.saida,
        contains('Cadastre uma área antes de criar o talhão.'),
      );
    });

    test(
      'repete a pergunta dos hectares até receber um valor válido',
      () async {
        final repos = await _comExemplo();
        final sessao = await _rodar([
          '1',
          '2',
          '1',
          'Pinheiro',
          '0',
          'muito',
          '2,05',
          '0',
          '0',
        ], repositorios: repos);
        expect(sessao.saida, contains('O valor precisa ser maior que 0.'));
        expect(sessao.saida, contains('Número inválido.'));
        final pinheiro = await repos.talhoes.buscarPorAreaENome(1, 'Pinheiro');
        expect(pinheiro?.hectares, 2.05);
      },
    );

    test('corrige os hectares de um talhão', () async {
      final repos = await _comExemplo();
      final sessao = await _rodar([
        '1',
        '6',
        '1',
        '3',
        '0',
        '0',
      ], repositorios: repos);
      expect(
        sessao.saida,
        contains('Talhão atualizado: nome:Chico1 - id:1 - hectares:3.0'),
      );
      final chico1 = await repos.talhoes.buscarPorId(1);
      expect(chico1?.hectares, 3.0);
    });

    test(
      'aplicador com capacidade zero é recusado com a mensagem do sistema',
      () async {
        final sessao = await _rodar([
          '1',
          '4',
          '2',
          'DJI',
          '0',
          '70',
          '70',
          '0',
          '0',
        ]);
        expect(sessao.saida, contains('O valor precisa ser maior que 0.'));
        expect((await sessao.repositorios.aplicadores.listarTodos()).length, 1);
      },
    );
  });

  group('registrar aplicação', () {
    test('avisa o que falta cadastrar', () async {
      final sessao = await _rodar(['2', '0']);
      expect(
        sessao.saida,
        contains(
          'Antes de registrar, cadastre: operação, aplicador, talhão, insumo.',
        ),
      );
    });

    test('fluxo completo: converte, calcula e mostra os alertas', () async {
      final repos = await _comExemplo();
      final sessao = await _rodar([
        ..._registrarDemonstracao(),
        '0',
      ], repositorios: repos);
      final saida = sessao.saida;

      expect(saida, contains('=== CONFERIR ANTES DE GRAVAR ==='));
      expect(saida, contains('Data: 07/11/2026'));
      expect(saida, contains('Talhões: Chico1, Chico2 (6,60 ha)'));
      expect(
        saida,
        contains('Orkestra SC: prevista 300 mL/ha, realizada 345 mL/ha'),
      );

      expect(saida, contains('=== APLICAÇÃO 1 REGISTRADA ==='));
      expect(saida, contains('Registrado em: app do drone e ficha de papel'));
      expect(saida, contains('Volume de calda: 66,00 L'));
      expect(saida, contains('Massa de produtos sólidos: 3,30 kg'));
      expect(saida, contains('dose prevista: 0,300 L/ha'));
      expect(saida, contains('dose realizada: 0,345 L/ha'));
      expect(saida, contains('quantidade a comprar (fator 0,95): 1,881 L'));
      expect(saida, contains('desperdício: 15,0%'));
      expect(saida, contains('sobredose: CRÍTICO (acima da tolerância)'));
      expect(saida, contains('dose prevista: 0,500 kg/ha'));
      expect(saida, contains('Choveu em menos de 3 h: REAPLICAR a aplicação.'));
      expect(
        saida,
        contains('Orkestra SC: SOBREDOSE, acima da tolerância de 10%.'),
      );
      expect(sessao.respostasRestantes, 0);

      final gravadas = await repos.aplicacoes.listarTodos();
      expect(gravadas.length, 1);
      final aplicacao = gravadas.first;
      expect(aplicacao.areaTotalHa, closeTo(6.6, 0.0001));
      expect(aplicacao.observacao, 'Teste do menu');
      expect(aplicacao.insumos.length, 2);
      expect(aplicacao.insumos.first.dosePrevista, 0.3);
      expect(aplicacao.insumos.last.unidade.texto, 'kg/ha');
    });

    test('um insumo já escolhido não é oferecido de novo', () async {
      final repos = await _comExemplo();
      final sessao = await _rodar([
        ..._registrarDemonstracao(),
        '0',
      ], repositorios: repos);
      final ofertas = RegExp(r'\[1\] Orkestra SC').allMatches(sessao.saida);
      expect(ofertas.length, 1);
    });

    test('dose em L/1000L usa a taxa de aplicação na conversão', () async {
      final repos = await _comExemplo();
      final sessao = await _rodar([
        '2', '1', '1', '1,2', '', '10',
        '1', '3', '2', '', 'n', // Orkestra: 2 L/1000L
        '', '', // sem chuva, sem observação
        '', // confirma
        '0',
      ], repositorios: repos);
      // 2 L/1000L com taxa de 10 L/ha: 2 x 10 / 1000 = 0,02 L/ha.
      expect(sessao.saida, contains('dose prevista: 0,020 L/ha'));
      expect(sessao.saida, contains('Alertas: nenhum.'));
    });

    test(
      'capacidade excedida: nada é gravado e dá para tentar outra taxa',
      () async {
        final repos = await _comExemplo();
        final sessao = await _rodar([
          ..._registrarDemonstracao(taxa: '20'),
          's', // tentar de novo
          '10', // nova taxa
          '0',
        ], repositorios: repos);
        final saida = sessao.saida;
        expect(
          saida,
          contains(
            'Não foi possível registrar: Capacidade excedida: 132 L (máximo 70 L)',
          ),
        );
        expect(saida, contains('Nada foi gravado.'));
        expect(saida, contains('=== APLICAÇÃO 1 REGISTRADA ==='));
        expect(saida, contains('Volume de calda: 66,00 L'));
        expect((await repos.aplicacoes.listarTodos()).length, 1);
        expect(sessao.respostasRestantes, 0);
      },
    );

    test('capacidade excedida: sem nova tentativa, nada é gravado', () async {
      final repos = await _comExemplo();
      final sessao = await _rodar([
        ..._registrarDemonstracao(taxa: '20'),
        'n', // não tentar de novo
        '0',
      ], repositorios: repos);
      expect(
        sessao.saida,
        contains('Capacidade excedida: 132 L (máximo 70 L)'),
      );
      expect(sessao.saida, isNot(contains('REGISTRADA')));
      expect(await repos.aplicacoes.listarTodos(), isEmpty);
    });

    test('responder não na conferência não grava nada', () async {
      final repos = await _comExemplo();
      final sessao = await _rodar([
        ..._registrarDemonstracao(confirmar: 'n'),
        '0',
      ], repositorios: repos);
      expect(sessao.saida, contains('Cancelado. Nada foi gravado.'));
      expect(await repos.aplicacoes.listarTodos(), isEmpty);
    });

    test('Enter em branco na operação cancela o registro', () async {
      final repos = await _comExemplo();
      final sessao = await _rodar(['2', '', '0'], repositorios: repos);
      expect(
        sessao.saida,
        contains('Enter em branco cancela e volta ao menu.'),
      );
      expect(await repos.aplicacoes.listarTodos(), isEmpty);
      expect(sessao.respostasRestantes, 0);
    });

    test('banco fora do ar: mostra a causa e o menu continua', () async {
      final repos = await _comExemplo();
      (repos.aplicacoes as AplicacaoRepositoryMemoria).bancoIndisponivel = true;
      final sessao = await _rodar([
        ..._registrarDemonstracao(),
        '0',
      ], repositorios: repos);
      final saida = sessao.saida;
      expect(
        saida,
        contains(
          'Não foi possível acessar os dados: Erro de persistência: salvar aplicação',
        ),
      );
      expect(saida, contains('Causa técnica: banco fora do ar'));
      expect(saida, contains('Até logo!'));
      expect(sessao.respostasRestantes, 0);
    });

    test('dose realizada é opcional', () async {
      final repos = await _comExemplo();
      final sessao = await _rodar([
        '2',
        '1',
        '1',
        '1',
        '',
        '10',
        '1',
        '1',
        '300',
        '',
        'n',
        '',
        '',
        '',
        '0',
      ], repositorios: repos);
      expect(sessao.saida, contains('ainda não aplicada'));
      expect(sessao.saida, contains('sobredose: sem dose realizada'));
      final aplicacao = (await repos.aplicacoes.listarTodos()).first;
      expect(aplicacao.insumos.first.doseRealizada, isNull);
    });
  });

  group('consultas', () {
    test('listas vazias avisam que não há nada cadastrado', () async {
      final sessao = await _rodar(['3', '1', '2', '3', '4', '5', '0', '0']);
      final saida = sessao.saida;
      expect(saida, contains('Nenhuma área cadastrada.'));
      expect(saida, contains('Nenhum insumo cadastrado.'));
      expect(saida, contains('Nenhum aplicador cadastrado.'));
      expect(saida, contains('Nenhuma operação cadastrada.'));
      expect(saida, contains('Nenhuma aplicação registrada.'));
    });

    test('lista o que foi cadastrado', () async {
      final repos = await _comExemplo();
      final sessao = await _rodar([
        '3',
        '1',
        '2',
        '3',
        '4',
        '0',
        '0',
      ], repositorios: repos);
      final saida = sessao.saida;
      expect(saida, contains('[1] Sede - 2 talhões, 6,60 ha'));
      expect(saida, contains('[1] Chico1 - 2,80 ha'));
      expect(saida, contains('[2] Boro Super (Fertilizante)'));
      expect(saida, contains('[1] Drone DJI: até 70 L / 70 kg por voo'));
      expect(saida, contains('registro: app do drone e ficha de papel'));
      expect(saida, contains('[1] Pulverização'));
    });

    test('mostra os detalhes de uma aplicação registrada', () async {
      final repos = await _comExemplo();
      final sessao = await _rodar([
        ..._registrarDemonstracao(),
        '3', '5', '1', '0', // Consultas > Aplicações > detalhes da 1
        '0',
      ], repositorios: repos);
      final saida = sessao.saida;
      expect(
        saida,
        contains(
          '[1] 07/11/2026 | Pulverização | drone | Chico1, Chico2 (6,60 ha) | 2 insumos',
        ),
      );
      expect(saida, contains('=== APLICAÇÃO 1 ==='));
      expect(saida, contains('Observação: Teste do menu'));
      expect(saida, contains('Talhões: Chico1 (2,80 ha), Chico2 (3,80 ha)'));
      expect(saida, contains('desperdício: 15,0%'));
    });
  });

  group('resumo de desperdício', () {
    test('sem dose realizada, avisa que ainda não há resumo', () async {
      final sessao = await _rodar(['4', '0']);
      expect(sessao.saida, contains('Ainda não há dose realizada registrada.'));
    });

    test('soma as aplicações e separa litros de quilos', () async {
      final repos = await _comExemplo();
      final sessao = await _rodar([
        ..._registrarDemonstracao(),
        '4',
        '0',
      ], repositorios: repos);
      final saida = sessao.saida;
      expect(
        saida,
        contains('=== RESUMO DE DESPERDÍCIO (todas as aplicações) ==='),
      );
      expect(saida, contains('previsto: 1,980 L'));
      expect(saida, contains('realizado: 2,277 L'));
      expect(saida, contains('desperdício: 0,297 L'));
      expect(saida, contains('percentual: 15,0%'));
      expect(saida, contains('previsto: 3,300 kg'));
      expect(saida, contains('desperdício: 0,000 kg'));
    });
  });

  group('parâmetros', () {
    test('mostra os parâmetros em uso e não altera sem confirmação', () async {
      final sessao = await _rodar(['6', 'n', '0']);
      expect(sessao.saida, contains('tolerância de sobredose: 10%'));
      expect(
        sessao.saida,
        contains('chuva: reaplicar se chover em menos de 3 h'),
      );
      expect(sessao.saida, contains('fator de compra: 0,95'));
      expect(sessao.respostasRestantes, 0);
    });

    test('uma tolerância maior muda a classificação da sobredose', () async {
      final repos = await _comExemplo();
      final sessao = await _rodar([
        '6', 's', '20', '', '', // tolerância 20%, o resto fica como está
        ..._registrarDemonstracao(),
        '0',
      ], repositorios: repos);
      final saida = sessao.saida;
      expect(saida, contains('tolerância de sobredose: 20%'));
      expect(saida, contains('sobredose: atenção (dentro da tolerância)'));
      expect(saida, contains('dentro da tolerância de 20%.'));
      expect(saida, isNot(contains('SOBREDOSE, acima da tolerância')));
    });

    test('limite de chuva e fator de compra novos valem no registro', () async {
      final repos = await _comExemplo();
      final sessao = await _rodar([
        '6', 's', '', '2', '0,9', // chuva em menos de 2 h; compra 90%
        ..._registrarDemonstracao(),
        '0',
      ], repositorios: repos);
      final saida = sessao.saida;
      // A chuva veio 2,5 h depois: com limite de 2 h, não precisa reaplicar.
      expect(saida, contains('Chuva: choveu depois do limite: não reaplicar'));
      expect(saida, contains('quantidade a comprar (fator 0,9): 1,782 L'));
    });

    test('valores inválidos são perguntados de novo', () async {
      final sessao = await _rodar([
        '6',
        's',
        '-5',
        '5',
        '0',
        '4',
        'x',
        '1',
        '0',
      ]);
      expect(sessao.saida, contains('O valor precisa ser pelo menos 0.'));
      expect(sessao.saida, contains('O valor precisa ser maior que 0.'));
      expect(sessao.saida, contains('tolerância de sobredose: 5%'));
      expect(sessao.respostasRestantes, 0);
    });
  });

  group('dados de exemplo', () {
    test('cria os cadastros e pode ser repetido sem duplicar', () async {
      final sessao = await _rodar(['7', '7', '0']);
      expect(sessao.saida, contains('Dados de exemplo prontos'));
      expect(sessao.saida, contains('Drone DJI: até 70 L / 70 kg por voo'));
      final repos = sessao.repositorios;
      expect((await repos.areas.listarTodos()).length, 1);
      expect((await repos.talhoes.listarTodos()).length, 2);
      expect((await repos.aplicadores.listarTodos()).length, 1);
      expect((await repos.operacoes.listarTodos()).length, 1);
      expect((await repos.insumos.listarTodos()).length, 2);
    });
  });

  group('calculadora dentro do menu', () {
    test('abre pela opção 5 e volta ao menu principal', () async {
      final sessao = await _rodar(['5', '1', '6,6', '10', '0', '0']);
      expect(
        sessao.saida,
        contains('=== CALCULADORA (funções de lib/logica) ==='),
      );
      expect(sessao.saida, contains('Volume de calda: 66,00 L'));
      expect(sessao.saida, contains('Até logo!'));
      expect(sessao.respostasRestantes, 0);
    });

    test('erro da lógica aparece e a calculadora continua', () async {
      final sessao = await _rodar([
        '5',
        '1',
        '-1',
        '10',
        '1',
        '6,6',
        '10',
        '0',
        '0',
      ]);
      expect(
        sessao.saida,
        contains('Erro de cálculo: A area nao pode ser negativa.'),
      );
      expect(sessao.saida, contains('Volume de calda: 66,00 L'));
    });
  });
}
