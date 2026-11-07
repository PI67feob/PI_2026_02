import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';
import 'package:caderno_fazenda/services/parametros_operacionais.dart';
import 'package:test/test.dart';

void main() {
  var recusa = throwsA(isA<DadoInvalidoException>());

  ParametrosOperacionais criar({double limite = 3, double fator = 0.95}) {
    return ParametrosOperacionais(
      toleranciaSobredosePercentual: 10,
      limiteChuvaHoras: limite,
      fatorCompra: fator,
    );
  }

  group('ParametrosOperacionais', () {
    test('usa os valores da fazenda como padrao', () {
      var parametros = ParametrosOperacionais(
        toleranciaSobredosePercentual: 10,
      );

      expect(parametros.toleranciaSobredosePercentual, 10);
      expect(parametros.limiteChuvaHoras, 3);
      expect(parametros.fatorCompra, 0.95);
    });

    test('guarda os valores informados', () {
      var parametros = criar(limite: 6, fator: 0.9);

      expect(parametros.limiteChuvaHoras, 6);
      expect(parametros.fatorCompra, 0.9);
    });

    test('aceita tolerancia zero (nenhum excesso permitido)', () {
      var parametros = ParametrosOperacionais(toleranciaSobredosePercentual: 0);

      expect(parametros.toleranciaSobredosePercentual, 0);
    });

    test('recusa tolerancia negativa ou invalida', () {
      for (var valor in [-1.0, double.nan, double.infinity]) {
        expect(
          () => ParametrosOperacionais(toleranciaSobredosePercentual: valor),
          recusa,
        );
      }
    });

    test('recusa limite da chuva zero, negativo ou invalido', () {
      for (var valor in [0.0, -3.0, double.nan]) {
        expect(() => criar(limite: valor), recusa);
      }
    });

    test('recusa fator de compra zero, negativo ou invalido', () {
      for (var valor in [0.0, -0.95, double.nan]) {
        expect(() => criar(fator: valor), recusa);
      }
    });
  });
}
