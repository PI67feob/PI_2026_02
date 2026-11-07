import 'package:caderno_fazenda/models/insumo.dart';
import 'package:caderno_fazenda/repositories/interfaces/repository.dart';

/// Persistência dos insumos (tabela `insumo`).
abstract interface class InsumoRepository implements Repository<Insumo> {
  /// Lista os insumos de um tipo (ex.: Herbicida), sem diferenciar maiúsculas
  /// de minúsculas, em ordem crescente de id.
  Future<List<Insumo>> listarPorTipo(String tipo);
}
