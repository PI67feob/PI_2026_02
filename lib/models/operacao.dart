import 'package:caderno_fazenda/models/entidade.dart';
import 'package:caderno_fazenda/models/validacoes.dart';

/// Tipo de trabalho feito numa aplicação (ex.: Pulverizacao).
class Operacao extends Entidade {
  late String _descricao;

  /// Cria a operação. [descricao] é obrigatória; [id] fica nulo até o banco
  /// gerar um.
  Operacao({required String descricao, super.id}) {
    this.descricao = descricao;
  }

  /// Descrição da operação, sem espaços nas pontas.
  String get descricao => _descricao;

  set descricao(String valor) {
    _descricao = textoObrigatorio(valor, 'descrição da operação');
  }
}
