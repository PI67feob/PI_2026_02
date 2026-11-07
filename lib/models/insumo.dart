import 'package:caderno_fazenda/models/entidade.dart';
import 'package:caderno_fazenda/models/validacoes.dart';

/// Produto usado nas aplicações (defensivo, fertilizante, biestimulante...).
///
/// Tem nome, marca e tipo, e não tem unidade de medida: a unidade da dose fica
/// em `AplicacaoInsumo`. O [tipo] é um texto livre porque a decisão sobre
/// produtos de mais de um tipo (como o Spirit) ainda está em aberto.
class Insumo extends Entidade {
  late String _nome;
  late String _tipo;
  String? _marca;

  /// Cria o insumo. [nome] e [tipo] são obrigatórios; [marca] só é informada
  /// quando se sabe qual é.
  Insumo({
    required String nome,
    required String tipo,
    String? marca,
    super.id,
  }) {
    this.nome = nome;
    this.tipo = tipo;
    this.marca = marca;
  }

  /// Nome do produto, sem espaços nas pontas.
  String get nome => _nome;

  set nome(String valor) {
    _nome = textoObrigatorio(valor, 'nome do insumo');
  }

  /// Tipo do produto (ex.: Fungicida, Herbicida, Fertilizante).
  String get tipo => _tipo;

  set tipo(String valor) {
    _tipo = textoObrigatorio(valor, 'tipo do insumo');
  }

  /// Marca do produto; nulo quando não se sabe qual é.
  String? get marca => _marca;

  set marca(String? valor) {
    _marca = textoOpcional(valor);
  }
}
