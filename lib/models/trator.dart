import 'package:caderno_fazenda/models/aplicador.dart';

/// Trator usado em operações agrícolas. Na fazenda é identificado por número e as
/// aplicações são anotadas na ficha de papel.
class Trator extends Aplicador {
  Trator({
    super.id,
    super.modelo,
    super.capacidadeMaximaL,
    super.capacidadeMaximaKg,
  });

  @override
  String get tipo => 'trator';

  @override
  String descreverCapacidade() {
    final nome = (modelo ?? id) != null ? 'Trator ${modelo ?? id}' : 'Trator';
    final temCapacidade =
        capacidadeMaximaL != null || capacidadeMaximaKg != null;
    return temCapacidade
        ? '$nome: compartimento de até $capacidadeMaximaTexto'
        : '$nome: compartimento com capacidade não informada';
  }

  @override
  String origemDoRegistro() => 'ficha de papel';
}
