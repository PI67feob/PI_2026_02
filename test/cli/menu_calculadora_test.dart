import 'package:caderno_fazenda/cli/interacao.dart';
import 'package:caderno_fazenda/cli/menu_calculadora.dart';
import 'package:caderno_fazenda/services/parametros_operacionais.dart';
import 'package:test/test.dart';

import '../ajuda/terminal_simulado.dart';

/// Testes da calculadora: cada opção chama uma função de `lib/logica` e mostra
/// o resultado, ou a mensagem de erro que a função devolveu.
void main() {
  var terminal = TerminalSimulado([]);

  /// Abre a calculadora com as [respostas] prontas e devolve a tela.
  Future<String> calcular(
    List<String> respostas, {
    ParametrosOperacionais? parametros,
  }) async {
    terminal = TerminalSimulado(respostas);
    final padrao =
        parametros ?? ParametrosOperacionais(toleranciaSobredosePercentual: 10);
    await MenuCalculadora(Interacao(terminal), () => padrao).executar();
    return terminal.saida;
  }

  group('volume de calda', () {
    test('multiplica a área pela taxa', () async {
      final saida = await calcular(['1', '6,6', '10', '0']);
      expect(saida, contains('Função: volumeCalda'));
      expect(saida, contains('Volume de calda: 66,00 L'));
    });

    test('mostra a recusa da função para área negativa', () async {
      final saida = await calcular(['1', '-1', '10', '0']);
      expect(saida, contains('Erro de cálculo: A area nao pode ser negativa.'));
    });

    test('mostra a recusa da função para taxa zero', () async {
      final saida = await calcular(['1', '6,6', '0', '0']);
      expect(
        saida,
        contains(
          'Erro de cálculo: A taxa de aplicacao deve ser maior que zero.',
        ),
      );
    });

    test('Enter em branco cancela sem calcular', () async {
      final saida = await calcular(['1', '', '0']);
      expect(saida, isNot(contains('Volume de calda:')));
      expect(terminal.respostasRestantes, 0);
    });
  });

  group('quantidade de produto', () {
    test('por hectare: área x dose', () async {
      final saida = await calcular(['2', '6,6', '0,3', '0']);
      expect(saida, contains('Função: quantidadeProdutoPorHa'));
      expect(
        saida,
        contains('Quantidade de produto: 1,98 (na mesma unidade da dose'),
      );
    });

    test('por hectare: dose negativa é recusada', () async {
      final saida = await calcular(['2', '6,6', '-1', '0']);
      expect(saida, contains('Erro de cálculo: A dose nao pode ser negativa.'));
    });

    test('por 1000 L: não arredonda para longe do valor real', () async {
      final saida = await calcular(['3', '66', '0,15', '0']);
      expect(saida, contains('Função: quantidadeProdutoPor1000L'));
      expect(saida, contains('Quantidade de produto: 0,0099'));
    });
  });

  group('normalizar uma dose', () {
    test('líquido em mL/ha vira L/ha', () async {
      final saida = await calcular(['4', '345', 'mL/ha', '10', '0']);
      expect(saida, contains('Função: normalizarDoseInformada'));
      expect(saida, contains('345 mL/ha = 0,345 L/ha'));
    });

    test('sólido em g/ha vira kg/ha', () async {
      final saida = await calcular(['4', '500', 'g/ha', '10', '0']);
      expect(saida, contains('500 g/ha = 0,5 kg/ha'));
    });

    test('L/1000L usa a taxa de aplicação', () async {
      final saida = await calcular(['4', '2', 'L/1000L', '10', '0']);
      expect(saida, contains('2 L/1000L = 0,02 L/ha'));
    });

    test('g/1000L continua pendente e a mensagem da lógica aparece', () async {
      final saida = await calcular(['4', '2', 'g/1000L', '10', '0']);
      expect(saida, contains('kg/1000L e g/1000L ainda estão pendentes'));
      expect(saida, contains('Erro de cálculo: Unidade desconhecida: g/1000L'));
    });

    test('unidade inventada é recusada e a calculadora continua', () async {
      final saida = await calcular(['4', '5', 'xyz', '10', '0']);
      expect(saida, contains('Erro de cálculo: Unidade desconhecida: xyz'));
      expect(terminal.respostasRestantes, 0);
    });
  });

  group('converter unidades', () {
    test('litro para mililitro', () async {
      final saida = await calcular(['5', '2', 'l', 'ml', '0']);
      expect(saida, contains('Função: converterUnidade'));
      expect(saida, contains('2 l = 2000 ml'));
    });

    test('quilo para tonelada', () async {
      final saida = await calcular(['5', '3', 'kg', 'ton', '0']);
      expect(saida, contains('3 kg = 0,003 ton'));
    });

    test('entre volume e massa a função pede a densidade', () async {
      final saida = await calcular(['5', '2', 'l', 'kg', '0']);
      expect(
        saida,
        contains(
          'Erro de cálculo: Nao e possivel converter entre massa e volume',
        ),
      );
    });

    test('unidade desconhecida é recusada', () async {
      final saida = await calcular(['5', '2', 'galao', 'l', '0']);
      expect(saida, contains('Erro de cálculo: Unidade desconhecida: galao'));
    });
  });

  group('chuva', () {
    test('chuva antes do limite manda reaplicar', () async {
      final saida = await calcular(['6', '2,5', '', 'n', '0']);
      expect(saida, contains('Limite em horas [Enter = 3]'));
      expect(saida, contains('Resultado: choveu antes do limite: REAPLICAR'));
    });

    test('chuva depois do limite não manda reaplicar', () async {
      final saida = await calcular(['6', '4', '', 'n', '0']);
      expect(
        saida,
        contains('Resultado: choveu depois do limite: não reaplicar'),
      );
    });

    test('no limite exato a resposta depende da escolha do usuário', () async {
      final naoReaplica = await calcular(['6', '3', '', 'n', '0']);
      expect(naoReaplica, contains('não reaplicar'));
      final reaplica = await calcular(['6', '3', '', 's', '0']);
      expect(reaplica, contains('REAPLICAR'));
    });

    test('aceita outro limite digitado', () async {
      final saida = await calcular(['6', '4', '5', 'n', '0']);
      expect(saida, contains('Resultado: choveu antes do limite: REAPLICAR'));
    });

    test('usa o limite dos parâmetros como padrão', () async {
      final parametros = ParametrosOperacionais(
        toleranciaSobredosePercentual: 10,
        limiteChuvaHoras: 2,
      );
      final saida = await calcular([
        '6',
        '2,5',
        '',
        'n',
        '0',
      ], parametros: parametros);
      expect(saida, contains('Limite em horas [Enter = 2]'));
      expect(saida, contains('não reaplicar'));
    });

    test('horas negativas são avisadas sem erro', () async {
      final saida = await calcular(['6', '-1', '', 'n', '0']);
      expect(saida, contains('Resultado: horas inválidas'));
    });
  });

  group('capacidade', () {
    test('calda que cabe', () async {
      final saida = await calcular(['7', '66', '70', '0']);
      expect(saida, contains('Resultado: cabe no aplicador'));
    });

    test('calda que passa da capacidade', () async {
      final saida = await calcular(['7', '132', '70', '0']);
      expect(saida, contains('Resultado: EXCEDEU a capacidade do aplicador'));
    });

    test('volume igual à capacidade ainda cabe', () async {
      final saida = await calcular(['7', '70', '70', '0']);
      expect(saida, contains('Resultado: cabe no aplicador'));
    });

    test('capacidade zero é entrada inválida', () async {
      final saida = await calcular(['7', '10', '0', '0']);
      expect(saida, contains('valores inválidos'));
    });
  });

  group('sobredose', () {
    test('acima da tolerância é crítico', () async {
      final saida = await calcular(['8', '300', '345', '', '0']);
      expect(saida, contains('Tolerância em % [Enter = 10]'));
      expect(saida, contains('Resultado: CRÍTICO (acima da tolerância)'));
      expect(saida, contains('Excesso sobre o previsto: 15,0%'));
    });

    test('tolerância digitada muda o resultado', () async {
      final saida = await calcular(['8', '300', '345', '20', '0']);
      expect(saida, contains('Resultado: atenção (dentro da tolerância)'));
    });

    test('dose igual ou menor que a prevista é ok', () async {
      final saida = await calcular(['8', '300', '250', '', '0']);
      expect(saida, contains('Resultado: ok'));
    });

    test(
      'dose prevista zero é entrada inválida e não mostra o excesso',
      () async {
        final saida = await calcular(['8', '0', '5', '', '0']);
        expect(saida, contains('Resultado: dose inválida'));
        expect(saida, isNot(contains('Excesso sobre o previsto')));
      },
    );

    test('usa a tolerância dos parâmetros como padrão', () async {
      final parametros = ParametrosOperacionais(
        toleranciaSobredosePercentual: 25,
      );
      final saida = await calcular([
        '8',
        '300',
        '345',
        '',
        '0',
      ], parametros: parametros);
      expect(saida, contains('Tolerância em % [Enter = 25]'));
      expect(saida, contains('Resultado: atenção'));
    });
  });

  group('desvio e percentual de desperdício', () {
    test('dose acima do previsto', () async {
      final saida = await calcular(['9', '300', '345', '0']);
      expect(saida, contains('Desvio (realizada - prevista): 45'));
      expect(saida, contains('Percentual de desperdício: 15,0%'));
    });

    test('dose abaixo do previsto não é desperdício', () async {
      final saida = await calcular(['9', '300', '200', '0']);
      expect(saida, contains('Desvio (realizada - prevista): -100'));
      expect(saida, contains('Percentual de desperdício: 0,0%'));
      expect(saida, contains('não conta como desperdício'));
    });

    test(
      'dose prevista zero: mostra o desvio e depois a recusa do percentual',
      () async {
        final saida = await calcular(['9', '0', '5', '0']);
        expect(saida, contains('Desvio (realizada - prevista): 5'));
        expect(
          saida,
          contains('Erro de cálculo: A dose prevista deve ser maior que zero'),
        );
      },
    );
  });

  group('quantidade a comprar', () {
    test('usa o fator padrão de 0,95', () async {
      final saida = await calcular(['10', '100', '', '0']);
      expect(saida, contains('Fator de compra [Enter = 0,95]'));
      expect(saida, contains('Quantidade a comprar: 95'));
    });

    test('aceita outro fator', () async {
      final saida = await calcular(['10', '100', '0,9', '0']);
      expect(saida, contains('Quantidade a comprar: 90'));
    });

    test('fator zero é recusado', () async {
      final saida = await calcular(['10', '100', '0', '0']);
      expect(
        saida,
        contains('Erro de cálculo: O fator de compra deve ser maior que zero.'),
      );
    });

    test('quantidade negativa é recusada', () async {
      final saida = await calcular(['10', '-5', '', '0']);
      expect(
        saida,
        contains(
          'Erro de cálculo: A quantidade calculada nao pode ser negativa.',
        ),
      );
    });
  });

  group('menu da calculadora', () {
    test('lista as dez funções e a opção de voltar', () async {
      final saida = await calcular(['0']);
      expect(saida, contains('  1. Volume de calda'));
      expect(saida, contains('  10. Quantidade a comprar'));
      expect(saida, contains('  0. Voltar'));
    });
  });
}
