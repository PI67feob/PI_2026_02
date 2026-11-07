import 'package:caderno_fazenda/models/operacao.dart';
import 'package:caderno_fazenda/repositories/interfaces/operacao_repository.dart';
import 'package:caderno_fazenda/repositories/mysql/ajuda_mysql.dart';
import 'package:caderno_fazenda/repositories/mysql/conexao_mysql.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';

/// Guarda os tipos de operação (pulverização, adubação...) no MySQL.
///
/// Tabela: `operacao (id_operacao, nome, descricao)`, com `UNIQUE (nome)`.
///
/// Atenção ao nome: a classe [Operacao] chama de `descricao` o texto que o
/// banco chama de `nome` (ex.: "Pulverização"). Este repositório faz essa
/// ponte: `Operacao.descricao` <-> coluna `nome`. A coluna `descricao` do banco
/// fica como está.
class OperacaoRepositoryMysql implements OperacaoRepository {
  final ConexaoMysql _banco;

  /// Cria o repositório usando uma conexão já aberta.
  OperacaoRepositoryMysql(this._banco);

  static const _selecao = 'SELECT id_operacao, nome FROM operacao';

  @override
  Future<Operacao> salvar(Operacao operacao) {
    return _banco.usar('salvar operação', (conexao) async {
      await gravarLinha(
        conexao,
        operacao,
        tabela: 'operacao',
        colunaId: 'id_operacao',
        nomeEntidade: 'operação',
        valores: {'nome': operacao.descricao},
      );
      return operacao;
    });
  }

  @override
  Future<Operacao?> buscarPorId(int id) {
    return _banco.usar('buscar operação', (conexao) async {
      final lista = await _consultar(conexao, 'WHERE id_operacao = :id', {
        'id': id,
      });
      return lista.firstOrNull;
    });
  }

  @override
  Future<Operacao?> buscarPorDescricao(String descricao) {
    return _banco.usar('buscar operação', (conexao) async {
      final lista = await _consultar(conexao, 'WHERE nome = :nome', {
        'nome': descricao.trim(),
      });
      return lista.firstOrNull;
    });
  }

  @override
  Future<List<Operacao>> listarTodos() {
    return _banco.usar('listar operação', (conexao) {
      return _consultar(conexao, '');
    });
  }

  @override
  Future<bool> remover(int id) {
    return _banco.usar('remover operação', (conexao) async {
      final resultado = await conexao.execute(
        'DELETE FROM operacao WHERE id_operacao = :id',
        {'id': id},
      );
      return resultado.affectedRows.toInt() > 0;
    });
  }

  Future<List<Operacao>> _consultar(
    MySQLConnection conexao,
    String filtro, [
    Map<String, dynamic>? parametros,
  ]) async {
    final resultado = await conexao.execute(
      '$_selecao $filtro ORDER BY id_operacao',
      parametros,
    );
    return [for (final linha in resultado.rows) _paraOperacao(linha.assoc())];
  }

  Operacao _paraOperacao(Map<String, dynamic> linha) {
    return Operacao(
      id: inteiro(linha['id_operacao']),
      descricao: linha['nome'].toString(),
    );
  }
}
