import 'package:caderno_fazenda/models/area.dart';
import 'package:caderno_fazenda/repositories/interfaces/repository.dart';

/// Persistência das áreas da propriedade (tabela `area`).
abstract interface class AreaRepository implements Repository<Area> {
  /// Procura uma área pelo nome, sem diferenciar maiúsculas de minúsculas.
  Future<Area?> buscarPorNome(String nome);
}
