import 'package:caderno_fazenda/cli/interacao.dart';
import 'package:caderno_fazenda/cli/terminal.dart';
import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';
import 'package:caderno_fazenda/exceptions/persistencia_exception.dart';
import 'package:caderno_fazenda/logica/calculo_desperdicio.dart';
import 'package:caderno_fazenda/logica/calculos_calda.dart';
import 'package:caderno_fazenda/models/area.dart';
import 'package:test/test.dart';

import '../ajuda/terminal_simulado.dart';

/// Testes da conversa com o usuário, usando um terminal com respostas prontas.
void main() {
  var terminal = TerminalSimulado([]);

  Interacao conversar(List<String> respostas) {
    terminal = TerminalSimulado(respostas);
    return Interacao(terminal);
  }

  group('perguntar', () {
    test('escreve o rótulo e devolve a resposta sem espaços nas pontas', () {
      final ui = conversar(['  Ana  ']);
      expect(ui.perguntar('Nome'), 'Ana');
      expect(terminal.saida, contains('Nome: '));
    });

    test('lança EntradaEncerrada quando a entrada acabou', () {
      final ui = conversar([]);
      var encerrou = false;
      try {
        ui.perguntar('Nome');
      } on EntradaEncerrada {
        encerrou = true;
      }
      expect(encerrou, isTrue);
    });
  });

  group('perguntarTexto', () {
    test('devolve o texto digitado', () {
      final ui = conversar(['Sede']);
      expect(ui.perguntarTexto('Área'), 'Sede');
    });

    test('devolve null se o usuário só apertou Enter', () {
      final ui = conversar(['']);
      expect(ui.perguntarTexto('Área'), isNull);
    });
  });

  group('perguntarNumero', () {
    test('aceita vírgula e ponto', () {
      expect(conversar(['2,5']).perguntarNumero('x'), 2.5);
      expect(conversar(['2.5']).perguntarNumero('x'), 2.5);
    });

    test('repete a pergunta até receber um número', () {
      final ui = conversar(['abc', '2,5']);
      expect(ui.perguntarNumero('x'), 2.5);
      expect(terminal.saida, contains('Número inválido'));
      expect(terminal.respostasRestantes, 0);
    });

    test('mínimo exclusivo recusa o próprio mínimo', () {
      final ui = conversar(['0', '-1', '3']);
      expect(ui.perguntarNumero('x', minimo: 0, exclusivo: true), 3.0);
      expect(terminal.saida, contains('O valor precisa ser maior que 0.'));
    });

    test('mínimo inclusivo aceita o próprio mínimo', () {
      final ui = conversar(['-1', '0']);
      expect(ui.perguntarNumero('x', minimo: 0), 0.0);
      expect(terminal.saida, contains('O valor precisa ser pelo menos 0.'));
    });

    test('devolve null se o usuário só apertou Enter', () {
      final ui = conversar(['']);
      expect(ui.perguntarNumero('x'), isNull);
    });
  });

  group('confirmar', () {
    test('entende sim e não', () {
      expect(conversar(['s']).confirmar('Gravar?'), isTrue);
      expect(conversar(['n']).confirmar('Gravar?', padrao: true), isFalse);
    });

    test('Enter vale o padrão', () {
      expect(conversar(['']).confirmar('Gravar?'), isFalse);
      expect(conversar(['']).confirmar('Gravar?', padrao: true), isTrue);
    });

    test('mostra o padrão na pergunta', () {
      conversar(['']).confirmar('Gravar?');
      expect(terminal.saida, contains('Gravar? (s/N): '));
      conversar(['']).confirmar('Gravar?', padrao: true);
      expect(terminal.saida, contains('Gravar? (S/n): '));
    });

    test('repete a pergunta se não entender', () {
      final ui = conversar(['talvez', 's']);
      expect(ui.confirmar('Gravar?'), isTrue);
      expect(terminal.saida, contains('Responda com s (sim) ou n (não).'));
    });
  });

  group('perguntarData', () {
    final hoje = DateTime(2026, 11, 7, 15, 30);

    test('Enter vale hoje, sem a hora', () {
      final ui = conversar(['']);
      expect(ui.perguntarData('Data', hoje), DateTime(2026, 11, 7));
      expect(terminal.saida, contains('[Enter = 07/11/2026]'));
    });

    test('lê a data digitada', () {
      final ui = conversar(['01/10/2026']);
      expect(ui.perguntarData('Data', hoje), DateTime(2026, 10, 1));
    });

    test('repete a pergunta se a data não existir', () {
      final ui = conversar(['31/02/2026', 'ontem', '05/11/2026']);
      expect(ui.perguntarData('Data', hoje), DateTime(2026, 11, 5));
      expect(terminal.saida, contains('Data inválida.'));
    });
  });

  group('editarTexto', () {
    test('Enter mantém o valor atual e mostra qual é', () {
      final ui = conversar(['']);
      expect(ui.editarTexto('Nome da área', 'Sede'), 'Sede');
      expect(
        terminal.saida,
        contains('Nome da área [atual: Sede; Enter = manter]: '),
      );
    });

    test('um texto novo troca o valor, sem espaços nas pontas', () {
      final ui = conversar(['  Norte  ']);
      expect(ui.editarTexto('Nome', 'Sede'), 'Norte');
    });
  });

  group('editarTextoOpcional', () {
    test('Enter mantém o valor atual', () {
      final ui = conversar(['']);
      expect(ui.editarTextoOpcional('Marca', 'BASF'), 'BASF');
      expect(
        terminal.saida,
        contains('Marca [atual: BASF; Enter = manter; - = apagar]: '),
      );
    });

    test('Enter num campo vazio continua vazio e diz "vazio"', () {
      final ui = conversar(['']);
      expect(ui.editarTextoOpcional('Marca', null), isNull);
      expect(terminal.saida, contains('[atual: vazio;'));
    });

    test('um traço apaga o valor', () {
      final ui = conversar(['-']);
      expect(ui.editarTextoOpcional('Marca', 'BASF'), isNull);
    });

    test('um texto novo troca o valor', () {
      final ui = conversar(['Bayer']);
      expect(ui.editarTextoOpcional('Marca', 'BASF'), 'Bayer');
    });
  });

  group('editarOpcaoOpcional', () {
    const opcoes = ['chuva', 'sol/calor', 'vento'];

    test('mostra as opções numeradas e o valor atual', () {
      final ui = conversar(['']);
      ui.editarOpcaoOpcional('Imprevisto', opcoes, 1);
      expect(terminal.saida, contains('1. chuva'));
      expect(terminal.saida, contains('3. vento'));
      expect(
        terminal.saida,
        contains('Imprevisto [atual: sol/calor; Enter = manter; - = tirar]: '),
      );
    });

    test('Enter mantém a opção atual', () {
      expect(conversar(['']).editarOpcaoOpcional('x', opcoes, 2), 2);
    });

    test('Enter sem opção atual continua sem opção e diz "nenhum"', () {
      final ui = conversar(['']);
      expect(ui.editarOpcaoOpcional('x', opcoes, null), isNull);
      expect(terminal.saida, contains('[atual: nenhum;'));
    });

    test('um traço tira a escolha', () {
      expect(conversar(['-']).editarOpcaoOpcional('x', opcoes, 0), isNull);
    });

    test('um número da lista troca a opção (devolve a posição de 0)', () {
      expect(conversar(['3']).editarOpcaoOpcional('x', opcoes, null), 2);
      expect(conversar(['1']).editarOpcaoOpcional('x', opcoes, 2), 0);
    });

    test('repete a pergunta se o número não está na lista ou não é número', () {
      final ui = conversar(['0', '4', 'vento', '2']);
      expect(ui.editarOpcaoOpcional('x', opcoes, null), 1);
      expect(
        RegExp('Escolha um número de 1 a 3').allMatches(terminal.saida).length,
        3,
      );
    });
  });

  group('editarNumero', () {
    test('Enter mantém o valor atual, escrito sem zeros sobrando', () {
      final ui = conversar(['']);
      expect(ui.editarNumero('Hectares', 2.8), 2.8);
      expect(
        terminal.saida,
        contains('Hectares [atual: 2,8; Enter = manter]: '),
      );
    });

    test('um número novo troca o valor (vírgula ou ponto)', () {
      expect(conversar(['3,1']).editarNumero('x', 2.8), 3.1);
      expect(conversar(['3.1']).editarNumero('x', 2.8), 3.1);
    });

    test('repete a pergunta se não for número', () {
      final ui = conversar(['muito', '3,1']);
      expect(ui.editarNumero('x', 2.8), 3.1);
      expect(terminal.saida, contains('Número inválido.'));
    });

    test('repete a pergunta se não respeitar o mínimo', () {
      final ui = conversar(['0', '-2', '3,1']);
      expect(ui.editarNumero('x', 2.8, minimo: 0, exclusivo: true), 3.1);
      expect(terminal.saida, contains('O valor precisa ser maior que 0.'));
    });

    test('o valor atual não é conferido contra o mínimo', () {
      final ui = conversar(['']);
      expect(ui.editarNumero('x', 0, minimo: 0, exclusivo: true), 0);
    });
  });

  group('editarNumeroOpcional', () {
    test('Enter mantém o valor atual', () {
      final ui = conversar(['']);
      expect(ui.editarNumeroOpcional('Capacidade', 70), 70);
      expect(
        terminal.saida,
        contains('Capacidade [atual: 70; Enter = manter; - = apagar]: '),
      );
    });

    test('Enter num campo vazio continua vazio e diz "vazio"', () {
      final ui = conversar(['']);
      expect(ui.editarNumeroOpcional('Capacidade', null), isNull);
      expect(terminal.saida, contains('[atual: vazio;'));
    });

    test('um traço apaga o valor', () {
      final ui = conversar(['-']);
      expect(ui.editarNumeroOpcional('Capacidade', 70), isNull);
    });

    test('um número novo preenche ou troca o valor', () {
      expect(conversar(['80']).editarNumeroOpcional('x', 70), 80);
      expect(conversar(['2,5']).editarNumeroOpcional('x', null), 2.5);
    });

    test('repete a pergunta se a resposta não servir', () {
      final ui = conversar(['abc', '0', '80']);
      expect(ui.editarNumeroOpcional('x', 70, minimo: 0, exclusivo: true), 80);
      expect(terminal.saida, contains('Número inválido.'));
      expect(terminal.saida, contains('O valor precisa ser maior que 0.'));
    });
  });

  group('editarData', () {
    test('Enter mantém a data atual e mostra qual é', () {
      final ui = conversar(['']);
      expect(
        ui.editarData('Data', DateTime(2026, 11, 7)),
        DateTime(2026, 11, 7),
      );
      expect(
        terminal.saida,
        contains('Data [atual: 07/11/2026; Enter = manter]: '),
      );
    });

    test('lê a data nova', () {
      final ui = conversar(['15/11/2026']);
      expect(
        ui.editarData('Data', DateTime(2026, 11, 7)),
        DateTime(2026, 11, 15),
      );
    });

    test('repete a pergunta se a data não existir', () {
      final ui = conversar(['31/02/2026', 'ontem', '15/11/2026']);
      expect(
        ui.editarData('Data', DateTime(2026, 11, 7)),
        DateTime(2026, 11, 15),
      );
      expect(terminal.saida, contains('Data inválida.'));
    });
  });

  group('escolherPorId', () {
    final sede = Area(nome: 'Sede', id: 1);
    final norte = Area(nome: 'Norte', id: 2);

    test('lista os itens com o id e devolve o escolhido', () {
      final ui = conversar(['2']);
      final area = ui.escolherPorId('Id', [sede, norte], (a) => a.nome);
      expect(area, same(norte));
      expect(terminal.saida, contains('  [1] Sede'));
      expect(terminal.saida, contains('  [2] Norte'));
    });

    test('repete a pergunta se o id não estiver na lista', () {
      final ui = conversar(['9', 'abc', '1']);
      final area = ui.escolherPorId('Id', [sede, norte], (a) => a.nome);
      expect(area, same(sede));
      expect(terminal.saida, contains('Esse id não está na lista.'));
    });

    test('devolve null se o usuário só apertou Enter', () {
      final ui = conversar(['']);
      final escolhida = ui.escolherPorId('Id', [sede], (a) => a.nome);
      expect(escolhida, isNull);
    });
  });

  group('escolherVariosPorId', () {
    final sede = Area(nome: 'Sede', id: 1);
    final norte = Area(nome: 'Norte', id: 2);
    final sul = Area(nome: 'Sul', id: 3);
    final todas = [sede, norte, sul];

    test('devolve os escolhidos na ordem digitada', () {
      final ui = conversar(['3, 1']);
      final areas = ui.escolherVariosPorId('Ids', todas, (a) => a.nome);
      expect(areas, [sul, sede]);
    });

    test('repete a pergunta se faltar vírgula, repetir ou não existir', () {
      final ui = conversar(['a,b', '1,1', '1,9', '2']);
      final areas = ui.escolherVariosPorId('Ids', todas, (a) => a.nome);
      expect(areas, [norte]);
      expect(terminal.saida, contains('Digite os ids separados por vírgula'));
      expect(terminal.saida, contains('Há um id repetido.'));
      expect(terminal.saida, contains('O id 9 não está na lista.'));
    });

    test('devolve null se o usuário só apertou Enter', () {
      final ui = conversar(['']);
      expect(ui.escolherVariosPorId('Ids', todas, (a) => a.nome), isNull);
    });
  });

  group('escolherOpcao', () {
    test('numera a partir de 1 e devolve a posição a partir de 0', () {
      final ui = conversar(['3']);
      expect(ui.escolherOpcao('Tipo', ['Trator', 'Drone', 'Costal']), 2);
      expect(terminal.saida, contains('  1. Trator'));
      expect(terminal.saida, contains('  3. Costal'));
    });

    test('repete a pergunta se o número não existir', () {
      final ui = conversar(['0', '4', 'x', '1']);
      expect(ui.escolherOpcao('Tipo', ['Trator', 'Drone', 'Costal']), 0);
      expect(terminal.saida, contains('Escolha um número de 1 a 3.'));
    });

    test('devolve null se o usuário só apertou Enter', () {
      final ui = conversar(['']);
      expect(ui.escolherOpcao('Tipo', ['Trator']), isNull);
    });
  });

  group('menu', () {
    test('executa a opção escolhida e volta a mostrar o menu', () async {
      var chamadas = 0;
      final ui = conversar(['1', '1', '0']);
      await ui.menu('TESTE', [
        OpcaoMenu('Primeira', () async {
          chamadas++;
        }),
      ]);
      expect(chamadas, 2);
      expect(terminal.saida, contains('=== TESTE ==='));
      expect(terminal.saida, contains('  1. Primeira'));
      expect(terminal.saida, contains('  0. Voltar'));
    });

    test('mostra a dica e o texto de saída pedidos', () async {
      final ui = conversar(['0']);
      await ui.menu('TESTE', [], saida: 'Sair', dica: 'Use com cuidado.');
      expect(terminal.saida, contains('Use com cuidado.'));
      expect(terminal.saida, contains('  0. Sair'));
    });

    test('avisa quando a opção não existe e continua', () async {
      var chamadas = 0;
      final ui = conversar(['9', 'x', '', '1', '0']);
      await ui.menu('TESTE', [
        OpcaoMenu('Primeira', () async {
          chamadas++;
        }),
      ]);
      expect(chamadas, 1);
      expect(terminal.saida, contains('Opção inválida.'));
    });

    test('um erro na opção aparece e o menu continua', () async {
      final ui = conversar(['1', '0']);
      await ui.menu('TESTE', [
        OpcaoMenu('Quebra', () async {
          throw DadoInvalidoException('taxa', 'deve ser maior que zero');
        }),
      ]);
      expect(terminal.saida, contains('Dado inválido: taxa'));
      expect(terminal.respostasRestantes, 0);
    });
  });

  group('executarProtegido', () {
    test('mostra o erro do domínio', () async {
      final ui = conversar([]);
      await ui.executarProtegido(() async {
        throw DadoInvalidoException('taxa', 'deve ser maior que zero');
      });
      expect(
        terminal.saida,
        contains(
          'Não foi possível concluir: '
          'Dado inválido: taxa (deve ser maior que zero)',
        ),
      );
    });

    test('mostra o erro de persistência com a causa técnica', () async {
      final ui = conversar([]);
      await ui.executarProtegido(() async {
        throw PersistenciaException('salvar área', causa: 'banco fora do ar');
      });
      expect(
        terminal.saida,
        contains(
          'Não foi possível acessar os dados: '
          'Erro de persistência: salvar área',
        ),
      );
      expect(terminal.saida, contains('Causa técnica: banco fora do ar'));
    });

    test('mostra o erro das funções de cálculo (CaldaException)', () async {
      final ui = conversar([]);
      await ui.executarProtegido(() async {
        throw CaldaException('A area nao pode ser negativa.');
      });
      expect(
        terminal.saida,
        contains('Erro de cálculo: A area nao pode ser negativa.'),
      );
    });

    test('mostra as exceções filhas da CaldaException', () async {
      final ui = conversar([]);
      await ui.executarProtegido(() async {
        throw UnidadeDesconhecidaException('xyz');
      });
      expect(terminal.saida, contains('Erro de cálculo: Unidade desconhecida'));
    });

    test('mostra o erro do cálculo de desperdício', () async {
      final ui = conversar([]);
      await ui.executarProtegido(() async {
        throw DesperdicioException('A dose prevista deve ser maior que zero.');
      });
      expect(
        terminal.saida,
        contains('Erro de cálculo: A dose prevista deve ser maior que zero.'),
      );
    });

    test('um imprevisto também não derruba o programa', () async {
      final ui = conversar([]);
      await ui.executarProtegido(() async {
        throw const FormatException('ruim');
      });
      expect(
        terminal.saida,
        contains('Erro inesperado: FormatException: ruim'),
      );
    });

    test('o fim da entrada passa direto, para encerrar o programa', () async {
      final ui = conversar([]);
      var encerrou = false;
      try {
        await ui.executarProtegido(() async {
          throw const EntradaEncerrada();
        });
      } on EntradaEncerrada {
        encerrou = true;
      }
      expect(encerrou, isTrue);
    });
  });
}
