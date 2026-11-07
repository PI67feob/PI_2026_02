import 'package:caderno_fazenda/models/area.dart';
import 'package:caderno_fazenda/repositories/interfaces/area_repository.dart';
import 'package:caderno_fazenda/repositories/mysql/ajuda_mysql.dart';
import 'package:caderno_fazenda/repositories/mysql/conexao_mysql.dart';

/// Guarda as áreas da propriedade na tabela `area` do MySQL.
///
/// Implementa a mesma interface da versão em memória, então os serviços não
/// percebem a troca. Todas as consultas usam parâmetros nomeados (`:nome`):
/// nenhum valor é colado no texto do SQL.
///
/// Tabela: `area (id_area, nome, descricao)`. A classe [Area] só tem o nome, e
/// a `descricao` (opcional no banco) fica como está.
class AreaRepositoryMysql implements AreaRepository {
  final ConexaoMysql _banco;

  /// Cria o repositório usando uma conexão já aberta.
  AreaRepositoryMysql(this._banco);

  static const _colunas = 'id_area, nome';

  @override
  Future<Area> salvar(Area area) {
    return _banco.usar('salvar área', (conexao) async {
      await gravarLinha(
        conexao,
        area,
        tabela: 'area',
        colunaId: 'id_area',
        nomeEntidade: 'área',
        valores: {'nome': area.nome},
      );
      return area;
    });
  }

  @override
  Future<Area?> buscarPorId(int id) {
    return _banco.usar('buscar área', (conexao) async {
      final resultado = await conexao.execute(
        'SELECT $_colunas FROM area WHERE id_area = :id',
        {'id': id},
      );
      final linha = resultado.rows.firstOrNull;
      return linha == null ? null : _paraArea(linha.assoc());
    });
  }

  @override
  Future<Area?> buscarPorNome(String nome) {
    return _banco.usar('buscar área por nome', (conexao) async {
      // A coluna usa utf8mb4_0900_ai_ci: a comparação já ignora maiúsculas e
      // acentos, igual à versão em memória.
      final resultado = await conexao.execute(
        'SELECT $_colunas FROM area WHERE nome = :nome '
        'ORDER BY id_area LIMIT 1',
        {'nome': nome.trim()},
      );
      final linha = resultado.rows.firstOrNull;
      return linha == null ? null : _paraArea(linha.assoc());
    });
  }

  @override
  Future<List<Area>> listarTodos() {
    return _banco.usar('listar áreas', (conexao) async {
      final resultado = await conexao.execute(
        'SELECT $_colunas FROM area ORDER BY id_area',
      );
      return [for (final linha in resultado.rows) _paraArea(linha.assoc())];
    });
  }

  @override
  Future<bool> remover(int id) {
    return _banco.usar('remover área', (conexao) async {
      final resultado = await conexao.execute(
        'DELETE FROM area WHERE id_area = :id',
        {'id': id},
      );
      return resultado.affectedRows.toInt() > 0;
    });
  }

  Area _paraArea(Map<String, dynamic> linha) {
    return Area(id: inteiro(linha['id_area']), nome: linha['nome'].toString());
  }
}
