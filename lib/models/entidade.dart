import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';

/// Base das classes que viram uma linha própria no banco de dados.
///
/// Guarda o identificador e as regras dele em um lugar só, para as entidades
/// (`Area`, `Talhao`, `Insumo`, `Operacao`, `Aplicador` e `Aplicacao`) não
/// repetirem o mesmo código.
///
/// O id é gerado pelo banco (AUTO_INCREMENT), então fica nulo até a entidade
/// ser salva. Depois de definido, não muda mais.
abstract class Entidade {
  int? _id;

  /// Cria a entidade. O [id] pode ficar nulo até o banco gerar um.
  ///
  /// Lança [DadoInvalidoException] se o [id] for zero ou negativo.
  Entidade({int? id}) : _id = _validarId(id);

  /// Identificador da linha no banco; nulo enquanto a entidade não foi salva.
  int? get id => _id;

  /// Guarda o id gerado ao salvar. Quem chama é o repositório.
  ///
  /// Lança [DadoInvalidoException] se o [novoId] for zero ou negativo, ou se a
  /// entidade já tiver outro id.
  void definirId(int novoId) {
    final atual = _id;
    if (atual != null && atual != novoId) {
      throw DadoInvalidoException('id', 'já definido como $atual');
    }
    _id = _validarId(novoId);
  }

  /// Diz se [outra] é o mesmo registro: o mesmo objeto, ou o mesmo id quando
  /// ele já foi definido. Duas entidades novas (sem id) só são iguais se forem
  /// o mesmo objeto.
  bool mesmoRegistro(Entidade outra) {
    final meuId = _id;
    return identical(this, outra) || (meuId != null && meuId == outra.id);
  }

  static int? _validarId(int? id) {
    if (id != null && id <= 0) {
      throw DadoInvalidoException('id', 'deve ser maior que zero');
    }
    return id;
  }
}
