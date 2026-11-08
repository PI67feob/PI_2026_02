import 'package:caderno_fazenda/cli/formato.dart';
import 'package:caderno_fazenda/logica/alertas_operacionais.dart';
import 'package:caderno_fazenda/models/aplicacao.dart';
import 'package:caderno_fazenda/models/aplicacao_insumo.dart';
import 'package:caderno_fazenda/models/area.dart';
import 'package:caderno_fazenda/models/drone.dart';
import 'package:caderno_fazenda/models/insumo.dart';
import 'package:caderno_fazenda/models/motivo_reaplicacao.dart';
import 'package:caderno_fazenda/models/operacao.dart';
import 'package:caderno_fazenda/models/talhao.dart';
import 'package:caderno_fazenda/models/unidade_dose.dart';
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
        'cabe numa viagem só',
      );
      expect(
        descreverResultadoCapacidade(ResultadoCapacidade.excedeu),
        'não cabe numa viagem só (precisa de mais de uma)',
      );
      expect(
        descreverResultadoCapacidade(ResultadoCapacidade.entradaInvalida),
        contains('inválidos'),
      );
    });
  });

  group('descreverViagens', () {
    test('uma viagem fica no singular', () {
      expect(descreverViagens(1, 70, 'L'), '1 viagem (até 70 L por viagem)');
    });

    test('mais de uma viagem fica no plural', () {
      expect(descreverViagens(2, 70, 'kg'), '2 viagens (até 70 kg por viagem)');
      expect(descreverViagens(7, 20, 'L'), '7 viagens (até 20 L por viagem)');
    });

    test('capacidade com casas decimais aparece sem zeros sobrando', () {
      expect(descreverViagens(3, 2.5, 'L'), '3 viagens (até 2,5 L por viagem)');
    });

    test('sem viagens calculadas, avisa que falta a capacidade', () {
      expect(
        descreverViagens(null, null, 'L'),
        'não calculadas (aplicador sem capacidade em L)',
      );
      expect(
        descreverViagens(null, null, 'kg'),
        'não calculadas (aplicador sem capacidade em kg)',
      );
    });
  });
  group('plural', () {
    test('um fica no singular; zero e vários, no plural', () {
      expect(plural(1, 'talhão', 'talhões'), 'talhão');
      expect(plural(0, 'talhão', 'talhões'), 'talhões');
      expect(plural(2, 'talhão', 'talhões'), 'talhões');
    });
  });

  group('descrição de registros em uma linha', () {
    test('insumo sem marca', () {
      final insumo = Insumo(nome: 'Orkestra SC', tipo: 'Fungicida');
      expect(descreverInsumo(insumo), 'Orkestra SC (Fungicida)');
    });

    test('insumo com marca', () {
      final insumo = Insumo(
        nome: 'Orkestra SC',
        tipo: 'Fungicida',
        marca: 'BASF',
      );
      expect(descreverInsumo(insumo), 'Orkestra SC (Fungicida, BASF)');
    });

    test('talhão com a área e os hectares', () {
      final talhao = Talhao(
        nome: 'Chico1',
        hectares: 2.8,
        area: Area(nome: 'Sede', id: 1),
      );
      expect(descreverTalhao(talhao), 'Sede / Chico1 - 2,80 ha');
    });

    test('aplicação com data, operação, aplicador, talhões e insumos', () {
      final sede = Area(nome: 'Sede', id: 1);
      final insumo = Insumo(nome: 'Orkestra SC', tipo: 'Fungicida', id: 1);
      final aplicacao = Aplicacao(
        data: DateTime(2026, 11, 6),
        operacao: Operacao(descricao: 'Pulverização', id: 1),
        aplicador: Drone(modelo: 'DJI', capacidadeMaximaL: 70, id: 1),
        talhoes: [
          Talhao(nome: 'Chico1', hectares: 2.8, area: sede, id: 1),
          Talhao(nome: 'Chico2', hectares: 3.8, area: sede, id: 2),
        ],
        insumos: [
          AplicacaoInsumo(
            insumo: insumo,
            unidade: UnidadeDose.litrosPorHectare,
            dosePrevista: 0.3,
          ),
        ],
      );
      expect(
        descreverAplicacao(aplicacao),
        '06/11/2026 | Pulverização | drone | Chico1, Chico2 (6,60 ha) | '
        '1 insumo',
      );
      expect(
        descreverAplicacao(aplicacao, reaplicar: true),
        '06/11/2026 | Pulverização | drone | Chico1, Chico2 (6,60 ha) | '
        '1 insumo | REAPLICAR',
      );
    });
  });

  group('imprevistos que obrigam a reaplicar', () {
    test('textosDosMotivos segue a ordem do enum', () {
      expect(textosDosMotivos, ['chuva', 'sol/calor', 'vento', 'outro motivo']);
    });

    test('sem chuva e sem motivo, não há aviso', () {
      expect(avisosDeReaplicacao(chuva: null, limiteChuvaHoras: 3), isEmpty);
      expect(
        avisosDeReaplicacao(
          chuva: DecisaoChuva.naoReaplicar,
          limiteChuvaHoras: 3,
        ),
        isEmpty,
      );
    });

    test('chuva antes do limite avisa com o limite em vigor', () {
      expect(
        avisosDeReaplicacao(chuva: DecisaoChuva.reaplicar, limiteChuvaHoras: 3),
        ['Choveu em menos de 3 h: REAPLICAR a aplicação.'],
      );
      expect(
        avisosDeReaplicacao(
          chuva: DecisaoChuva.reaplicar,
          limiteChuvaHoras: 2.5,
        ),
        ['Choveu em menos de 2,5 h: REAPLICAR a aplicação.'],
      );
    });

    test('um motivo marcado avisa com o texto do motivo', () {
      expect(
        avisosDeReaplicacao(
          chuva: null,
          limiteChuvaHoras: 3,
          motivo: MotivoReaplicacao.solCalor,
        ),
        ['Marcada para reaplicar por sol/calor: REAPLICAR a aplicação.'],
      );
      expect(
        avisosDeReaplicacao(
          chuva: null,
          limiteChuvaHoras: 3,
          motivo: MotivoReaplicacao.outro,
        ),
        ['Marcada para reaplicar por outro motivo: REAPLICAR a aplicação.'],
      );
    });

    test('chuva e outro motivo juntos dão dois avisos', () {
      expect(
        avisosDeReaplicacao(
          chuva: DecisaoChuva.reaplicar,
          limiteChuvaHoras: 3,
          motivo: MotivoReaplicacao.vento,
        ),
        [
          'Choveu em menos de 3 h: REAPLICAR a aplicação.',
          'Marcada para reaplicar por vento: REAPLICAR a aplicação.',
        ],
      );
    });

    test('o motivo chuva não repete o aviso da chuva', () {
      expect(
        avisosDeReaplicacao(
          chuva: DecisaoChuva.reaplicar,
          limiteChuvaHoras: 3,
          motivo: MotivoReaplicacao.chuva,
        ),
        ['Choveu em menos de 3 h: REAPLICAR a aplicação.'],
      );
    });

    test(
      'o motivo chuva avisa sozinho quando a regra já não manda reaplicar',
      () {
        expect(
          avisosDeReaplicacao(
            chuva: DecisaoChuva.naoReaplicar,
            limiteChuvaHoras: 3,
            motivo: MotivoReaplicacao.chuva,
          ),
          ['Marcada para reaplicar por chuva: REAPLICAR a aplicação.'],
        );
      },
    );
  });
}
