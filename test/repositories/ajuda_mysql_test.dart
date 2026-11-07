import 'package:caderno_fazenda/repositories/mysql/ajuda_mysql.dart';
import 'package:test/test.dart';

/// Testes das funções de conversão usadas pelos repositórios MySQL.
/// Não precisam de banco.
void main() {
  group('inteiro', () {
    test('lê o texto que o driver devolve', () {
      expect(inteiro('42'), 42);
    });

    test('aceita um valor que já é int', () {
      expect(inteiro(7), 7);
    });

    test('texto que não é número lança FormatException', () {
      expect(() => inteiro('abc'), throwsFormatException);
    });
  });

  group('decimal', () {
    test('lê a coluna DECIMAL, que chega como texto', () {
      expect(decimal('2.80'), 2.8);
      expect(decimal('0.300'), 0.3);
    });

    test('decimalOuNulo devolve null quando a coluna é NULL', () {
      expect(decimalOuNulo(null), isNull);
      expect(decimalOuNulo('6.40'), 6.4);
    });
  });

  group('textoOuNulo', () {
    test('devolve null para NULL e o próprio texto nos outros casos', () {
      expect(textoOuNulo(null), isNull);
      expect(textoOuNulo('Sede'), 'Sede');
    });
  });

  group('arredondar', () {
    test('tira o ruído de ponto flutuante', () {
      expect(0.1 + 0.2, isNot(0.3));
      expect(arredondar(0.1 + 0.2, 3), 0.3);
    });

    test('respeita o número de casas', () {
      expect(arredondar(1.23456, 2), 1.23);
      expect(arredondar(1.23456, 3), 1.235);
    });

    test('número redondo continua igual', () {
      expect(arredondar(70, 2), 70.0);
    });
  });

  group('dataSql', () {
    test('formata como AAAA-MM-DD', () {
      expect(dataSql(DateTime(2026, 11, 6)), '2026-11-06');
    });

    test('completa mês e dia com zero à esquerda', () {
      expect(dataSql(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('completa o ano com zeros à esquerda', () {
      expect(dataSql(DateTime(987, 3, 9)), '0987-03-09');
    });
  });
}
