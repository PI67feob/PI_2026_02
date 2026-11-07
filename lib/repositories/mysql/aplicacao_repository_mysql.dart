import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';
import 'package:caderno_fazenda/models/aplicacao.dart';
import 'package:caderno_fazenda/models/aplicacao_insumo.dart';
import 'package:caderno_fazenda/models/aplicador.dart';
import 'package:caderno_fazenda/models/insumo.dart';
import 'package:caderno_fazenda/models/operacao.dart';
import 'package:caderno_fazenda/models/talhao.dart';
import 'package:caderno_fazenda/models/unidade_dose.dart';
import 'package:caderno_fazenda/repositories/interfaces/aplicacao_repository.dart';
import 'package:caderno_fazenda/repositories/interfaces/aplicador_repository.dart';
import 'package:caderno_fazenda/repositories/interfaces/insumo_repository.dart';
import 'package:caderno_fazenda/repositories/interfaces/operacao_repository.dart';
import 'package:caderno_fazenda/repositories/interfaces/repository.dart';
import 'package:caderno_fazenda/repositories/interfaces/talhao_repository.dart';
import 'package:caderno_fazenda/repositories/mysql/ajuda_mysql.dart';
import 'package:caderno_fazenda/repositories/mysql/conexao_mysql.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';

/// Guarda as aplicações no MySQL.
///
/// Uma [Aplicacao] ocupa três tabelas: `aplicacao` (a linha principal),
/// `aplicacao_talhao` (os talhões) e `aplicacao_insumo` (os insumos, com as
/// doses). O [salvar] e o [remover] rodam dentro de uma transação
/// (`START TRANSACTION` / `COMMIT` / `ROLLBACK`): ou gravam tudo ou não
/// gravam nada.
///
/// Para montar uma aplicação lida do banco, o repositório busca a operação, o
/// aplicador, os talhões e os insumos pelos repositórios correspondentes. Por
/// isso eles são recebidos no construtor, e tudo precisa estar salvo (com id)
/// antes de salvar uma aplicação.
///
/// As tabelas filhas têm triggers de auditoria: cada linha gravada ou apagada
/// gera uma linha em `historico_alteracoes`.
class AplicacaoRepositoryMysql implements AplicacaoRepository {
  final ConexaoMysql _banco;
  final OperacaoRepository _operacoes;
  final AplicadorRepository _aplicadores;
  final TalhaoRepository _talhoes;
  final InsumoRepository _insumos;

  /// Cria o repositório. Os repositórios de `operacoes`, `aplicadores`,
  /// `talhoes` e `insumos` precisam usar a mesma conexão.
  AplicacaoRepositoryMysql(
    this._banco, {
    required this._operacoes,
    required this._aplicadores,
    required this._talhoes,
    required this._insumos,
  });

  static const _selecao =
      'SELECT a.id_aplicacao, a.id_operacao, a.id_aplicador, '
      'a.data_aplicacao, a.observacao FROM aplicacao a';

  @override
  Future<Aplicacao> salvar(Aplicacao aplicacao) {
    return _banco.usar('salvar aplicação', (conexao) async {
      _exigirTudoSalvo(aplicacao);
      final idAtual = aplicacao.id;
      final valores = <String, Object?>{
        'id_operacao': aplicacao.operacao.id,
        'id_aplicador': aplicacao.aplicador.id,
        'data_aplicacao': dataSql(aplicacao.data),
        'observacao': aplicacao.observacao,
      };

      await conexao.execute('START TRANSACTION');
      try {
        final int id;
        if (idAtual == null) {
          id = await inserirLinha(conexao, 'aplicacao', valores);
        } else {
          id = idAtual;
          await atualizarLinha(
            conexao,
            'aplicacao',
            'id_aplicacao',
            id,
            valores,
            entidade: 'aplicação',
          );
          await _apagarFilhos(conexao, id);
        }
        await _gravarFilhos(conexao, aplicacao, id);
        await conexao.execute('COMMIT');
        // O id só é guardado depois do COMMIT: se der erro, a aplicação
        // continua sem id, como se nunca tivesse sido salva.
        if (idAtual == null) {
          aplicacao.definirId(id);
        }
      } catch (_) {
        await _desfazer(conexao);
        rethrow;
      }
      return aplicacao;
    });
  }

  @override
  Future<Aplicacao?> buscarPorId(int id) {
    return _banco.usar('buscar aplicação', (conexao) async {
      final lista = await _consultar(conexao, 'WHERE a.id_aplicacao = :id', {
        'id': id,
      });
      return lista.firstOrNull;
    });
  }

