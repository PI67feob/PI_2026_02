import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';
import 'package:caderno_fazenda/models/area.dart';
import 'package:test/test.dart';

/// A [Entidade] é abstrata: o teste usa a [Area], que é a mais simples.
void main() {
  var recusa = throwsA(isA<DadoInvalidoException>());

  group('Entidade', () {
    test('fica sem id ate ser salva', () {
      expect(Area(nome: 'Sede').id, isNull);
    });

    test('definirId guarda o id gerado pelo banco', () {
      var area = Area(nome: 'Sede');

      area.definirId(7);

      expect(area.id, 7);
    });

    test('definirId com o mesmo id nao muda nada', () {
      var area = Area(nome: 'Sede', id: 7);

      area.definirId(7);

      expect(area.id, 7);
    });

    test('depois de definido, o id nao muda', () {
      var area = Area(nome: 'Sede', id: 7);

      expect(() => area.definirId(8), recusa);
      expect(area.id, 7);
    });

    test('id zero ou negativo e recusado', () {
      expect(() => Area(nome: 'Sede', id: 0), recusa);
      expect(() => Area(nome: 'Sede').definirId(-1), recusa);
    });

    test('mesmoRegistro: mesmo objeto ou mesmo id', () {
      var sede = Area(nome: 'Sede', id: 1);
      var mesmoId = Area(nome: 'Outro nome', id: 1);
      var outroId = Area(nome: 'Sede', id: 2);

      expect(sede.mesmoRegistro(sede), isTrue);
      expect(sede.mesmoRegistro(mesmoId), isTrue);
      expect(sede.mesmoRegistro(outroId), isFalse);
    });

    test('mesmoRegistro: duas entidades novas sao diferentes', () {
      var a = Area(nome: 'Sede');
      var b = Area(nome: 'Sede');

      expect(a.mesmoRegistro(a), isTrue);
      expect(a.mesmoRegistro(b), isFalse);
    });
  });
}
