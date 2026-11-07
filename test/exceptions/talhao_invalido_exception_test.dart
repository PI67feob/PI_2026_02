import 'package:caderno_fazenda/exceptions/agrogestor_exception.dart';
import 'package:caderno_fazenda/exceptions/talhao_invalido_exception.dart';
import 'package:test/test.dart';

void main() {
  group('TalhaoInvalidoException', () {
    test('e uma AgroGestorException', () {
      expect(TalhaoInvalidoException('-3 ha'), isA<AgroGestorException>());
    });

    test('mensagem segue o padrao e inclui o valor recebido', () {
      var excecao = TalhaoInvalidoException('-3 ha');

      expect(excecao.mensagem, 'Talhão inválido: -3 ha');
      expect(excecao.toString(), 'Talhão inválido: -3 ha');
    });

    test('mensagem inclui o motivo quando informado', () {
      var excecao = TalhaoInvalidoException(
        '-3 ha',
        motivo: 'área deve ser maior que zero',
      );

      expect(
        excecao.mensagem,
        'Talhão inválido: -3 ha (área deve ser maior que zero)',
      );
      expect(excecao.valor, '-3 ha');
      expect(excecao.motivo, 'área deve ser maior que zero');
    });

    test('pode ser capturada como AgroGestorException', () {
      expect(
        () => throw TalhaoInvalidoException(99, motivo: 'id não encontrado'),
        throwsA(isA<AgroGestorException>()),
      );
    });
  });
}
