import 'package:caderno_fazenda/logica/calculos_calda.dart';
import 'package:test/test.dart';

void main() {
  group('Funcao 1 - volumeCalda', () {
    test('normal: 25 ha com taxa 40 retorna 1000 L', () {
      expect(volumeCalda(25, 40), equals(1000));
    });

    test('limite: area zero retorna zero', () {
      expect(volumeCalda(0, 40), equals(0));
    });

    test('invalido: area negativa lanca excecao', () {
      expect(() => volumeCalda(-1, 40), throwsA(isA<CaldaException>()));
    });

    test('invalido: taxa zero lanca excecao', () {
      expect(() => volumeCalda(25, 0), throwsA(isA<CaldaException>()));
    });
  });

  group('Funcao 2 - quantidadeProdutoPorHa', () {
    test('normal: dose 2 L/ha em 25 ha retorna 50 L', () {
      expect(quantidadeProdutoPorHa(25, 2), equals(50));
    });

    test('limite: area zero retorna zero', () {
      expect(quantidadeProdutoPorHa(0, 2), equals(0));
    });

    test('invalido: area negativa lanca excecao', () {
      expect(
        () => quantidadeProdutoPorHa(-1, 2),
        throwsA(isA<CaldaException>()),
      );
    });
  });

  group('Funcao 3 - quantidadeProdutoPor1000L', () {
    test('normal: 2 L/1000 L com 1000 L retorna 2 L', () {
      expect(quantidadeProdutoPor1000L(1000, 2), equals(2));
    });

    test('limite: volume zero retorna zero', () {
      expect(quantidadeProdutoPor1000L(0, 2), equals(0));
    });

    test('invalido: volume negativo lanca excecao', () {
      expect(
        () => quantidadeProdutoPor1000L(-1, 2),
        throwsA(isA<CaldaException>()),
      );
    });
  });

  group('Funcao 4 - normalizarDose', () {
    test('normal: 1 L/1000 L com taxa 40 retorna 0.04 L/ha', () {
      expect(normalizarDose(1, 'L/1000L', 40), closeTo(0.04, 1e-12));
    });

    test('limite: dose zero permanece zero', () {
      expect(normalizarDose(0, 'L/ha', 40), equals(0));
    });

    test('dose ja em L/ha nao sofre conversao dupla', () {
      expect(normalizarDose(2, 'L/ha', 40), equals(2));
    });

    test('invalido: taxa zero lanca excecao', () {
      expect(
        () => normalizarDose(1, 'L/1000L', 0),
        throwsA(isA<CaldaException>()),
      );
    });

    test('normal: 500 mL/ha retorna 0.5 L/ha', () {
      expect(normalizarDose(500, 'ml/ha', 40), equals(0.5));
    });

    test('normal: unidade mL/ha aceita maiusculas e espacos', () {
      expect(normalizarDose(500, ' mL/ha ', 40), equals(0.5));
    });

    test('limite: dose zero em mL/ha retorna zero', () {
      expect(normalizarDose(0, 'ml/ha', 40), equals(0));
    });

    test('invalido: dose negativa em mL/ha lanca excecao', () {
      expect(
        () => normalizarDose(-1, 'ml/ha', 40),
        throwsA(isA<CaldaException>()),
      );
    });

    test('invalido: unidade de massa kg/ha exige densidade', () {
      expect(
        () => normalizarDose(1, 'kg/ha', 40),
        throwsA(isA<DensidadeNecessariaException>()),
      );
    });

    test('invalido: unidade de massa g/ha exige densidade', () {
      expect(
        () => normalizarDose(500, 'g/ha', 40),
        throwsA(isA<DensidadeNecessariaException>()),
      );
    });

    test('invalido: unidade desconhecida lanca excecao especifica', () {
      expect(
        () => normalizarDose(1, 'banana', 40),
        throwsA(isA<UnidadeDesconhecidaException>()),
      );
    });
  });

  group('Funcao 5 - converterUnidade', () {
    test('normal: 1000 mL para L retorna 1 L', () {
      expect(converterUnidade(1000, 'mL', 'L'), equals(1));
    });

    test('limite: zero g para kg retorna zero', () {
      expect(converterUnidade(0, 'g', 'kg'), equals(0));
    });

    test('converte g, kg e ton corretamente', () {
      expect(converterUnidade(2000, 'g', 'kg'), equals(2));
      expect(converterUnidade(2, 'kg', 'ton'), equals(0.002));
      expect(converterUnidade(1, 'ton', 'g'), equals(1000000));
    });

    test('invalido: kg para L exige densidade', () {
      expect(
        () => converterUnidade(1, 'kg', 'L'),
        throwsA(isA<DensidadeNecessariaException>()),
      );
    });

    test('invalido: unidade desconhecida lanca excecao especifica', () {
      expect(
        () => converterUnidade(1, 'banana', 'kg'),
        throwsA(isA<UnidadeDesconhecidaException>()),
      );
    });
  });

  group('Funcao 6 - normalizarDoseMassa', () {
    test('normal: 500 g/ha retorna 0.5 kg/ha', () {
      expect(normalizarDoseMassa(500, 'g/ha'), equals(0.5));
    });

    test('normal: dose ja em kg/ha nao sofre conversao', () {
      expect(normalizarDoseMassa(2, 'kg/ha'), equals(2));
    });

    test('normal: unidade g/ha aceita maiusculas e espacos', () {
      expect(normalizarDoseMassa(500, ' G/HA '), equals(0.5));
    });

    test('limite: dose zero retorna zero', () {
      expect(normalizarDoseMassa(0, 'g/ha'), equals(0));
    });

    test('invalido: dose negativa lanca excecao', () {
      expect(
        () => normalizarDoseMassa(-1, 'g/ha'),
        throwsA(isA<CaldaException>()),
      );
    });

    test('invalido: unidade de volume L/ha exige densidade', () {
      expect(
        () => normalizarDoseMassa(1, 'L/ha'),
        throwsA(isA<DensidadeNecessariaException>()),
      );
    });

    test('invalido: unidade de volume mL/ha exige densidade', () {
      expect(
        () => normalizarDoseMassa(500, 'ml/ha'),
        throwsA(isA<DensidadeNecessariaException>()),
      );
    });

    test('invalido: unidade desconhecida lanca excecao especifica', () {
      expect(
        () => normalizarDoseMassa(1, 'banana'),
        throwsA(isA<UnidadeDesconhecidaException>()),
      );
    });
  });
}
