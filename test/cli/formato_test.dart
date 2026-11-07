import 'package:caderno_fazenda/cli/formato.dart';
import 'package:caderno_fazenda/logica/alertas_operacionais.dart';
import 'package:test/test.dart';

/// Testes das funções que transformam números, datas e decisões em texto.
void main() {
  group('formatarNumero', () {
    test('usa vírgula e o número de casas pedido', () {
      expect(formatarNumero(2.8), '2,80');
      expect(formatarNumero(0.3, 3), '0,300');
      expect(formatarNumero(66, 0), '66');
    });

    test('arredonda na última casa', () {
      expect(formatarNumero(123456.789), '123456,79');
    });
  });

  group('formatarCompacto', () {
    test('tira os zeros que sobram à direita', () {
      expect(formatarCompacto(10), '10');
      expect(formatarCompacto(0.345), '0,345');
      expect(formatarCompacto(1.5), '1,5');
      expect(formatarCompacto(0.95, 2), '0,95');
    });

    test('respeita o máximo de casas', () {
      expect(formatarCompacto(0.0099), '0,0099');
      expect(formatarCompacto(1 / 3), '0,3333');
      expect(formatarCompacto(1 / 3, 2), '0,33');
    });

    test('não mostra "-0"', () {
      expect(formatarCompacto(0), '0');
      expect(formatarCompacto(-0.00001), '0');
    });

    test('mantém o sinal de menos', () {
      expect(formatarCompacto(-100), '-100');
    });
  });

  group('formatarData', () {
    test('escreve dia/mês/ano com zero à esquerda', () {
      expect(formatarData(DateTime(2026, 11, 6)), '06/11/2026');
      expect(formatarData(DateTime(2026, 1, 5)), '05/01/2026');
    });
  });

  group('descreverChuva', () {
    test('um texto para cada decisão e outro para chuva não informada', () {
      expect(
        descreverChuva(DecisaoChuva.reaplicar),
        'choveu antes do limite: REAPLICAR',
      );
      expect(
        descreverChuva(DecisaoChuva.naoReaplicar),
        'choveu depois do limite: não reaplicar',
      );
      expect(descreverChuva(DecisaoChuva.entradaInvalida), 'horas inválidas');
      expect(descreverChuva(null), 'não informada');
    });
  });

  group('descreverSobredose', () {
    test('um texto para cada status e outro para dose não informada', () {
      expect(descreverSobredose(StatusSobredose.ok), 'ok');
      expect(
        descreverSobredose(StatusSobredose.atencao),
        'atenção (dentro da tolerância)',
      );
      expect(
        descreverSobredose(StatusSobredose.critico),
        'CRÍTICO (acima da tolerância)',
      );
      expect(
        descreverSobredose(StatusSobredose.entradaInvalida),
        'dose inválida',
      );
      expect(descreverSobredose(null), 'sem dose realizada');
    });
  });

  group('descreverResultadoCapacidade', () {
    test('um texto para cada resultado', () {
      expect(
        descreverResultadoCapacidade(ResultadoCapacidade.dentroDaCapacidade),
        'cabe no aplicador',
      );
      expect(
        descreverResultadoCapacidade(ResultadoCapacidade.excedeu),
        'EXCEDEU a capacidade do aplicador',
      );
      expect(
        descreverResultadoCapacidade(ResultadoCapacidade.entradaInvalida),
        contains('inválidos'),
      );
    });
  });
}
