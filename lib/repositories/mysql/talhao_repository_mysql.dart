import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';
import 'package:caderno_fazenda/models/area.dart';
import 'package:caderno_fazenda/models/talhao.dart';
import 'package:caderno_fazenda/repositories/interfaces/talhao_repository.dart';
import 'package:caderno_fazenda/repositories/mysql/ajuda_mysql.dart';
import 'package:caderno_fazenda/repositories/mysql/conexao_mysql.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';

/// Guarda os talhões na tabela `talhao` do MySQL.
///
/// Tabela: `talhao (id_talhao, id_area, nome, hectares, localizacao)`, com
/// `UNIQUE (id_area, nome)` e `hectares > 0`. Um talhão repetido na mesma área
/// (sem diferenciar maiúsculas) vira `PersistenciaException`, como na versão
/// em memória. Cada talhão lido já vem com a sua [Area], por um JOIN.
class TalhaoRepositoryMysql implements TalhaoRepository {
  final ConexaoMysql _banco;

  /// Cria o repositório usando uma conexão já aberta.
  TalhaoRepositoryMysql(this._banco);

  static const _selecao =
      'SELECT t.id_talhao, t.nome, t.hectares, a.id_area, '
      'a.nome AS nome_area '
      'FROM talhao t JOIN area a ON a.id_area = t.id_area';

  @override
  Future<Talhao> salvar(Talhao talhao) {
    return _banco.usar('salvar talhão', (conexao) async {
      final areaId = talhao.area.id;
      if (areaId == null) {
        throw DadoInvalidoException('área', 'salve a área antes do talhão');
      }
      await gravarLinha(
        conexao,
        talhao,
        tabela: 'talhao',
        colunaId: 'id_talhao',
        nomeEntidade: 'talhão',
        valores: {
          'id_area': areaId,
          'nome': talhao.nome,
          'hectares': arredondar(talhao.hectares, 2),
        },
      );
      return talhao;
    });
  }

  @override
  Future<Talhao?> buscarPorId(int id) {
    return _banco.usar('buscar talhão', (conexao) async {
      final lista = await _consultar(conexao, 'WHERE t.id_talhao = :id', {
        'id': id,
      });
      return lista.firstOrNull;
    });
  }

  @override
  Future<Talhao?> buscarPorAreaENome(int areaId, String nome) {
    return _banco.usar('buscar talhão', (conexao) async {
      final lista = await _consultar(
        conexao,
        'WHERE t.id_area = :area AND t.nome = :nome',
        {'area': areaId, 'nome': nome.trim()},
      );
      return lista.firstOrNull;
    });
  }

  @override
  Future<List<Talhao>> listarPorArea(int areaId) {
    return _banco.usar('listar talhão', (conexao) {
      return _consultar(conexao, 'WHERE t.id_area = :area', {'area': areaId});
    });
  }

  @override
  Future<List<Talhao>> listarTodos() {
    return _banco.usar('listar talhão', (conexao) {
      return _consultar(conexao, '');
    });
  }

  @override
  Future<bool> remover(int id) {
    return _banco.usar('remover talhão', (conexao) async {
      final resultado = await conexao.execute(
        'DELETE FROM talhao WHERE id_talhao = :id',
        {'id': id},
      );
      return resultado.affectedRows.toInt() > 0;
    });
  }

  /// Roda o SELECT padrão com o [filtro] (que só tem texto fixo do código e
  /// parâmetros nomeados), sempre em ordem crescente de id.
  Future<List<Talhao>> _consultar(
    MySQLConnection conexao,
    String filtro, [
    Map<String, dynamic>? parametros,
  ]) async {
    final resultado = await conexao.execute(
      '$_selecao $filtro ORDER BY t.id_talhao',
      parametros,
    );
    return [for (final linha in resultado.rows) _paraTalhao(linha.assoc())];
  }

  Talhao _paraTalhao(Map<String, dynamic> linha) {
    return Talhao(
      id: inteiro(linha['id_talhao']),
      nome: linha['nome'].toString(),
      hectares: decimal(linha['hectares']),
      area: Area(
        id: inteiro(linha['id_area']),
        nome: linha['nome_area'].toString(),
      ),
    );
  }
}
