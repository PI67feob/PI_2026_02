import 'package:caderno_fazenda/models/entidade.dart';
import 'package:caderno_fazenda/models/validacoes.dart';

/// Parte da propriedade que agrupa talhões (ex.: a Sede).
///
/// O nome é obrigatório e nunca fica vazio: o setter de [nome] aplica a mesma
/// regra do construtor, então a área não consegue ficar inválida depois de
/// criada.
class Area extends Entidade {
  late String _nome;

  /// Cria a área. [nome] é obrigatório; [id] fica nulo até o banco gerar um.
  Area({required String nome, super.id}) {
    this.nome = nome;
  }

  /// Nome da área, sem espaços nas pontas.
  String get nome => _nome;

  set nome(String valor) {
    _nome = textoObrigatorio(valor, 'nome da área');
  }
}