  @override
  Future<List<Aplicacao>> listarTodos() {
    return _banco.usar('listar aplicação', (conexao) {
      return _consultar(conexao, '');
    });
  }

  @override
  Future<List<Aplicacao>> listarPorTalhao(int talhaoId) {
    return _banco.usar('listar aplicação', (conexao) {
      return _consultar(
        conexao,
        'WHERE a.id_aplicacao IN '
        '(SELECT id_aplicacao FROM aplicacao_talhao WHERE id_talhao = :talhao)',
        {'talhao': talhaoId},
      );
    });
  }

  @override
  Future<List<Aplicacao>> listarPorPeriodo(DateTime de, DateTime ate) {
    return _banco.usar('listar aplicação', (conexao) {
      return _consultar(
        conexao,
        'WHERE a.data_aplicacao BETWEEN :de AND :ate',
        {'de': dataSql(de), 'ate': dataSql(ate)},
      );
    });
  }

  @override
  Future<bool> remover(int id) {
    return _banco.usar('remover aplicação', (conexao) async {
      await conexao.execute('START TRANSACTION');
      try {
        await _apagarFilhos(conexao, id);
        final resultado = await conexao.execute(
          'DELETE FROM aplicacao WHERE id_aplicacao = :id',
          {'id': id},
        );
        await conexao.execute('COMMIT');
        return resultado.affectedRows.toInt() > 0;
      } catch (_) {
        await _desfazer(conexao);
        rethrow;
      }
    });
  }

  /// Confere, antes de abrir a transação, que tudo o que a aplicação usa já
  /// foi salvo (tem id). Sem isso o INSERT falharia no meio da gravação.
  void _exigirTudoSalvo(Aplicacao aplicacao) {
    const aviso = 'salve antes de registrar a aplicação';
    if (aplicacao.operacao.id == null) {
      throw DadoInvalidoException('operação', aviso);
    }
    if (aplicacao.aplicador.id == null) {
      throw DadoInvalidoException('aplicador', aviso);
    }
    for (final talhao in aplicacao.talhoes) {
      if (talhao.id == null) {
        throw DadoInvalidoException('talhão ${talhao.nome}', aviso);
      }
    }
    for (final item in aplicacao.insumos) {
      if (item.insumo.id == null) {
        throw DadoInvalidoException('insumo ${item.insumo.nome}', aviso);
      }
    }
  }

  Future<void> _gravarFilhos(
    MySQLConnection conexao,
    Aplicacao aplicacao,
    int id,
  ) async {
    for (final talhao in aplicacao.talhoes) {
      await conexao.execute(
        'INSERT INTO aplicacao_talhao (id_aplicacao, id_talhao) '
        'VALUES (:aplicacao, :talhao)',
        {'aplicacao': id, 'talhao': talhao.id},
      );
    }
    for (final item in aplicacao.insumos) {
      final realizada = item.doseRealizada;
      await conexao.execute(
        'INSERT INTO aplicacao_insumo (id_aplicacao, id_insumo, '
        'dose_prevista, dose_realizada, unidade_dose) '
        'VALUES (:aplicacao, :insumo, :prevista, :realizada, :unidade)',
        {
          'aplicacao': id,
          'insumo': item.insumo.id,
          'prevista': arredondar(item.dosePrevista, 3),
          'realizada': realizada == null ? null : arredondar(realizada, 3),
          'unidade': item.unidade.texto,
        },
      );
    }
  }

  Future<void> _apagarFilhos(MySQLConnection conexao, int id) async {
    await conexao.execute(
      'DELETE FROM aplicacao_insumo WHERE id_aplicacao = :id',
      {'id': id},
    );
    await conexao.execute(
      'DELETE FROM aplicacao_talhao WHERE id_aplicacao = :id',
      {'id': id},
    );
  }

  /// Desfaz a transação. Se até o ROLLBACK falhar (a conexão caiu), o erro
  /// original é o que importa, então este é ignorado.
  Future<void> _desfazer(MySQLConnection conexao) async {
    try {
      await conexao.execute('ROLLBACK');
    } catch (_) {
      // Sem conexão não há o que desfazer; o servidor descarta a transação.
    }
  }

