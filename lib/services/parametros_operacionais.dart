import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';
import 'package:caderno_fazenda/logica/alertas_operacionais.dart';
import 'package:caderno_fazenda/logica/calculo_desperdicio.dart';

/// Valores das regras da fazenda que não podem ficar escritos fixos no código.
///
/// As funções de `lib/logica` recebem esses valores por parâmetro; o serviço
/// guarda todos aqui, num lugar só, para o agrônomo ou a fazenda poderem mudar
/// um número sem mexer nas regras.
///
/// A tolerância de sobredose é obrigatória e não tem valor padrão: quem define
/// o excesso aceitável é o agrônomo. O limite da chuva (3 horas) e o fator de
/// compra (0,95) vêm da fazenda e têm valor padrão.
class ParametrosOperacionais {
  /// Excesso aceito acima da dose prevista, em %. Zero significa nenhum.
  final double toleranciaSobredosePercentual;

  /// Horas entre a aplicação e a chuva abaixo das quais se reaplica.
  final double limiteChuvaHoras;

  /// Fator da quantidade a comprar: 0,95 significa comprar 5% a menos.
  final double fatorCompra;

  /// Cria os parâmetros. Lança `DadoInvalidoException` se a tolerância for
  /// negativa ou se o limite da chuva ou o fator de compra não forem maiores
  /// que zero.
  ParametrosOperacionais({
    required this.toleranciaSobredosePercentual,
    this.limiteChuvaHoras = limiteChuvaPadraoHoras,
    this.fatorCompra = fatorCompraPadrao,
  }) {
    final tolerancia = toleranciaSobredosePercentual;
    if (!tolerancia.isFinite || tolerancia < 0) {
      throw DadoInvalidoException('tolerância', 'não pode ser negativa');
    }
    _exigirPositivo(limiteChuvaHoras, 'limite da chuva (horas)');
    _exigirPositivo(fatorCompra, 'fator de compra');
  }

  static void _exigirPositivo(double valor, String campo) {
    if (!valor.isFinite || valor <= 0) {
      throw DadoInvalidoException(campo, 'deve ser maior que zero');
    }
  }
}
