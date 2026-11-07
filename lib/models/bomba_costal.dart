import 'package:caderno_fazenda/models/aplicador.dart';

/// Bomba costal, carregada nas costas do operador. As aplicações são anotadas
/// na ficha de papel.
class BombaCostal extends Aplicador {
  BombaCostal({
    super.id,
    super.modelo,
    super.capacidadeMaximaL,
    super.capacidadeMaximaKg,
  });

  @override
  String get tipo => 'bomba costal';

  @override
  String descreverCapacidade() {
    final nome = (modelo ?? id) != null
        ? 'Bomba costal ${modelo ?? id}'
        : 'Bomba costal';
    final temCapacidade =
        capacidadeMaximaL != null || capacidadeMaximaKg != null;
    return temCapacidade
        ? '$nome: reservatório de até $capacidadeMaximaTexto nas costas do operador'
        : '$nome: reservatório com capacidade não informada nas costas do operador';
  }

  @override
  String origemDoRegistro() => 'ficha de papel';
}
