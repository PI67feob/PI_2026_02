import 'package:caderno_fazenda/exceptions/dose_invalida_exception.dart';
import 'package:caderno_fazenda/models/aplicacao_insumo.dart';
import 'package:caderno_fazenda/models/insumo.dart';
import 'package:caderno_fazenda/models/unidade_dose.dart';
import 'package:test/test.dart';

import '../ajuda/erros.dart';

void main() {
  var orkestra = Insumo(nome: 'Orkestra SC', tipo: 'Fungicida');
  var recusa = throwsA(isA<DoseInvalidaException>());

  AplicacaoInsumo criar({double previsto = 2, double? realizado}) {
    return AplicacaoInsumo(
      insumo: orkestra,
      unidade: UnidadeDose.litrosPorHectare,
      dosePrevista: previsto,
      doseRealizada: realizado,
    );
  }

  group('AplicacaoInsumo', () {
    test('guarda insumo, unidade e doses', () {
      var item = criar(previsto: 0.3, realizado: 0.35);

      expect(item.insumo, same(orkestra));
      expect(item.unidade, UnidadeDose.litrosPorHectare);
      expect(item.dosePrevista, 0.3);
      expect(item.doseRealizada, 0.35);
    });

    test('dose realizada pode ficar vazia e entrar depois', () {
      var item = criar();

      expect(item.doseRealizada, isNull);

      item.registrarDoseRealizada(1.8);

      expect(item.doseRealizada, 1.8);
    });

    test('dose realizada zero e aceita', () {
      expect(criar(realizado: 0).doseRealizada, 0);
    });

    test('dose prevista zero, negativa ou invalida e recusada', () {
      for (var dose in [0.0, -1.0, double.nan, double.infinity]) {
        expect(() => criar(previsto: dose), recusa);
      }
    });

    test('dose realizada negativa ou invalida e recusada', () {
      for (var dose in [-0.1, double.nan, double.infinity]) {
        expect(() => criar(realizado: dose), recusa);
      }
    });

    test('registrarDoseRealizada recusa valor invalido', () {
      var item = criar(realizado: 1.5);

      expect(() => item.registrarDoseRealizada(-1), recusa);
      expect(item.doseRealizada, 1.5);
    });

    test('a mensagem inclui a dose e a unidade', () {
      var mensagem = mensagemDoErro(() => criar(previsto: -1));

      expect(mensagem, 'Dose inválida: -1.0 L/ha');
    });
  });
}
