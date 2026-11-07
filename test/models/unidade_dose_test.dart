import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';
import 'package:caderno_fazenda/models/unidade_dose.dart';
import 'package:test/test.dart';

void main() {
  group('UnidadeDose', () {
    test('o texto bate com o valor gravado no banco', () {
      expect(UnidadeDose.litrosPorHectare.texto, 'L/ha');
      expect(UnidadeDose.quilosPorHectare.texto, 'kg/ha');
    });

    test('so existem duas unidades: litros e quilos nao se misturam', () {
      expect(UnidadeDose.values.length, 2);
    });

    test('deTexto converte o texto do banco', () {
      expect(UnidadeDose.deTexto('L/ha'), UnidadeDose.litrosPorHectare);
      expect(UnidadeDose.deTexto(' kg/ha '), UnidadeDose.quilosPorHectare);
    });

    test('deTexto recusa qualquer outro texto', () {
      for (var texto in ['mL/ha', 'l/ha', 'g/ha', '']) {
        expect(
          () => UnidadeDose.deTexto(texto),
          throwsA(isA<DadoInvalidoException>()),
        );
      }
    });
  });
}
