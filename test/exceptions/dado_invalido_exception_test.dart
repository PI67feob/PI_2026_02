import 'package:caderno_fazenda/exceptions/agrogestor_exception.dart';
import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';
import 'package:test/test.dart';

void main() {
  group('DadoInvalidoException', () {
    test('e uma AgroGestorException', () {
      var excecao = DadoInvalidoException('nome', 'vazio');

      expect(excecao, isA<AgroGestorException>());
    });

    test('mensagem segue o padrao e inclui o campo e o motivo', () {
      var excecao = DadoInvalidoException('nome da área', 'vazio');

      expect(excecao.mensagem, 'Dado inválido: nome da área (vazio)');
      expect(excecao.toString(), 'Dado inválido: nome da área (vazio)');
      expect(excecao.campo, 'nome da área');
      expect(excecao.motivo, 'vazio');
    });

    test('pode ser capturada como AgroGestorException', () {
      expect(
        () => throw DadoInvalidoException('nome', 'vazio'),
        throwsA(isA<AgroGestorException>()),
      );
    });
  });
}
