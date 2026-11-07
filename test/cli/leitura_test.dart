import 'package:caderno_fazenda/cli/leitura.dart';
import 'package:test/test.dart';

/// Testes das funções que transformam o texto digitado em número, data e
/// lista. Não precisam de terminal nem de banco.
void main() {
  group('lerNumero', () {
    test('aceita vírgula ou ponto como separador decimal', () {
      expect(lerNumero('2,8'), 2.8);
      expect(lerNumero('2.8'), 2.8);
    });

    test('aceita inteiro, espaços nas pontas e sinal de menos', () {
      expect(lerNumero('10'), 10.0);
      expect(lerNumero('  7,5  '), 7.5);
      expect(lerNumero('-3'), -3.0);
    });

    test('recusa o que não é número', () {
      expect(lerNumero('abc'), isNull);
      expect(lerNumero(''), isNull);
      expect(lerNumero('1,2,3'), isNull);
      expect(lerNumero('1.000,5'), isNull);
      expect(lerNumero('2,'), isNull);
      expect(lerNumero('1e5'), isNull);
    });

    test('recusa NaN e infinito', () {
      expect(lerNumero('NaN'), isNull);
      expect(lerNumero('Infinity'), isNull);
    });
  });

  group('lerData', () {
    test('lê dia/mês/ano', () {
      expect(lerData('06/11/2026'), DateTime(2026, 11, 6));
      expect(lerData(' 6/1/2026 '), DateTime(2026, 1, 6));
    });

    test('aceita 29 de fevereiro só em ano bissexto', () {
      expect(lerData('29/02/2024'), DateTime(2024, 2, 29));
      expect(lerData('29/02/2026'), isNull);
    });

    test('recusa data que não existe', () {
      expect(lerData('31/02/2026'), isNull);
      expect(lerData('31/04/2026'), isNull);
      expect(lerData('00/10/2026'), isNull);
      expect(lerData('32/01/2026'), isNull);
      expect(lerData('10/13/2026'), isNull);
    });

    test('recusa outros formatos', () {
      expect(lerData('2026-11-06'), isNull);
      expect(lerData('06/11/26'), isNull);
      expect(lerData('hoje'), isNull);
      expect(lerData(''), isNull);
    });
  });

  group('lerIds', () {
    test('separa por vírgula, ponto e vírgula ou espaço', () {
      expect(lerIds('1,2'), [1, 2]);
      expect(lerIds('1 2'), [1, 2]);
      expect(lerIds(' 3 ; 4 '), [3, 4]);
      expect(lerIds('5'), [5]);
    });

    test('mantém a ordem digitada', () {
      expect(lerIds('3,1,2'), [3, 1, 2]);
    });

    test('recusa lista vazia e item que não é inteiro', () {
      expect(lerIds(''), isNull);
      expect(lerIds('  '), isNull);
      expect(lerIds('1,a'), isNull);
      expect(lerIds('1.5'), isNull);
    });
  });

  group('lerSimNao', () {
    test('entende sim', () {
      expect(lerSimNao('s'), isTrue);
      expect(lerSimNao('S'), isTrue);
      expect(lerSimNao('sim'), isTrue);
      expect(lerSimNao(' SIM '), isTrue);
    });

    test('entende não, com ou sem acento', () {
      expect(lerSimNao('n'), isFalse);
      expect(lerSimNao('N'), isFalse);
      expect(lerSimNao('nao'), isFalse);
      expect(lerSimNao('não'), isFalse);
    });

    test('devolve null para qualquer outra resposta', () {
      expect(lerSimNao('talvez'), isNull);
      expect(lerSimNao(''), isNull);
    });
  });
}
