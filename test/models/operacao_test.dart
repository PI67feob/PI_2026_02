import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';
import 'package:caderno_fazenda/models/operacao.dart';
import 'package:test/test.dart';

void main() {
  var recusa = throwsA(isA<DadoInvalidoException>());

  test('Operacao guarda id e descricao', () {
    var operacao = Operacao(id: 1, descricao: "Pulverizacao");

    expect(operacao.id, 1);
    expect(operacao.descricao, "Pulverizacao");
  });

  test('descricao sem espacos nas pontas', () {
    expect(Operacao(descricao: " Pulverizacao ").descricao, "Pulverizacao");
  });

  test('descricao vazia e recusada', () {
    var operacao = Operacao(descricao: "Pulverizacao");

    expect(() => Operacao(descricao: ""), recusa);
    expect(() => operacao.descricao = "  ", recusa);
    expect(operacao.descricao, "Pulverizacao");
  });
}
