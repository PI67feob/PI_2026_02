import 'package:caderno_fazenda/models/aplicador.dart';

/// Drone de pulverização. As aplicações ficam registradas no app do drone
/// (produto, dose, data e mapa de voo) e também na ficha de papel.
class Drone extends Aplicador {
  Drone({
    super.id,
    super.modelo,
    super.capacidadeMaximaL,
    super.capacidadeMaximaKg,
  });

  @override
  String get tipo => 'drone';

  @override
  String descreverCapacidade() {
    final nome = (modelo ?? id) != null ? 'Drone ${modelo ?? id}' : 'Drone';
    final temCapacidade =
        capacidadeMaximaL != null || capacidadeMaximaKg != null;
    return temCapacidade
        ? '$nome: até $capacidadeMaximaTexto por voo'
        : '$nome: capacidade não informada por voo';
  }

  @override
  String origemDoRegistro() => 'app do drone e ficha de papel';
}
