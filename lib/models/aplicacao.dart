import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';
import 'package:caderno_fazenda/models/aplicacao_insumo.dart';
import 'package:caderno_fazenda/models/aplicador.dart';
import 'package:caderno_fazenda/models/entidade.dart';
import 'package:caderno_fazenda/models/motivo_reaplicacao.dart';
import 'package:caderno_fazenda/models/operacao.dart';
import 'package:caderno_fazenda/models/talhao.dart';
import 'package:caderno_fazenda/models/validacoes.dart';

/// Uma aplicação feita na fazenda: o que foi aplicado, onde, com o quê, quando.
///
/// É a classe central do domínio e é feita por composição: uma [Operacao], um
/// [Aplicador], uma lista de [Talhao] (relação N:N, a ficha de papel chega a
/// somar dois talhões no mesmo lançamento) e uma lista de [AplicacaoInsumo]
/// (N:N com os insumos, porque a calda mistura várias marcas).
///
/// Regras que a própria classe garante: a data fica sem horário (no banco é
/// DATE), há ao menos um talhão e um insumo, e nenhum talhão ou insumo se
/// repete. O volume de calda não é guardado: ele é calculado pelo serviço a
/// partir da área e da taxa de aplicação.
///
/// Guarda também o que pode obrigar a refazer o serviço: as horas entre o fim
/// da aplicação e a chuva e o imprevisto que obriga a reaplicar (chuva, sol,
/// vento...). O aviso de reaplicar é calculado com o limite de chuva em vigor.
/// O motivo fica gravado e é o que o BI agrupa.
class Aplicacao extends Entidade {
  /// Tipo de trabalho feito (ex.: pulverização).
  final Operacao operacao;

  /// Equipamento usado na aplicação.
  final Aplicador aplicador;

  final List<Talhao> _talhoes = [];
  final List<AplicacaoInsumo> _insumos = [];
  late DateTime _data;
  String? _observacao;
  double? _horasAteChuva;

  /// Cria a aplicação. Lança `DadoInvalidoException` se faltar talhão ou
  /// insumo, ou se algum deles estiver repetido.
  Aplicacao({
    required DateTime data,
    required this.operacao,
    required this.aplicador,
    required List<Talhao> talhoes,
    required List<AplicacaoInsumo> insumos,
    String? observacao,
    double? horasAteChuva,
    this.motivoReaplicacao,
    super.id,
  }) {
    this.data = data;
    this.observacao = observacao;
    this.horasAteChuva = horasAteChuva;
    for (final talhao in talhoes) {
      adicionarTalhao(talhao);
    }
    for (final insumo in insumos) {
      adicionarInsumo(insumo);
    }
    if (_talhoes.isEmpty) {
      throw DadoInvalidoException('talhões', 'informe ao menos um talhão');
    }
    if (_insumos.isEmpty) {
      throw DadoInvalidoException('insumos', 'informe ao menos um insumo');
    }
  }

  /// Dia da aplicação, sem horário.
  DateTime get data => _data;

  set data(DateTime valor) {
    _data = DateTime(valor.year, valor.month, valor.day);
  }

  /// Observação livre; nula quando não há nada a anotar.
  String? get observacao => _observacao;

  set observacao(String? valor) {
    _observacao = textoOpcional(valor);
  }

  /// Horas entre o fim da aplicação e a chuva; nulo quando não choveu ou não
  /// se sabe.
  double? get horasAteChuva => _horasAteChuva;

  /// Lança `DadoInvalidoException` se for negativo ou não for um número.
  set horasAteChuva(double? valor) {
    if (valor != null && !valor.isFinite) {
      throw DadoInvalidoException('chuva (horas)', 'precisa ser um número');
    }
    if (valor != null && valor < 0) {
      throw DadoInvalidoException('chuva (horas)', 'não pode ser negativa');
    }
    _horasAteChuva = valor;
  }

  /// Imprevisto que obriga a reaplicar; nulo quando nada pede para refazer a
  /// aplicação. É a categoria que o BI agrupa no banco.
  MotivoReaplicacao? motivoReaplicacao;

  /// Talhões da aplicação (cópia que não pode ser alterada de fora).
  List<Talhao> get talhoes => List.unmodifiable(_talhoes);

  /// Insumos da aplicação, cada um com a sua dose (cópia somente leitura).
  List<AplicacaoInsumo> get insumos => List.unmodifiable(_insumos);

  /// Soma dos hectares de todos os talhões da aplicação.
  double get areaTotalHa {
    var total = 0.0;
    for (final talhao in _talhoes) {
      total += talhao.hectares;
    }
    return total;
  }

  /// Inclui um talhão. Lança `DadoInvalidoException` se ele já estiver na
  /// aplicação.
  void adicionarTalhao(Talhao talhao) {
    if (_talhoes.any(talhao.mesmoRegistro)) {
      throw DadoInvalidoException('talhões', '${talhao.nome} repetido');
    }
    _talhoes.add(talhao);
  }

  /// Inclui um insumo com a sua dose. Lança `DadoInvalidoException` se o
  /// insumo já estiver na aplicação.
  void adicionarInsumo(AplicacaoInsumo item) {
    final repetido = _insumos.any((x) => x.insumo.mesmoRegistro(item.insumo));
    if (repetido) {
      throw DadoInvalidoException('insumos', '${item.insumo.nome} repetido');
    }
    _insumos.add(item);
  }
}
