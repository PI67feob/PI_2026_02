import 'package:caderno_fazenda/models/entidade.dart';
import 'package:caderno_fazenda/models/validacoes.dart';

/// Equipamento usado para aplicar calda nos talhões.
///
/// A fazenda tem três tipos de aplicador: `Trator`, `Drone` e `BombaCostal`.
/// Cada subclasse define o próprio [tipo] (igual ao valor gravado no banco) e
/// implementa [descreverCapacidade] e [origemDoRegistro] do seu jeito.
///
/// A capacidade é um limite máximo POR VIAGEM, não um volume fixo: o tanque
/// nem sempre é cheio, e uma aplicação maior que ele é feita em mais de uma
/// viagem. O cálculo das viagens fica na frente de Lógica
/// (`viagensNecessarias`) e é aplicado pelo serviço; aqui o aplicador só expõe
/// a sua capacidade máxima e garante que, quando informada, ela é maior que
/// zero.
/// A capacidade pode ficar nula: a do trator ainda não foi levantada.
abstract class Aplicador extends Entidade {
  String? _modelo;
  double? _capacidadeMaximaL;
  double? _capacidadeMaximaKg;

  Aplicador({
    super.id,
    String? modelo,
    double? capacidadeMaximaL,
    double? capacidadeMaximaKg,
  }) {
    this.modelo = modelo;
    this.capacidadeMaximaL = capacidadeMaximaL;
    this.capacidadeMaximaKg = capacidadeMaximaKg;
  }

  /// Modelo ou número do aplicador (ex.: `DJI`); nulo se não foi informado.
  String? get modelo => _modelo;

  set modelo(String? valor) {
    _modelo = textoOpcional(valor);
  }

  /// Capacidade máxima em litros; nula quando ainda não foi levantada.
  double? get capacidadeMaximaL => _capacidadeMaximaL;

  set capacidadeMaximaL(double? valor) {
    _capacidadeMaximaL = positivoOuNulo(valor, 'capacidade máxima (L)');
  }

  /// Capacidade máxima em quilos; nula quando ainda não foi levantada.
  double? get capacidadeMaximaKg => _capacidadeMaximaKg;

  set capacidadeMaximaKg(double? valor) {
    _capacidadeMaximaKg = positivoOuNulo(valor, 'capacidade máxima (kg)');
  }

  /// Tipo do aplicador, com o mesmo texto usado no banco:
  /// `trator`, `drone` ou `bomba costal`.
  String get tipo;

  /// Descreve a capacidade máxima do aplicador do jeito do seu tipo.
  String descreverCapacidade();

  /// Onde a fazenda registra as aplicações feitas com este tipo de aplicador.
  String origemDoRegistro();

  /// Capacidade máxima em texto, ex.: `70 L / 70 kg`.
  /// Mostra `não informada` quando nenhuma capacidade foi cadastrada.
  String get capacidadeMaximaTexto {
    var partes = [
      if (capacidadeMaximaL != null) '${_numero(capacidadeMaximaL!)} L',
      if (capacidadeMaximaKg != null) '${_numero(capacidadeMaximaKg!)} kg',
    ];
    return partes.isEmpty ? 'não informada' : partes.join(' / ');
  }

  /// Mostra `70` em vez de `70.0` quando o valor não tem casas decimais.
  static String _numero(double valor) => valor == valor.truncateToDouble()
      ? valor.toInt().toString()
      : valor.toString();
}
