import 'dart:math';

import 'package:caderno_fazenda/cli/menu_caderno.dart';
import 'package:caderno_fazenda/repositories/repositorios.dart';
import 'package:test/test.dart';

import '../ajuda/terminal_simulado.dart';

/// Sessões de uso sorteadas: um "usuário" que cadastra, registra, corrige e
/// exclui com valores às vezes certos e às vezes errados.
///
/// O teste não confere o texto da tela, só duas coisas que nunca podem
/// acontecer, qualquer que seja a sequência de respostas:
/// 1. aparecer "Erro inesperado" (um erro que ninguém previu);
/// 2. sobrar no repositório um registro apontando para outro que não existe
///    mais (por exemplo, uma aplicação cujo talhão foi excluído);
/// 3. ficar gravada uma chuva abaixo do limite sem o motivo de reaplicação
///    (o BI conta as reaplicações pelo motivo).
///
/// O sorteio usa uma semente fixa, então a mesma sequência roda toda vez.
/// Se algum dia falhar, o número da sessão e as respostas aparecem na falha.
void main() {
  group('sessões sorteadas', () {
    const sessoes = 250;
    final sorteio = Random(2026);

    String sortear(List<String> opcoes) =>
        opcoes[sorteio.nextInt(opcoes.length)];

    List<String> cadastrar() {
      final tipo = sortear(['1', '2', '3', '4', '5']);
      return [
        '1',
        tipo,
        ...switch (tipo) {
          '1' => [
            sortear(['Norte', 'Sul', 'Sede']),
          ],
          '2' => [
            sortear(['1', '2']),
            sortear(['T1', 'T2', 'Chico1']),
            sortear(['1', '2,5', '0', 'x']),
          ],
          '3' => [
            sortear(['Zinco', 'Orkestra SC', 'Cobre']),
            sortear(['Fertilizante', 'Fungicida']),
            sortear(['', 'Marca']),
          ],
          '4' => [
            sortear(['1', '2', '3']),
            sortear(['', 'Modelo']),
            sortear(['', '20', '0', '70']),
            sortear(['', '10', '70']),
          ],
          _ => [
            sortear(['Adubação', 'Capina', 'Pulverização']),
          ],
        },
        '0',
      ];
    }

    List<String> registrar() {
      final respostas = [
        '2',
        sortear(['1', '1', '1', '2', 'x']),
        sortear(['1', '1', '2', '3', '9']),
        sortear(['1', '2', '1,2', '1,1', '3', '1,2,3']),
        sortear(['', '', '07/11/2026', '32/01/2026', '15/11/2026']),
        sortear(['10', '200', '50', '0', '-5', '1e3', 'abc', '5000']),
      ];
      final insumos = 1 + sorteio.nextInt(3);
      for (var i = 0; i < insumos; i++) {
        respostas.addAll([
          sortear(['1', '2', '1', '2', '3']),
          sortear(['1', '2', '3', '4', '5']),
          sortear(['300', '0,5', '20', '2', '0', '-1', 'x', '1000']),
          sortear(['', '', '345', '0,6', '25', '0', '3000']),
          i == insumos - 1 ? 'n' : 's',
        ]);
      }
      respostas.addAll([
        sortear(['', '', '2,5', '5', '-1', '0']),
        sortear(['', '', '1', '2', '3', '4', '9']),
        sortear(['', 'obs']),
        sortear(['', '', 's', 'n']),
      ]);
      return respostas;
    }

    List<String> corrigir() {
      final tipo = sortear(['1', '2', '3', '4', '5', '6']);
      return [
        '8',
        tipo,
        sortear(['1', '2', '3', '1', '9']),
        ...switch (tipo) {
          '1' => [
            sortear(['', 'Norte', 'Sede']),
            sortear(['', 's', 'n']),
          ],
          '2' => [
            sortear(['', 'Chico1', 'Chico2', 'Novo']),
            sortear(['', '1', '5,5', '0', 'x']),
            sortear(['', 's', 'n']),
          ],
          '3' => [
            sortear(['', 'Orkestra SC', 'Boro']),
            sortear(['', 'Fungicida', 'Outro']),
            sortear(['', '-', 'Bayer']),
            sortear(['', 's', 'n']),
          ],
          '4' => [
            sortear(['', 'DJI', '-']),
            sortear(['', '80', '-', '0', '10']),
            sortear(['', '-', '75', '1']),
            sortear(['', 's', 'n']),
          ],
          '5' => [
            sortear(['', 'Adubação', 'Pulverização']),
            sortear(['', 's', 'n']),
          ],
          _ => [
            sortear(['', '15/11/2026', '31/02/2026']),
            sortear(['', '-', 'texto']),
            sortear(['', '2', '8', '-', '-1', 'x']),
            sortear(['', '-', '1', '2', '3', '4']),
            for (var i = 0; i < 3; i++) ...[
              sortear(['n', 's', 'n']),
              sortear(['1', '2']),
              sortear(['100', '3450', '0,3', '0', '-1', '25000']),
            ],
            sortear(['', 's', 'n']),
          ],
        },
        '0',
      ];
    }

    List<String> excluir() {
      return [
        '9',
        sortear(['1', '2', '3', '4', '5', '6']),
        sortear(['1', '2', '3', '1', '2', '9']),
        sortear(['s', 's', 'n', '']),
        '0',
      ];
    }

    /// Procura registros que apontam para algo que não existe mais. Devolve
    /// null se estiver tudo certo, ou o que está errado.
    Future<String?> conferirIntegridade(Repositorios repos) async {
      final areas = {for (final a in await repos.areas.listarTodos()) a.id};
      final talhoes = {
        for (final t in await repos.talhoes.listarTodos()) t.id: t,
      };
      final insumos = {for (final i in await repos.insumos.listarTodos()) i.id};
      final aplicadores = {
        for (final a in await repos.aplicadores.listarTodos()) a.id,
      };
      final operacoes = {
        for (final o in await repos.operacoes.listarTodos()) o.id,
      };
      for (final talhao in talhoes.values) {
        if (!areas.contains(talhao.area.id)) {
          return 'talhão ${talhao.id} aponta para uma área que não existe';
        }
      }
      for (final aplicacao in await repos.aplicacoes.listarTodos()) {
        final id = aplicacao.id;
        if (!operacoes.contains(aplicacao.operacao.id)) {
          return 'aplicação $id: a operação sumiu';
        }
        if (!aplicadores.contains(aplicacao.aplicador.id)) {
          return 'aplicação $id: o aplicador sumiu';
        }
        for (final talhao in aplicacao.talhoes) {
          if (!talhoes.containsKey(talhao.id)) {
            return 'aplicação $id: o talhão ${talhao.id} sumiu';
          }
        }
        for (final item in aplicacao.insumos) {
          if (!insumos.contains(item.insumo.id)) {
            return 'aplicação $id: o insumo ${item.insumo.id} sumiu';
          }
          final realizada = item.doseRealizada;
          if (item.dosePrevista <= 0 || (realizada != null && realizada < 0)) {
            return 'aplicação $id: dose inválida guardada';
          }
        }
        if (aplicacao.areaTotalHa <= 0) {
          return 'aplicação $id: área zerada';
        }
        // Chuva abaixo do limite padrão (3 h) sempre deixa o motivo gravado,
        // porque é por ele que o BI conta as reaplicações.
        final horas = aplicacao.horasAteChuva;
        if (horas != null && horas < 3 && aplicacao.motivoReaplicacao == null) {
          return 'aplicação $id: chuva em $horas h sem motivo de reaplicação';
        }
      }
      return null;
    }

    test('$sessoes sessões sem erro inesperado e sem registro órfão', () async {
      var registradas = 0;
      var exclusoes = 0;
      for (var sessao = 0; sessao < sessoes; sessao++) {
        final respostas = ['7'];
        final acoes = 15 + sorteio.nextInt(40);
        for (var i = 0; i < acoes; i++) {
          respostas.addAll(switch (sorteio.nextInt(8)) {
            0 || 1 || 2 => registrar(),
            3 || 4 => corrigir(),
            5 || 6 => excluir(),
            _ => cadastrar(),
          });
        }
        final repos = Repositorios.memoria();
        final terminal = TerminalSimulado(respostas);
        await MenuCaderno(repos, terminal).executar();

        final saida = terminal.saida;
        registradas += 'REGISTRADA'.allMatches(saida).length;
        exclusoes += 'Excluído:'.allMatches(saida).length;
        final contexto = 'sessão $sessao, respostas: ${respostas.join(' | ')}';
        expect(saida.contains('Erro inesperado'), isFalse, reason: contexto);
        expect(await conferirIntegridade(repos), isNull, reason: contexto);
      }
      // Garante que o sorteio chegou longe: houve registros e exclusões.
      expect(registradas, greaterThan(0));
      expect(exclusoes, greaterThan(0));
    });
  });
}
