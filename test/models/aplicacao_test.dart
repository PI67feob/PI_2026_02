import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';
import 'package:caderno_fazenda/models/aplicacao.dart';
import 'package:caderno_fazenda/models/aplicacao_insumo.dart';
import 'package:caderno_fazenda/models/area.dart';
import 'package:caderno_fazenda/models/drone.dart';
import 'package:caderno_fazenda/models/insumo.dart';
import 'package:caderno_fazenda/models/operacao.dart';
import 'package:caderno_fazenda/models/talhao.dart';
import 'package:caderno_fazenda/models/unidade_dose.dart';
import 'package:test/test.dart';

import '../ajuda/erros.dart';

void main() {
  var sede = Area(nome: 'Sede', id: 1);
  var chico1 = Talhao(nome: 'Chico1', hectares: 2.8, area: sede, id: 1);
  var chico2 = Talhao(nome: 'Chico2', hectares: 3.8, area: sede, id: 2);
  var operacao = Operacao(descricao: 'Pulverização', id: 1);
  var drone = Drone(modelo: 'DJI', capacidadeMaximaL: 70, id: 1);
  var orkestra = Insumo(nome: 'Orkestra SC', tipo: 'Fungicida', id: 1);
  var boro = Insumo(nome: 'Boro Super', tipo: 'Fertilizante', id: 2);
  var recusa = throwsA(isA<DadoInvalidoException>());

  AplicacaoInsumo dose(Insumo insumo) {
    return AplicacaoInsumo(
      insumo: insumo,
      unidade: UnidadeDose.litrosPorHectare,
      dosePrevista: 1,
    );
  }

  Aplicacao criar({List<Talhao>? talhoes, List<AplicacaoInsumo>? insumos}) {
    return Aplicacao(
      data: DateTime(2026, 11, 6),
      operacao: operacao,
      aplicador: drone,
      talhoes: talhoes ?? [chico1, chico2],
      insumos: insumos ?? [dose(orkestra), dose(boro)],
    );
  }

  group('Aplicacao', () {
    test('guarda a composicao: operacao, aplicador, talhoes e insumos', () {
      var aplicacao = criar();

      expect(aplicacao.operacao, same(operacao));
      expect(aplicacao.aplicador, same(drone));
      expect(aplicacao.talhoes, [chico1, chico2]);
      expect(aplicacao.insumos.length, 2);
      expect(aplicacao.id, isNull);
    });

    test('a data fica sem horario', () {
      var aplicacao = Aplicacao(
        data: DateTime(2026, 11, 6, 14, 30),
        operacao: operacao,
        aplicador: drone,
        talhoes: [chico1],
        insumos: [dose(orkestra)],
      );

      expect(aplicacao.data, DateTime(2026, 11, 6));
    });

    test('areaTotalHa soma os hectares dos talhoes', () {
      expect(criar().areaTotalHa, closeTo(6.6, 1e-9));
      expect(criar(talhoes: [chico2]).areaTotalHa, closeTo(3.8, 1e-9));
    });

    test('as listas devolvidas nao podem ser alteradas de fora', () {
      var aplicacao = criar();

      expect(() => aplicacao.talhoes.add(chico1), throwsUnsupportedError);
      expect(() => aplicacao.insumos.clear(), throwsUnsupportedError);
    });

    test('adicionarTalhao e adicionarInsumo incluem na aplicacao', () {
      var aplicacao = criar(talhoes: [chico1], insumos: [dose(orkestra)]);

      aplicacao.adicionarTalhao(chico2);
      aplicacao.adicionarInsumo(dose(boro));

      expect(aplicacao.talhoes, [chico1, chico2]);
      expect(aplicacao.insumos.length, 2);
    });

    test('exige ao menos um talhao e um insumo', () {
      expect(() => criar(talhoes: []), recusa);
      expect(() => criar(insumos: []), recusa);
    });

    test('recusa talhao repetido, pelo objeto ou pelo id', () {
      var mesmoId = Talhao(nome: 'Outro', hectares: 1, area: sede, id: 1);

      expect(() => criar(talhoes: [chico1, chico1]), recusa);
      expect(() => criar(talhoes: [chico1, mesmoId]), recusa);
    });

    test('recusa insumo repetido', () {
      expect(() => criar(insumos: [dose(orkestra), dose(orkestra)]), recusa);
    });

    test('a mensagem de repetido cita o nome', () {
      var mensagem = mensagemDoErro(() => criar(talhoes: [chico1, chico1]));

      expect(mensagem, 'Dado inválido: talhões (Chico1 repetido)');
    });

    test('observacao em branco vira nulo e o texto e aparado', () {
      var aplicacao = criar();
      expect(aplicacao.observacao, isNull);

      aplicacao.observacao = '  chuva no fim da tarde ';
      expect(aplicacao.observacao, 'chuva no fim da tarde');

      aplicacao.observacao = '   ';
      expect(aplicacao.observacao, isNull);
    });
  });
}
