import 'package:caderno_fazenda/exceptions/agrogestor_exception.dart';
import 'package:caderno_fazenda/exceptions/dose_invalida_exception.dart';
import 'package:test/test.dart';

void main() {
  group('DoseInvalidaException', () {
    test('e uma AgroGestorException', () {
      expect(DoseInvalidaException(-2, 'L/ha'), isA<AgroGestorException>());
    });

    test('mensagem segue o padrao e inclui o valor recebido', () {
      var excecao = DoseInvalidaException(-2, 'L/ha');

      expect(excecao.mensagem, 'Dose inválida: -2 L/ha');
      expect(excecao.toString(), 'Dose inválida: -2 L/ha');
    });

    test('guarda a dose e a unidade', () {
      var excecao = DoseInvalidaException(0.5, 'kg/ha');

      expect(excecao.dose, 0.5);
      expect(excecao.unidade, 'kg/ha');
      expect(excecao.mensagem, 'Dose inválida: 0.5 kg/ha');
    });

    test('pode ser capturada como AgroGestorException', () {
      expect(
        () => throw DoseInvalidaException(-2, 'L/ha'),
        throwsA(isA<AgroGestorException>()),
      );
    });
  });
}
