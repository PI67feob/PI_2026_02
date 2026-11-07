import 'package:caderno_fazenda/logica/calculo_desperdicio.dart';
import 'package:test/test.dart';

void main() {
  group('Funcao 1 - desvioDose', () {
    test('normal: realizado maior que previsto devolve desvio positivo', () {
      expect(desvioDose(2, 2.5), closeTo(0.5, 1e-9));
    });

    test('normal: realizado menor que previsto devolve desvio negativo', () {
      expect(desvioDose(2, 1.5), closeTo(-0.5, 1e-9));
    });

    test('normal: realizado igual ao previsto devolve zero', () {
      expect(desvioDose(2, 2), closeTo(0, 1e-9));
    });

    test('limite: previsto e realizado zero devolvem zero', () {
      expect(desvioDose(0, 0), closeTo(0, 1e-9));
    });

    test('limite: previsto zero e realizado positivo devolve o realizado', () {
      expect(desvioDose(0, 3), closeTo(3, 1e-9));
    });

    test('invalido: dose prevista negativa lanca excecao', () {
      expect(() => desvioDose(-1, 2), throwsA(isA<DesperdicioException>()));
    });

    test('invalido: dose realizada negativa lanca excecao', () {
      expect(() => desvioDose(2, -1), throwsA(isA<DesperdicioException>()));
    });
  });

  group('Funcao 2 - percentualDesperdicio', () {
    test('normal: previsto 10 e realizado 12 devolve 20%', () {
      expect(percentualDesperdicio(10, 12), closeTo(20, 1e-9));
    });

    test('normal: previsto 2 e realizado 2.5 devolve 25%', () {
      expect(percentualDesperdicio(2, 2.5), closeTo(25, 1e-9));
    });

    test('normal: realizado menor que previsto devolve 0', () {
      expect(percentualDesperdicio(10, 8), closeTo(0, 1e-9));
    });

    test('limite: realizado igual ao previsto devolve 0', () {
      expect(percentualDesperdicio(10, 10), closeTo(0, 1e-9));
    });

    test('limite: realizado zero devolve 0', () {
      expect(percentualDesperdicio(10, 0), closeTo(0, 1e-9));
    });

    test('invalido: previsto zero lanca excecao', () {
      expect(
        () => percentualDesperdicio(0, 5),
        throwsA(isA<DesperdicioException>()),
      );
    });

    test('invalido: previsto negativo lanca excecao', () {
      expect(
        () => percentualDesperdicio(-10, 5),
        throwsA(isA<DesperdicioException>()),
      );
    });

    test('invalido: realizado negativo lanca excecao', () {
      expect(
        () => percentualDesperdicio(10, -5),
        throwsA(isA<DesperdicioException>()),
      );
    });
  });

  group('Funcao 3 - quantidadeAComprar', () {
    test('normal: fator padrao compra 95% da quantidade calculada', () {
      expect(quantidadeAComprar(100), closeTo(95, 1e-9));
    });

    test('normal: fator informado por parametro substitui o padrao', () {
      expect(quantidadeAComprar(100, fator: 0.9), closeTo(90, 1e-9));
    });

    test('normal: o fator padrao nomeado vale 0.95', () {
      expect(fatorCompraPadrao, closeTo(0.95, 1e-9));
    });

    test('limite: quantidade calculada zero devolve zero', () {
      expect(quantidadeAComprar(0), closeTo(0, 1e-9));
    });

    test('invalido: quantidade calculada negativa lanca excecao', () {
      expect(
        () => quantidadeAComprar(-1),
        throwsA(isA<DesperdicioException>()),
      );
    });

    test('invalido: fator zero lanca excecao', () {
      expect(
        () => quantidadeAComprar(100, fator: 0),
        throwsA(isA<DesperdicioException>()),
      );
    });

    test('invalido: fator negativo lanca excecao', () {
      expect(
        () => quantidadeAComprar(100, fator: -0.5),
        throwsA(isA<DesperdicioException>()),
      );
    });
  });
}
