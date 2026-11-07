import 'package:caderno_fazenda/models/aplicador.dart';
import 'package:caderno_fazenda/models/aplicador_fabrica.dart';
import 'package:caderno_fazenda/repositories/interfaces/aplicador_repository.dart';
import 'package:caderno_fazenda/repositories/mysql/ajuda_mysql.dart';
import 'package:caderno_fazenda/repositories/mysql/conexao_mysql.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';

/// Guarda os aplicadores (trator, drone, bomba costal) no MySQL.
///
/// Tabela: `aplicador (id_aplicador, modelo, tipo, capacidade_max_litros,
/// capacidade_max_kg)`. A coluna `tipo` decide a subclasse na leitura, pela
/// função `criarAplicador`.
///
/// Atenção: no banco a coluna `modelo` é `NOT NULL`, mas em [Aplicador] o
/// modelo é opcional. Quando não há modelo, grava-se texto vazio, e na leitura
/// o texto vazio volta a ser null.
class AplicadorRepositoryMysql implements AplicadorRepository {
  final ConexaoMysql _banco;

  /// Cria o repositório usando uma conexão já aberta.
  AplicadorRepositoryMysql(this._banco);

  static const _selecao =
      'SELECT id_aplicador, modelo, tipo, capacidade_max_litros, '
      'capacidade_max_kg FROM aplicador';

  @override
  Future<Aplicador> salvar(Aplicador aplicador) {
    return _banco.usar('salvar aplicador', (conexao) async {
      final litrosMax = aplicador.capacidadeMaximaL;
      final kgMax = aplicador.capacidadeMaximaKg;
      await gravarLinha(
        conexao,
        aplicador,
        tabela: 'aplicador',
        colunaId: 'id_aplicador',
        nomeEntidade: 'aplicador',
        valores: {
          'modelo': aplicador.modelo ?? '',
          'tipo': aplicador.tipo,
          'capacidade_max_litros': litrosMax == null
              ? null
              : arredondar(litrosMax, 2),
          'capacidade_max_kg': kgMax == null ? null : arredondar(kgMax, 2),
        },
      );
      return aplicador;
    });
  }

  @override
  Future<Aplicador?> buscarPorId(int id) {
    return _banco.usar('buscar aplicador', (conexao) async {
      final lista = await _consultar(conexao, 'WHERE id_aplicador = :id', {
        'id': id,
      });
      return lista.firstOrNull;
    });
  }

  @override
  Future<List<Aplicador>> listarPorTipo(String tipo) {
    return _banco.usar('listar aplicador', (conexao) {
      return _consultar(conexao, 'WHERE tipo = :tipo', {'tipo': tipo.trim()});
    });
  }

  @override
  Future<List<Aplicador>> listarTodos() {
    return _banco.usar('listar aplicador', (conexao) {
      return _consultar(conexao, '');
    });
  }

  @override
  Future<bool> remover(int id) {
    return _banco.usar('remover aplicador', (conexao) async {
      final resultado = await conexao.execute(
        'DELETE FROM aplicador WHERE id_aplicador = :id',
        {'id': id},
      );
      return resultado.affectedRows.toInt() > 0;
    });
  }

  Future<List<Aplicador>> _consultar(
    MySQLConnection conexao,
    String filtro, [
    Map<String, dynamic>? parametros,
  ]) async {
    final resultado = await conexao.execute(
      '$_selecao $filtro ORDER BY id_aplicador',
      parametros,
    );
    return [for (final linha in resultado.rows) _paraAplicador(linha.assoc())];
  }

  Aplicador _paraAplicador(Map<String, dynamic> linha) {
    return criarAplicador(
      linha['tipo'].toString(),
      id: inteiro(linha['id_aplicador']),
      modelo: textoOuNulo(linha['modelo']),
      capacidadeMaximaL: decimalOuNulo(linha['capacidade_max_litros']),
      capacidadeMaximaKg: decimalOuNulo(linha['capacidade_max_kg']),
    );
  }
}
