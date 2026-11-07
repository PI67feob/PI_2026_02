import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';
import 'package:caderno_fazenda/models/aplicador_fabrica.dart';
import 'package:caderno_fazenda/models/bomba_costal.dart';
import 'package:caderno_fazenda/models/drone.dart';
import 'package:caderno_fazenda/models/trator.dart';
import 'package:test/test.dart';

void main() {
  group('criarAplicador', () {
    test('cria a subclasse certa para cada tipo do banco', () {
      expect(criarAplicador('trator'), isA<Trator>());
      expect(criarAplicador('drone'), isA<Drone>());
      expect(criarAplicador('bomba costal'), isA<BombaCostal>());
    });

    test('ignora maiusculas e espacos nas pontas', () {
      expect(criarAplicador('  DRONE '), isA<Drone>());
      expect(criarAplicador('Bomba Costal'), isA<BombaCostal>());
    });

    test('repassa id, modelo e capacidades', () {
      var aplicador = criarAplicador(
        'drone',
        id: 4,
        modelo: 'DJI',
        capacidadeMaximaL: 70,
        capacidadeMaximaKg: 60,
      );

      expect(aplicador.id, 4);
      expect(aplicador.modelo, 'DJI');
      expect(aplicador.capacidadeMaximaL, 70);
      expect(aplicador.capacidadeMaximaKg, 60);
      expect(aplicador.tipo, 'drone');
    });

    test('a subclasse devolvida muda o comportamento (polimorfismo)', () {
      var origem = criarAplicador('trator').origemDoRegistro();
      var origemDrone = criarAplicador('drone').origemDoRegistro();

      expect(origem, 'ficha de papel');
      expect(origemDrone, 'app do drone e ficha de papel');
    });

    test('tipo desconhecido lanca DadoInvalidoException', () {
      for (var tipo in ['trator de esteira', '']) {
        expect(
          () => criarAplicador(tipo),
          throwsA(isA<DadoInvalidoException>()),
        );
      }
    });
  });
}
