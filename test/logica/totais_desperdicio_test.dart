import 'package:caderno_fazenda/logica/totais_desperdicio.dart';
import 'package:test/test.dart';

DoseNaArea _dose(String unidade, double area, double previsto, double? real) {
  return DoseNaArea(
    areaHa: area,
    dosePrevista: previsto,
    doseRealizada: real,
    unidade: unidade,
  );
}

void main() {
  group('totalizarPorUnidade', () {
    test('sem doses devolve mapa vazio', () {
      expect(totalizarPorUnidade([]), isEmpty);
    });

    test('se nenhuma dose tem valor realizado, o mapa fica vazio', () {
      expect(totalizarPorUnidade([_dose('L/ha', 5, 1, null)]), isEmpty);
    });

    test('soma previsto, realizado e desperdicio de uma unidade', () {
      var totais = totalizarPorUnidade([_dose('L/ha', 6.6, 0.3, 0.345)]);
      var litros = totais['L/ha']!;

      expect(litros.unidade, 'L/ha');
      expect(litros.totalPrevisto, closeTo(1.98, 1e-9));
      expect(litros.totalRealizado, closeTo(2.277, 1e-9));
      expect(litros.volumeDesperdicado, closeTo(0.297, 1e-9));
      expect(litros.percentual, closeTo(15, 1e-9));
    });

    test('separa litros de quilos, sem misturar', () {
      var doses = [_dose('L/ha', 2, 10, 12), _dose('kg/ha', 3, 5, 4)];
      var totais = totalizarPorUnidade(doses);

      expect(totais.keys.toList(), ['L/ha', 'kg/ha']);
      expect(totais['L/ha']!.totalPrevisto, closeTo(20, 1e-9));
      expect(totais['L/ha']!.totalRealizado, closeTo(24, 1e-9));
      expect(totais['L/ha']!.volumeDesperdicado, closeTo(4, 1e-9));
      expect(totais['kg/ha']!.totalPrevisto, closeTo(15, 1e-9));
      expect(totais['kg/ha']!.totalRealizado, closeTo(12, 1e-9));
      expect(totais['kg/ha']!.volumeDesperdicado, closeTo(0, 1e-9));
    });

    test('aplicar menos nao abate o excesso de outra dose', () {
      var doses = [_dose('L/ha', 1, 10, 11), _dose('L/ha', 1, 10, 8)];
      var litros = totalizarPorUnidade(doses)['L/ha']!;

      expect(litros.totalPrevisto, closeTo(20, 1e-9));
      expect(litros.totalRealizado, closeTo(19, 1e-9));
      expect(litros.volumeDesperdicado, closeTo(1, 1e-9));
      expect(litros.percentual, closeTo(5, 1e-9));
    });

    test('so conta as doses que ja tem valor realizado', () {
      var doses = [_dose('L/ha', 2, 10, 12), _dose('L/ha', 100, 10, null)];
      var litros = totalizarPorUnidade(doses)['L/ha']!;

      expect(litros.totalPrevisto, closeTo(20, 1e-9));
      expect(litros.totalRealizado, closeTo(24, 1e-9));
    });
  });

  group('TotaisDesperdicio', () {
    test('percentual e o desperdicio sobre o previsto', () {
      var totais = TotaisDesperdicio(
        unidade: 'kg/ha',
        totalPrevisto: 200,
        totalRealizado: 230,
        volumeDesperdicado: 30,
      );

      expect(totais.percentual, closeTo(15, 1e-9));
    });

    test('percentual e zero quando nada foi previsto', () {
      var totais = TotaisDesperdicio(
        unidade: 'kg/ha',
        totalPrevisto: 0,
        totalRealizado: 0,
        volumeDesperdicado: 0,
      );

      expect(totais.percentual, 0);
    });
  });
}
