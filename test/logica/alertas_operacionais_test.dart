import 'package:caderno_fazenda/logica/alertas_operacionais.dart';
import 'package:test/test.dart';

void main() {
  group('avaliarChuva', () {
    test('normal: chuva em 1 hora manda reaplicar', () {
      expect(avaliarChuva(1), DecisaoChuva.reaplicar);
    });

    test('normal: chuva em 5 horas nao manda reaplicar', () {
      expect(avaliarChuva(5), DecisaoChuva.naoReaplicar);
    });

    test('limite: 2h59 reaplica', () {
      expect(avaliarChuva(2 + 59 / 60), DecisaoChuva.reaplicar);
    });

    test('limite: exatamente 3h nao reaplica (PENDENTE com a fazenda)', () {
      expect(avaliarChuva(3), DecisaoChuva.naoReaplicar);
    });

    test('limite: exatamente 3h reaplica se a fazenda decidir assim', () {
      expect(avaliarChuva(3, reaplicarNoLimite: true), DecisaoChuva.reaplicar);
    });

    test('limite: 3h01 nao reaplica', () {
      expect(avaliarChuva(3 + 1 / 60), DecisaoChuva.naoReaplicar);
    });

    test('limite: chuva logo depois da aplicacao (0 h) reaplica', () {
      expect(avaliarChuva(0), DecisaoChuva.reaplicar);
    });

    test('o limite e parametro: com 6 h, chuva em 5 h reaplica', () {
      expect(avaliarChuva(5, limiteHoras: 6), DecisaoChuva.reaplicar);
      expect(avaliarChuva(6.5, limiteHoras: 6), DecisaoChuva.naoReaplicar);
    });

    test('invalido: horas negativas', () {
      expect(avaliarChuva(-1), DecisaoChuva.entradaInvalida);
    });

    test('invalido: horas NaN ou infinitas', () {
      expect(avaliarChuva(double.nan), DecisaoChuva.entradaInvalida);
      expect(avaliarChuva(double.infinity), DecisaoChuva.entradaInvalida);
    });

    test('invalido: limite zero ou negativo', () {
      expect(avaliarChuva(2, limiteHoras: 0), DecisaoChuva.entradaInvalida);
      expect(avaliarChuva(2, limiteHoras: -3), DecisaoChuva.entradaInvalida);
    });

    test('invalido: nao lanca excecao, so devolve o resultado', () {
      expect(() => avaliarChuva(-5, limiteHoras: -5), returnsNormally);
    });
  });

  group('avaliarCapacidade', () {
    var invalida = ResultadoCapacidade.entradaInvalida;

    test('normal: volume menor que a capacidade cabe', () {
      var resultado = avaliarCapacidade(50, 70);

      expect(resultado, ResultadoCapacidade.dentroDaCapacidade);
    });

    test('normal: volume maior que a capacidade excede', () {
      expect(avaliarCapacidade(132, 70), ResultadoCapacidade.excedeu);
    });

    test('limite: volume igual a capacidade ainda cabe', () {
      var resultado = avaliarCapacidade(70, 70);

      expect(resultado, ResultadoCapacidade.dentroDaCapacidade);
    });

    test('limite: um pouco acima da capacidade excede', () {
      expect(avaliarCapacidade(70.01, 70), ResultadoCapacidade.excedeu);
    });

    test('limite: volume zero cabe', () {
      var resultado = avaliarCapacidade(0, 70);

      expect(resultado, ResultadoCapacidade.dentroDaCapacidade);
    });

    test('invalido: capacidade zero ou negativa', () {
      expect(avaliarCapacidade(10, 0), invalida);
      expect(avaliarCapacidade(10, -5), invalida);
    });

    test('invalido: volume negativo', () {
      expect(avaliarCapacidade(-1, 70), invalida);
    });

    test('invalido: NaN ou infinito em qualquer argumento', () {
      expect(avaliarCapacidade(double.nan, 70), invalida);
      expect(avaliarCapacidade(10, double.nan), invalida);
      expect(avaliarCapacidade(double.infinity, 70), invalida);
      expect(avaliarCapacidade(10, double.infinity), invalida);
    });

    test('invalido: nao lanca excecao, so devolve o resultado', () {
      expect(() => avaliarCapacidade(-1, 0), returnsNormally);
    });
  });

  group('avaliarSobredose', () {
    var invalida = StatusSobredose.entradaInvalida;

    test('normal: dose abaixo do previsto e ok', () {
      var status = avaliarSobredose(10, 8, toleranciaPercentual: 10);

      expect(status, StatusSobredose.ok);
    });

    test('normal: excesso dentro da tolerancia pede atencao', () {
      var status = avaliarSobredose(10, 10.5, toleranciaPercentual: 10);

      expect(status, StatusSobredose.atencao);
    });

    test('normal: excesso acima da tolerancia e critico', () {
      var status = avaliarSobredose(10, 12, toleranciaPercentual: 10);

      expect(status, StatusSobredose.critico);
    });

    test('limite: dose igual ao previsto e ok', () {
      var status = avaliarSobredose(10, 10, toleranciaPercentual: 10);

      expect(status, StatusSobredose.ok);
    });

    test('limite: excesso igual a tolerancia ainda e atencao', () {
      var status = avaliarSobredose(10, 11, toleranciaPercentual: 10);

      expect(status, StatusSobredose.atencao);
    });

    test('limite: excesso logo acima da tolerancia e critico', () {
      var status = avaliarSobredose(10, 11.01, toleranciaPercentual: 10);

      expect(status, StatusSobredose.critico);
    });

    test('limite: sem tolerancia, qualquer excesso e critico', () {
      var excesso = avaliarSobredose(10, 10.01, toleranciaPercentual: 0);
      var exato = avaliarSobredose(10, 10, toleranciaPercentual: 0);

      expect(excesso, StatusSobredose.critico);
      expect(exato, StatusSobredose.ok);
    });

    test('a tolerancia e parametro: a mesma dose muda de status', () {
      var rigoroso = avaliarSobredose(10, 12, toleranciaPercentual: 10);
      var folgado = avaliarSobredose(10, 12, toleranciaPercentual: 25);

      expect(rigoroso, StatusSobredose.critico);
      expect(folgado, StatusSobredose.atencao);
    });

    test('invalido: dose prevista zero ou negativa', () {
      expect(avaliarSobredose(0, 5, toleranciaPercentual: 10), invalida);
      expect(avaliarSobredose(-1, 5, toleranciaPercentual: 10), invalida);
    });

    test('invalido: dose realizada negativa', () {
      expect(avaliarSobredose(10, -1, toleranciaPercentual: 10), invalida);
    });

    test('invalido: tolerancia negativa', () {
      expect(avaliarSobredose(10, 12, toleranciaPercentual: -1), invalida);
    });

    test('invalido: NaN ou infinito em qualquer argumento', () {
      var nan = double.nan;
      var infinito = double.infinity;

      expect(avaliarSobredose(nan, 5, toleranciaPercentual: 10), invalida);
      expect(avaliarSobredose(10, nan, toleranciaPercentual: 10), invalida);
      expect(avaliarSobredose(10, 12, toleranciaPercentual: nan), invalida);
      expect(
        avaliarSobredose(10, infinito, toleranciaPercentual: 10),
        invalida,
      );
    });

    test('invalido: nao lanca excecao, so devolve o resultado', () {
      expect(
        () => avaliarSobredose(0, -1, toleranciaPercentual: -1),
        returnsNormally,
      );
    });
  });
}
