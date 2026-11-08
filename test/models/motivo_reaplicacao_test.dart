import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';
import 'package:caderno_fazenda/models/motivo_reaplicacao.dart';
import 'package:test/test.dart';

import '../ajuda/erros.dart';

void main() {
  group('MotivoReaplicacao', () {
    test('os códigos gravados no banco são fixos', () {
      expect(
        [for (final motivo in MotivoReaplicacao.values) motivo.codigo],
        ['chuva', 'sol', 'vento', 'outro'],
      );
    });

    test('os textos mostrados ao usuário', () {
      expect(
        [for (final motivo in MotivoReaplicacao.values) motivo.texto],
        ['chuva', 'sol/calor', 'vento', 'outro motivo'],
      );
    });

    test('deCodigo converte cada código no motivo certo', () {
      for (final motivo in MotivoReaplicacao.values) {
        expect(MotivoReaplicacao.deCodigo(motivo.codigo), motivo);
      }
    });

    test('deCodigo ignora espaços em volta', () {
      expect(MotivoReaplicacao.deCodigo(' sol '), MotivoReaplicacao.solCalor);
    });

    test('deCodigo recusa texto desconhecido e diz o que veio', () {
      final mensagem = mensagemDoErro(() => MotivoReaplicacao.deCodigo('neve'));

      expect(
        mensagem,
        'Dado inválido: motivo da reaplicação '
        '(use chuva, sol, vento ou outro (recebido: neve))',
      );
    });

    test('deCodigo não aceita o texto de tela no lugar do código', () {
      expect(
        () => MotivoReaplicacao.deCodigo('sol/calor'),
        throwsA(isA<DadoInvalidoException>()),
      );
    });
  });
}
