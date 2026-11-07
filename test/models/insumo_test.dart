import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';
import 'package:caderno_fazenda/models/insumo.dart';
import 'package:test/test.dart';

void main() {
  var recusa = throwsA(isA<DadoInvalidoException>());

  test('Insumo guarda nome, id, marca e tipo', () {
    var insumo = Insumo(
      nome: "Orkestra SC",
      id: 13,
      marca: "BASF",
      tipo: "Fungicida",
    );

    expect(insumo.nome, "Orkestra SC");
    expect(insumo.id, 13);
    expect(insumo.marca, "BASF");
    expect(insumo.tipo, "Fungicida");
  });

  group('validacoes', () {
    test('nome e tipo sao obrigatorios', () {
      expect(() => Insumo(nome: "", tipo: "Fungicida"), recusa);
      expect(() => Insumo(nome: "Orkestra SC", tipo: " "), recusa);
    });

    test('textos sem espacos nas pontas', () {
      var insumo = Insumo(nome: " Orkestra SC ", tipo: " Fungicida ");

      expect(insumo.nome, "Orkestra SC");
      expect(insumo.tipo, "Fungicida");
    });

    test('marca e opcional e em branco vira nulo', () {
      expect(Insumo(nome: "Orkestra SC", tipo: "Fungicida").marca, isNull);
      expect(
        Insumo(nome: "Orkestra SC", tipo: "Fungicida", marca: "  ").marca,
        isNull,
      );
    });

    test('setters aplicam as mesmas regras do construtor', () {
      var insumo = Insumo(nome: "Orkestra SC", tipo: "Fungicida");

      insumo.marca = " BASF ";
      expect(insumo.marca, "BASF");

      expect(() => insumo.nome = "", recusa);
      expect(() => insumo.tipo = "", recusa);
      expect(insumo.nome, "Orkestra SC");
    });
  });
}
