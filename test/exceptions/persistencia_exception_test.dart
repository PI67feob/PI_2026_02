import 'package:caderno_fazenda/exceptions/agrogestor_exception.dart';
import 'package:caderno_fazenda/exceptions/persistencia_exception.dart';
import 'package:test/test.dart';

void main() {
  group('PersistenciaException', () {
    test('e uma AgroGestorException', () {
      expect(
        PersistenciaException('salvar talhão'),
        isA<AgroGestorException>(),
      );
    });

    test('mensagem segue o padrao e inclui o valor recebido', () {
      var excecao = PersistenciaException('salvar talhão');

      expect(excecao.mensagem, 'Erro de persistência: salvar talhão');
      expect(excecao.toString(), 'Erro de persistência: salvar talhão');
    });

    test('guarda a causa tecnica sem mostrar na mensagem', () {
      var erroMysql = StateError('MySQL error 1045: Access denied');
      var excecao = PersistenciaException('buscar insumos', causa: erroMysql);

      expect(excecao.operacao, 'buscar insumos');
      expect(excecao.causa, same(erroMysql));
      expect(excecao.mensagem, 'Erro de persistência: buscar insumos');
      expect(excecao.mensagem, isNot(contains('MySQL')));
    });

    test('pode ser capturada como AgroGestorException', () {
      expect(
        () => throw PersistenciaException('salvar talhão'),
        throwsA(isA<AgroGestorException>()),
      );
    });
  });
}
