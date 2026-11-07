import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';
import 'package:caderno_fazenda/models/area.dart';
import 'package:test/test.dart';

void main() {
  var recusa = throwsA(isA<DadoInvalidoException>());

  test('Area guarda nome e id', () {
    var area = Area(nome: "Sede", id: 1);

    expect(area.nome, "Sede");
    expect(area.id, 1);
  });

  group('validacoes', () {
    test('nome sem espacos nas pontas', () {
      expect(Area(nome: "  Sede  ").nome, "Sede");
    });

    test('nome vazio ou so espacos e recusado', () {
      expect(() => Area(nome: ""), recusa);
      expect(() => Area(nome: "   "), recusa);
    });

    test('setter de nome aplica a mesma regra do construtor', () {
      var area = Area(nome: "Sede");

      area.nome = " Fundos ";
      expect(area.nome, "Fundos");

      expect(() => area.nome = "", recusa);
      expect(area.nome, "Fundos");
    });
  });
}
