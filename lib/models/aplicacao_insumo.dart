import 'package:caderno_fazenda/exceptions/dose_invalida_exception.dart';
import 'package:caderno_fazenda/models/insumo.dart';
import 'package:caderno_fazenda/models/unidade_dose.dart';

/// Um insumo usado numa aplicação, com a dose prevista e a dose realizada.
///
/// É a classe de associação entre `Aplicacao` e [Insumo] (relação N:N): uma
/// aplicação mistura vários insumos, e cada um tem a sua dose. As doses já
/// estão na base do banco: L/ha para produto líquido e kg/ha para sólido.
///
/// A dose realizada pode ficar vazia até a aplicação ser feita, e entra depois
/// por [registrarDoseRealizada].
class AplicacaoInsumo {
  /// Insumo aplicado.
  final Insumo insumo;

  /// Unidade das duas doses (`L/ha` ou `kg/ha`).
  final UnidadeDose unidade;

  /// Dose que o cálculo indicava; sempre maior que zero.
  final double dosePrevista;

  double? _doseRealizada;

  /// Cria o item. Lança [DoseInvalidaException] se [dosePrevista] não for
  /// maior que zero ou se [doseRealizada] for negativa.
  AplicacaoInsumo({
    required this.insumo,
    required this.unidade,
    required this.dosePrevista,
    double? doseRealizada,
  }) {
    if (!dosePrevista.isFinite || dosePrevista <= 0) {
      throw DoseInvalidaException(dosePrevista, unidade.texto);
    }
    if (doseRealizada != null) {
      registrarDoseRealizada(doseRealizada);
    }
  }

  /// Dose realmente aplicada; nula enquanto não foi informada.
  double? get doseRealizada => _doseRealizada;

  /// Guarda a dose realmente aplicada.
  ///
  /// Lança [DoseInvalidaException] se [dose] for negativa, infinita ou NaN.
  void registrarDoseRealizada(double dose) {
    if (!dose.isFinite || dose < 0) {
      throw DoseInvalidaException(dose, unidade.texto);
    }
    _doseRealizada = dose;
  }
}
