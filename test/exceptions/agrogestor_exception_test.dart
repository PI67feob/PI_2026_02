import 'package:caderno_fazenda/exceptions/agrogestor_exception.dart';
import 'package:test/test.dart';

/// Subclasse só para teste, já que a classe-base é abstrata.
class _ExcecaoDeTeste extends AgroGestorException {
  _ExcecaoDeTeste(super.mensagem);
}

void main() {
  group('AgroGestorException', () {
    test('implementa Exception', () {
      expect(_ExcecaoDeTeste('Erro: 1'), isA<Exception>());
    });

    test('guarda a mensagem recebida', () {
      expect(_ExcecaoDeTeste('Erro: 1').mensagem, 'Erro: 1');
    });

    test('toString devolve a mensagem', () {
      expect(_ExcecaoDeTeste('Erro: 1').toString(), 'Erro: 1');
    });
  });
}
