import 'package:caderno_fazenda/exceptions/agrogestor_exception.dart';
import 'package:caderno_fazenda/exceptions/capacidade_excedida_exception.dart';
import 'package:test/test.dart';

void main() {
  group('CapacidadeExcedidaException', () {
    test('e uma AgroGestorException', () {
      expect(
        CapacidadeExcedidaException(2500, 2000, 'L'),
        isA<AgroGestorException>(),
      );
    });

    test('mensagem segue o padrao e inclui o valor recebido', () {
      var excecao = CapacidadeExcedidaException(2500, 2000, 'L');

      expect(excecao.mensagem, 'Capacidade excedida: 2500 L (máximo 2000 L)');
      expect(excecao.toString(), 'Capacidade excedida: 2500 L (máximo 2000 L)');
    });

    test('guarda valor, capacidade maxima e unidade', () {
      var excecao = CapacidadeExcedidaException(612.5, 600, 'kg');

      expect(excecao.valor, 612.5);
      expect(excecao.capacidadeMaxima, 600);
      expect(excecao.unidade, 'kg');
    });

    test('pode ser capturada como AgroGestorException', () {
      expect(
        () => throw CapacidadeExcedidaException(2500, 2000, 'L'),
        throwsA(isA<AgroGestorException>()),
      );
    });
  });
}