  /// Roda o SELECT padrão com o [filtro] (texto fixo do código com parâmetros
  /// nomeados) e monta as aplicações, em ordem crescente de id.
  Future<List<Aplicacao>> _consultar(
    MySQLConnection conexao,
    String filtro, [
    Map<String, dynamic>? parametros,
  ]) async {
    final resultado = await conexao.execute(
      '$_selecao $filtro ORDER BY a.id_aplicacao',
      parametros,
    );
    final linhas = <Map<String, dynamic>>[
      for (final linha in resultado.rows) linha.assoc(),
    ];
    return _montar(conexao, linhas);
  }

  /// Transforma as [linhas] de `aplicacao` em objetos [Aplicacao].
  ///
  /// Os talhões e os insumos de todas as linhas vêm em duas consultas (e não
  /// uma por aplicação), e cada operação, aplicador, talhão e insumo é buscado
  /// uma única vez, mesmo que várias aplicações o usem. Isso importa porque
  /// cada ida ao banco na AWS leva uma fração de segundo.
  Future<List<Aplicacao>> _montar(
    MySQLConnection conexao,
    List<Map<String, dynamic>> linhas,
  ) async {
    if (linhas.isEmpty) {
      return [];
    }
    // Só números que acabaram de sair do banco: seguro colar no IN (...).
    final ids = [for (final linha in linhas) inteiro(linha['id_aplicacao'])];
    final lista = ids.join(', ');

    final porTalhao = await conexao.execute(
      'SELECT id_aplicacao, id_talhao FROM aplicacao_talhao '
      'WHERE id_aplicacao IN ($lista) ORDER BY id_aplicacao, id_talhao',
    );
    final talhaoIds = <int, List<int>>{};
    for (final linha in porTalhao.rows) {
      final dados = linha.assoc();
      talhaoIds
          .putIfAbsent(inteiro(dados['id_aplicacao']), () => [])
          .add(inteiro(dados['id_talhao']));
    }

    final porInsumo = await conexao.execute(
      'SELECT id_aplicacao, id_insumo, dose_prevista, dose_realizada, '
      'unidade_dose FROM aplicacao_insumo '
      'WHERE id_aplicacao IN ($lista) ORDER BY id_aplicacao, id_insumo',
    );
    final doses = <int, List<Map<String, dynamic>>>{};
    for (final linha in porInsumo.rows) {
      final dados = linha.assoc();
      doses.putIfAbsent(inteiro(dados['id_aplicacao']), () => []).add(dados);
    }

    final operacoes = <int, Operacao>{};
    final aplicadores = <int, Aplicador>{};
    final talhoes = <int, Talhao>{};
    final insumos = <int, Insumo>{};

    final aplicacoes = <Aplicacao>[];
    for (final linha in linhas) {
      final id = inteiro(linha['id_aplicacao']);

      final idOperacao = inteiro(linha['id_operacao']);
      final operacao = operacoes[idOperacao] ??= await _operacoes.exigirPorId(
        idOperacao,
        'operação',
      );

      final idAplicador = inteiro(linha['id_aplicador']);
      final aplicador = aplicadores[idAplicador] ??= await _aplicadores
          .exigirPorId(idAplicador, 'aplicador');

      final dosesDaAplicacao = <AplicacaoInsumo>[];
      for (final dados in doses[id] ?? const <Map<String, dynamic>>[]) {
        final idInsumo = inteiro(dados['id_insumo']);
        final insumo = insumos[idInsumo] ??= await _insumos.exigirPorId(
          idInsumo,
          'insumo',
        );
        dosesDaAplicacao.add(
          AplicacaoInsumo(
            insumo: insumo,
            unidade: UnidadeDose.deTexto(dados['unidade_dose'].toString()),
            dosePrevista: decimal(dados['dose_prevista']),
            doseRealizada: decimalOuNulo(dados['dose_realizada']),
          ),
        );
      }

      final talhoesDaAplicacao = <Talhao>[];
      for (final idTalhao in talhaoIds[id] ?? const <int>[]) {
        talhoesDaAplicacao.add(
          talhoes[idTalhao] ??= await _talhoes.exigirPorId(idTalhao, 'talhão'),
        );
      }

      aplicacoes.add(
        Aplicacao(
          id: id,
          data: DateTime.parse(linha['data_aplicacao'].toString()),
          operacao: operacao,
          aplicador: aplicador,
          talhoes: talhoesDaAplicacao,
          insumos: dosesDaAplicacao,
          observacao: textoOuNulo(linha['observacao']),
        ),
      );
    }
    return aplicacoes;
  }
}
