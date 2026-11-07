import 'package:caderno_fazenda/logica/calculos_calda.dart';
import 'package:caderno_fazenda/logica/normalizacao_dose.dart';
import 'package:test/test.dart';

void main() {
  group('normalizarDoseInformada - produto liquido', () {
    test('L/ha fica como esta', () {
      var dose = normalizarDoseInformada(2, 'L/ha', 20);

      expect(dose.valor, closeTo(2, 1e-9));
      expect(dose.unidade, 'L/ha');
    });

    test('mL/ha vira L/ha', () {
      var dose = normalizarDoseInformada(500, 'mL/ha', 20);

      expect(dose.valor, closeTo(0.5, 1e-9));
      expect(dose.unidade, 'L/ha');
    });

    test('L/1000L usa a taxa de aplicacao', () {
      var dose = normalizarDoseInformada(2, 'L/1000L', 20);

      expect(dose.valor, closeTo(0.04, 1e-9));
      expect(dose.unidade, 'L/ha');
    });

    test('ignora maiusculas e espacos nas pontas', () {
      var dose = normalizarDoseInformada(500, ' ML/HA ', 20);

      expect(dose.valor, closeTo(0.5, 1e-9));
      expect(dose.unidade, 'L/ha');
    });
  });

  group('normalizarDoseInformada - produto solido', () {
    test('kg/ha fica como esta', () {
      var dose = normalizarDoseInformada(2, 'kg/ha', 20);

      expect(dose.valor, closeTo(2, 1e-9));
      expect(dose.unidade, 'kg/ha');
    });

    test('g/ha vira kg/ha', () {
      var dose = normalizarDoseInformada(500, 'g/ha', 20);

      expect(dose.valor, closeTo(0.5, 1e-9));
      expect(dose.unidade, 'kg/ha');
    });

    test('ignora maiusculas e espacos nas pontas', () {
      var dose = normalizarDoseInformada(500, ' G/HA ', 20);

      expect(dose.valor, closeTo(0.5, 1e-9));
      expect(dose.unidade, 'kg/ha');
    });
  });

  group('normalizarDoseInformada - erros', () {
    test('unidade desconhecida lanca UnidadeDesconhecidaException', () {
      expect(
        () => normalizarDoseInformada(1, 'caixa/ha', 20),
        throwsA(isA<UnidadeDesconhecidaException>()),
      );
    });

    test('kg/1000L e g/1000L continuam pendentes e sao recusadas', () {
      for (var unidade in ['kg/1000L', 'g/1000L']) {
        expect(
          () => normalizarDoseInformada(1, unidade, 20),
          throwsA(isA<UnidadeDesconhecidaException>()),
        );
      }
    });

    test('dose negativa lanca CaldaException', () {
      expect(
        () => normalizarDoseInformada(-1, 'L/ha', 20),
        throwsA(isA<CaldaException>()),
      );
      expect(
        () => normalizarDoseInformada(-1, 'kg/ha', 20),
        throwsA(isA<CaldaException>()),
      );
    });

    test('taxa zero lanca CaldaException para produto liquido', () {
      expect(
        () => normalizarDoseInformada(1, 'L/ha', 0),
        throwsA(isA<CaldaException>()),
      );
    });
  });
}
