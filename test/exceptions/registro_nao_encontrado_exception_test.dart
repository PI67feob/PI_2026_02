import 'package:caderno_fazenda/exceptions/agrogestor_exception.dart';
import 'package:caderno_fazenda/exceptions/registro_nao_encontrado_exception.dart';
import 'package:test/test.dart';

void main() {
  group('RegistroNaoEncontradoException', () {
    test('e uma AgroGestorException', () {
      var excecao = RegistroNaoEncontradoException('talhão', 99);

      expect(excecao, isA<AgroGestorException>());
    });

    test('mensagem inclui a entidade e o id', () {
      var excecao = RegistroNaoEncontradoException('talhão', 99);

      expect(excecao.mensagem, 'Registro não encontrado: talhão 99');
      expect(excecao.toString(), 'Registro não encontrado: talhão 99');
      expect(excecao.entidade, 'talhão');
      expect(excecao.id, 99);
    });

    test('pode ser capturada como AgroGestorException', () {
      expect(
        () => throw RegistroNaoEncontradoException('insumo', 7),
        throwsA(isA<AgroGestorException>()),
      );
    });
  });
}
