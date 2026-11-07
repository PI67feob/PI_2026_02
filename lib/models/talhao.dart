import 'package:caderno_fazenda/exceptions/talhao_invalido_exception.dart';
import 'package:caderno_fazenda/models/area.dart';
import 'package:caderno_fazenda/models/entidade.dart';
import 'package:caderno_fazenda/models/validacoes.dart';

/// Pedaço de terra de uma [Area], medido em hectares.
///
/// O nome só precisa ser único dentro da própria área (essa regra fica no
/// serviço e no banco). A área do talhão não muda depois de criado; nome e
/// hectares podem ser corrigidos, sempre passando pela validação.
class Talhao extends Entidade {
  /// Área da propriedade a que o talhão pertence.
  final Area area;

  late String _nome;
  late double _hectares;

  /// Cria o talhão.
  ///
  /// Lança [TalhaoInvalidoException] se [hectares] não for maior que zero e
  /// `DadoInvalidoException` se [nome] estiver vazio.
  Talhao({
    required String nome,
    required double hectares,
    required this.area,
    super.id,
  }) {
    this.nome = nome;
    this.hectares = hectares;
  }

  /// Nome do talhão, sem espaços nas pontas.
  String get nome => _nome;

  set nome(String valor) {
    _nome = textoObrigatorio(valor, 'nome do talhão');
  }

  /// Tamanho do talhão em hectares; sempre maior que zero.
  double get hectares => _hectares;

  set hectares(double valor) {
    if (!valor.isFinite || valor <= 0) {
      const motivo = 'área deve ser maior que zero';
      throw TalhaoInvalidoException('$valor ha', motivo: motivo);
    }
    _hectares = valor;
  }

  // renomeado: o metodo devolve os dados do talhao, nao a area
  String obterDados() {
    return "nome:$nome - id:$id - hectares:$hectares - area:${area.nome}";
  }
}
