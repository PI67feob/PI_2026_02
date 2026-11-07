import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';
import 'package:caderno_fazenda/exceptions/talhao_invalido_exception.dart';
import 'package:caderno_fazenda/models/area.dart';
import 'package:caderno_fazenda/models/talhao.dart';
import 'package:test/test.dart';

import '../ajuda/erros.dart';

void main() {
  var sede = Area(nome: "Sede", id: 1);
  var recusaHectares = throwsA(isA<TalhaoInvalidoException>());
  var recusaNome = throwsA(isA<DadoInvalidoException>());

  test('Talhao guarda nome, id, hectares e area', () {
    var talhao = Talhao(nome: "Chico1", id: 1, hectares: 2.80, area: sede);

    expect(talhao.nome, "Chico1");
    expect(talhao.id, 1);
    expect(talhao.hectares, 2.80);
    expect(talhao.area, same(sede));
  });

  test('obterDados devolve os dados do talhao', () {
    var talhao = Talhao(nome: "Chico1", id: 1, hectares: 2.80, area: sede);

    expect(
      talhao.obterDados(),
      "nome:Chico1 - id:1 - hectares:2.8 - area:Sede",
    );
  });

  group('validacoes', () {
    test('hectares zero, negativo ou invalido e recusado', () {
      for (var hectares in [0.0, -2.5, double.nan, double.infinity]) {
        expect(
          () => Talhao(nome: "Chico1", hectares: hectares, area: sede),
          recusaHectares,
        );
      }
    });

    test('a mensagem cita o valor e o motivo', () {
      var mensagem = mensagemDoErro(() {
        Talhao(nome: "Chico1", hectares: -3, area: sede);
      });

      expect(
        mensagem,
        "Talhão inválido: -3.0 ha (área deve ser maior que zero)",
      );
    });

    test('nome vazio e recusado', () {
      expect(() => Talhao(nome: " ", hectares: 1, area: sede), recusaNome);
    });

    test('nome sem espacos nas pontas', () {
      expect(Talhao(nome: " Chico1 ", hectares: 1, area: sede).nome, "Chico1");
    });

    test('setter de hectares valida e mantem o valor antigo', () {
      var talhao = Talhao(nome: "Chico1", hectares: 2.8, area: sede);

      talhao.hectares = 3.1;
      expect(talhao.hectares, 3.1);

      expect(() => talhao.hectares = 0, recusaHectares);
      expect(talhao.hectares, 3.1);
    });

    test('setter de nome valida e mantem o valor antigo', () {
      var talhao = Talhao(nome: "Chico1", hectares: 2.8, area: sede);

      talhao.nome = " Chico2 ";
      expect(talhao.nome, "Chico2");

      expect(() => talhao.nome = "", recusaNome);
      expect(talhao.nome, "Chico2");
    });
  });
}
