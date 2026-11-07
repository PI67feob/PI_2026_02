import 'package:caderno_fazenda/models/insumo.dart';
import 'package:caderno_fazenda/repositories/interfaces/insumo_repository.dart';
import 'package:caderno_fazenda/repositories/mysql/ajuda_mysql.dart';
import 'package:caderno_fazenda/repositories/mysql/conexao_mysql.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';

/// Guarda os insumos na tabela `insumo` do MySQL.
///
/// Tabela: `insumo (id_insumo, nome, marca, tipo)`. A unidade de medida não
/// fica aqui: ela mora em `item_compra` e em `aplicacao_insumo`.
///
/// Esta tabela tem triggers de auditoria: cada INSERT, UPDATE e DELETE gera
/// uma linha em `historico_alteracoes`, com o usuário do banco (`USER()`).
class InsumoRepositoryMysql implements InsumoRepository {
  final ConexaoMysql _banco;

  /// Cria o repositório usando uma conexão já aberta.
  InsumoRepositoryMysql(this._banco);

  static const _selecao = 'SELECT id_insumo, nome, marca, tipo FROM insumo';

  @override
  Future<Insumo> salvar(Insumo insumo) {
    return _banco.usar('salvar insumo', (conexao) async {
      await gravarLinha(
        conexao,
        insumo,
        tabela: 'insumo',
        colunaId: 'id_insumo',
        nomeEntidade: 'insumo',
        valores: {
          'nome': insumo.nome,
          'marca': insumo.marca,
          'tipo': insumo.tipo,
        },
      );
      return insumo;
    });
  }

  @override
  Future<Insumo?> buscarPorId(int id) {
    return _banco.usar('buscar insumo', (conexao) async {
      final lista = await _consultar(conexao, 'WHERE id_insumo = :id', {
        'id': id,
      });
      return lista.firstOrNull;
    });
  }

  @override
  Future<List<Insumo>> listarPorTipo(String tipo) {
    return _banco.usar('listar insumo', (conexao) {
      return _consultar(conexao, 'WHERE tipo = :tipo', {'tipo': tipo.trim()});
    });
  }

  @override
  Future<List<Insumo>> listarTodos() {
    return _banco.usar('listar insumo', (conexao) {
      return _consultar(conexao, '');
    });
  }

  @override
  Future<bool> remover(int id) {
    return _banco.usar('remover insumo', (conexao) async {
      final resultado = await conexao.execute(
        'DELETE FROM insumo WHERE id_insumo = :id',
        {'id': id},
      );
      return resultado.affectedRows.toInt() > 0;
    });
  }

  Future<List<Insumo>> _consultar(
    MySQLConnection conexao,
    String filtro, [
    Map<String, dynamic>? parametros,
  ]) async {
    final resultado = await conexao.execute(
      '$_selecao $filtro ORDER BY id_insumo',
      parametros,
    );
    return [for (final linha in resultado.rows) _paraInsumo(linha.assoc())];
  }

  Insumo _paraInsumo(Map<String, dynamic> linha) {
    return Insumo(
      id: inteiro(linha['id_insumo']),
      nome: linha['nome'].toString(),
      tipo: linha['tipo'].toString(),
      marca: textoOuNulo(linha['marca']),
    );
  }
}
