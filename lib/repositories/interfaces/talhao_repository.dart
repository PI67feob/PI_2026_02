import 'package:caderno_fazenda/models/talhao.dart';
import 'package:caderno_fazenda/repositories/interfaces/repository.dart';

/// Persistência dos talhões (tabela `talhao`).
///
/// O nome do talhão é único apenas dentro da área: quem implementa não pode
/// aceitar dois talhões com o mesmo nome na mesma área.
abstract interface class TalhaoRepository implements Repository<Talhao> {
  /// Procura o talhão de [nome] dentro da área [areaId], sem diferenciar
  /// maiúsculas de minúsculas. Devolve null se não existir.
  Future<Talhao?> buscarPorAreaENome(int areaId, String nome);

  /// Lista os talhões da área [areaId], em ordem crescente de id.
  Future<List<Talhao>> listarPorArea(int areaId);
}
