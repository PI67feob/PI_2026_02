import 'package:caderno_fazenda/models/operacao.dart';
import 'package:caderno_fazenda/repositories/interfaces/repository.dart';

/// Persistência das operações (tabela `operacao`).
abstract interface class OperacaoRepository implements Repository<Operacao> {
  /// Procura uma operação pela descrição, sem diferenciar maiúsculas de
  /// minúsculas. Devolve null se não existir.
  Future<Operacao?> buscarPorDescricao(String descricao);
}
