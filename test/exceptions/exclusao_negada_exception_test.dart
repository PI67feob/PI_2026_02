import 'package:caderno_fazenda/exceptions/agrogestor_exception.dart';
import 'package:caderno_fazenda/exceptions/exclusao_negada_exception.dart';
import 'package:test/test.dart';

void main() {
  group('ExclusaoNegadaException', () {
    test('e uma AgroGestorException', () {
      var excecao = ExclusaoNegadaException('talhão Chico1', 'em uso');

      expect(excecao, isA<AgroGestorException>());
    });

    test('mensagem inclui o registro e o motivo', () {
      var excecao = ExclusaoNegadaException(
        'talhão Chico1',
        'usado na aplicação 3; exclua-a antes',
      );

      expect(
        excecao.mensagem,
        'Exclusão negada: talhão Chico1 (usado na aplicação 3; exclua-a antes)',
      );
      expect(excecao.toString(), excecao.mensagem);
      expect(excecao.registro, 'talhão Chico1');
      expect(excecao.motivo, 'usado na aplicação 3; exclua-a antes');
    });

    test('pode ser capturada como AgroGestorException', () {
      expect(
        () => throw ExclusaoNegadaException('área Sede', 'tem talhões'),
        throwsA(isA<AgroGestorException>()),
      );
    });
  });
}
