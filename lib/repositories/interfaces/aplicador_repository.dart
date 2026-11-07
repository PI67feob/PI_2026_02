import 'package:caderno_fazenda/models/aplicador.dart';
import 'package:caderno_fazenda/repositories/interfaces/repository.dart';

/// Persistência dos aplicadores (tabela `aplicador`).
///
/// Quem implementa devolve sempre a subclasse certa de [Aplicador]. Na versão
/// MySQL, isso é feito lendo o texto da coluna `tipo` e chamando
/// `criarAplicador`.
abstract interface class AplicadorRepository implements Repository<Aplicador> {
  /// Lista os aplicadores de um tipo (`trator`, `drone` ou `bomba costal`),
  /// em ordem crescente de id.
  Future<List<Aplicador>> listarPorTipo(String tipo);
}
