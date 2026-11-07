import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';
import 'package:caderno_fazenda/models/validacoes.dart';
import 'package:test/test.dart';

import '../ajuda/erros.dart';

void main() {
  var recusa = throwsA(isA<DadoInvalidoException>());

  group('textoObrigatorio', () {
    test('tira os espacos das pontas', () {
      expect(textoObrigatorio('  Sede  ', 'nome'), 'Sede');
    });

    test('recusa nulo, vazio e so espacos', () {
      for (var valor in [null, '', '   ']) {
        expect(() => textoObrigatorio(valor, 'nome'), recusa);
      }
    });

    test('a mensagem cita o campo', () {
      var mensagem = mensagemDoErro(() => textoObrigatorio('', 'nome'));

      expect(mensagem, 'Dado inválido: nome (não pode ser vazio)');
    });
  });

  group('textoOpcional', () {
    test('tira os espacos das pontas', () {
      expect(textoOpcional('  Jacto '), 'Jacto');
    });

    test('devolve nulo para nulo, vazio e so espacos', () {
      expect(textoOpcional(null), isNull);
      expect(textoOpcional(''), isNull);
      expect(textoOpcional('   '), isNull);
    });
  });

  group('positivoOuNulo', () {
    test('aceita nulo', () {
      expect(positivoOuNulo(null, 'capacidade'), isNull);
    });

    test('aceita numero positivo', () {
      expect(positivoOuNulo(70, 'capacidade'), 70);
      expect(positivoOuNulo(0.5, 'capacidade'), 0.5);
    });

    test('recusa zero, negativo, infinito e NaN', () {
      for (var valor in [0.0, -1.0, double.infinity, double.nan]) {
        expect(() => positivoOuNulo(valor, 'capacidade'), recusa);
      }
    });

    test('a mensagem cita o campo', () {
      var mensagem = mensagemDoErro(() => positivoOuNulo(0, 'capacidade'));

      expect(mensagem, 'Dado inválido: capacidade (deve ser maior que zero)');
    });
  });
}
