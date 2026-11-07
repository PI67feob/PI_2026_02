import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';
import 'package:caderno_fazenda/models/aplicador.dart';
import 'package:caderno_fazenda/models/bomba_costal.dart';
import 'package:caderno_fazenda/models/drone.dart';
import 'package:caderno_fazenda/models/trator.dart';
import 'package:test/test.dart';

void main() {
  // Trator sem capacidade nos dados principais: reflete a realidade da fazenda,
  // onde o trator é identificado por número sem capacidade registrada nos documentos.
  var trator = Trator(id: 1);
  var drone = Drone(
    id: 2,
    modelo: "DJI",
    capacidadeMaximaL: 70,
    capacidadeMaximaKg: 70,
  );
  var costal = BombaCostal(
    id: 3,
    modelo: "Jacto",
    capacidadeMaximaL: 20,
    capacidadeMaximaKg: 20,
  );

  group('polimorfismo', () {
    List<Aplicador> aplicadores = [trator, drone, costal];

    test('descreverCapacidade muda conforme o tipo', () {
      var descricoes = [
        for (var aplicador in aplicadores) aplicador.descreverCapacidade(),
      ];

      expect(descricoes, [
        'Trator 1: compartimento com capacidade não informada',
        'Drone DJI: até 70 L / 70 kg por voo',
        'Bomba costal Jacto: reservatório de até 20 L / 20 kg nas costas do operador',
      ]);
      expect(descricoes.toSet().length, 3);
    });

    test('origemDoRegistro muda conforme o tipo', () {
      var origens = [
        for (var aplicador in aplicadores) aplicador.origemDoRegistro(),
      ];

      expect(origens, [
        'ficha de papel',
        'app do drone e ficha de papel',
        'ficha de papel',
      ]);
    });

    test('tipo vem da subclasse e bate com os valores do banco', () {
      var tipos = [for (var aplicador in aplicadores) aplicador.tipo];

      expect(tipos, ['trator', 'drone', 'bomba costal']);
    });
  });

  group('Aplicador', () {
    test('subclasses sao Aplicador', () {
      expect(trator, isA<Aplicador>());
      expect(drone, isA<Aplicador>());
      expect(costal, isA<Aplicador>());
    });

    test('guarda id, modelo e capacidades maximas', () {
      expect(drone.id, 2);
      expect(drone.modelo, "DJI");
      expect(drone.capacidadeMaximaL, 70);
      expect(drone.capacidadeMaximaKg, 70);
    });

    test('capacidadeMaximaTexto mostra so o que foi informado', () {
      expect(Drone(capacidadeMaximaL: 2.5).capacidadeMaximaTexto, '2.5 L');
      expect(Drone(capacidadeMaximaKg: 10).capacidadeMaximaTexto, '10 kg');
      expect(Trator(id: 9).capacidadeMaximaTexto, 'não informada');
    });

    test('sem modelo, a descricao usa o id (exemplo ficticio)', () {
      // Exemplo declaradamente fictício: a capacidade do trator não consta dos documentos.
      expect(
        Trator(id: 4, capacidadeMaximaL: 450).descreverCapacidade(),
        'Trator 4: compartimento de até 450 L',
      );
    });

    test('sem capacidade, a descricao informa sem o "ate"', () {
      expect(
        Trator(id: 1).descreverCapacidade(),
        'Trator 1: compartimento com capacidade não informada',
      );
      expect(
        Drone(modelo: 'DJI').descreverCapacidade(),
        'Drone DJI: capacidade não informada por voo',
      );
      expect(
        BombaCostal(modelo: 'Jacto').descreverCapacidade(),
        'Bomba costal Jacto: reservatório com capacidade não informada nas costas do operador',
      );
    });

    test('sem modelo e sem id, nao aparece "null"', () {
      // Exemplo declaradamente fictício para testar capacidade sem identificador
      expect(
        Trator(capacidadeMaximaL: 600).descreverCapacidade(),
        'Trator: compartimento de até 600 L',
      );
      expect(
        Drone(capacidadeMaximaL: 70).descreverCapacidade(),
        'Drone: até 70 L por voo',
      );
      expect(
        BombaCostal(capacidadeMaximaL: 20).descreverCapacidade(),
        'Bomba costal: reservatório de até 20 L nas costas do operador',
      );
    });

    test('sem identificacao e sem capacidade, nao exibe null nem "ate"', () {
      expect(
        Trator().descreverCapacidade(),
        'Trator: compartimento com capacidade não informada',
      );
      expect(
        Drone().descreverCapacidade(),
        'Drone: capacidade não informada por voo',
      );
      expect(
        BombaCostal().descreverCapacidade(),
        'Bomba costal: reservatório com capacidade não informada nas costas do operador',
      );
    });
  });

  group('validacoes', () {
    var recusa = throwsA(isA<DadoInvalidoException>());

    test('capacidade zero, negativa ou invalida e recusada', () {
      for (var valor in [0.0, -1.0, double.nan, double.infinity]) {
        expect(() => Drone(capacidadeMaximaL: valor), recusa);
        expect(() => Trator(capacidadeMaximaKg: valor), recusa);
      }
    });

    test('capacidade ausente e permitida (a do trator nao foi levantada)', () {
      expect(Trator().capacidadeMaximaL, isNull);
      expect(Trator().capacidadeMaximaKg, isNull);
    });

    test('modelo em branco vira nulo e o texto e aparado', () {
      expect(Drone(modelo: "   ").modelo, isNull);
      expect(Drone(modelo: " DJI ").modelo, "DJI");
    });

    test('setters validam e aceitam nulo', () {
      var aplicador = Drone(capacidadeMaximaL: 70);

      aplicador.capacidadeMaximaL = 50;
      expect(aplicador.capacidadeMaximaL, 50);

      expect(() => aplicador.capacidadeMaximaL = -5, recusa);
      expect(aplicador.capacidadeMaximaL, 50);

      aplicador.capacidadeMaximaL = null;
      expect(aplicador.capacidadeMaximaL, isNull);
    });

    test('id zero ou negativo e recusado', () {
      expect(() => Trator(id: 0), recusa);
      expect(() => BombaCostal(id: -2), recusa);
    });
  });
}
