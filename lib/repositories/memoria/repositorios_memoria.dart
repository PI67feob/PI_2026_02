/// Repositórios provisórios que guardam tudo na memória (mock do banco).
///
/// Servem para o sistema funcionar e ser testado antes de existir o MySQL.
/// Quando a persistência real chegar (PI-023), as classes de
/// `lib/repositories/mysql` implementam as mesmas interfaces e substituem estas
/// na hora de montar os serviços; nenhuma regra de negócio muda.
///
/// A versão em memória imita o que o banco faz: gera o id (AUTO_INCREMENT),
/// aceita um id já definido, impede talhão repetido na mesma área (UNIQUE) e
/// falha com `PersistenciaException` quando o banco está "fora do ar". Os dados
/// somem quando o programa termina.
library;

import 'package:caderno_fazenda/exceptions/persistencia_exception.dart';
import 'package:caderno_fazenda/models/aplicacao.dart';
import 'package:caderno_fazenda/models/aplicador.dart';
import 'package:caderno_fazenda/models/area.dart';
import 'package:caderno_fazenda/models/entidade.dart';
import 'package:caderno_fazenda/models/insumo.dart';
import 'package:caderno_fazenda/models/operacao.dart';
import 'package:caderno_fazenda/models/talhao.dart';
import 'package:caderno_fazenda/repositories/interfaces/aplicacao_repository.dart';
import 'package:caderno_fazenda/repositories/interfaces/aplicador_repository.dart';
import 'package:caderno_fazenda/repositories/interfaces/area_repository.dart';
import 'package:caderno_fazenda/repositories/interfaces/insumo_repository.dart';
import 'package:caderno_fazenda/repositories/interfaces/operacao_repository.dart';
import 'package:caderno_fazenda/repositories/interfaces/repository.dart';
import 'package:caderno_fazenda/repositories/interfaces/talhao_repository.dart';

/// Compara dois textos sem diferenciar maiúsculas de minúsculas, como o
/// MySQL faz nas colunas de texto.
bool _mesmoTexto(String a, String b) {
  return a.trim().toLowerCase() == b.trim().toLowerCase();
}

/// Repositório genérico em memória: serve de base para os de cada entidade.
class RepositoryMemoria<T extends Entidade> implements Repository<T> {
  final String _nomeEntidade;
  final Map<int, T> _registros = {};
  int _proximoId = 1;

  /// Quando verdadeiro, toda operação falha com `PersistenciaException`, como
  /// se o banco estivesse fora do ar. Serve para testar o tratamento de erro.
  bool bancoIndisponivel = false;

  /// Cria o repositório. O [_nomeEntidade] aparece nas mensagens de erro.
  RepositoryMemoria(this._nomeEntidade);

  @override
  Future<T> salvar(T entidade) async {
    _exigirBanco('salvar $_nomeEntidade');
    conferirRestricoes(entidade);
    final id = entidade.id ?? _proximoId;
    entidade.definirId(id);
    _registros[id] = entidade;
    if (id >= _proximoId) {
      _proximoId = id + 1;
    }
    return entidade;
  }

  @override
  Future<T?> buscarPorId(int id) async {
    _exigirBanco('buscar $_nomeEntidade');
    return _registros[id];
  }

  @override
  Future<List<T>> listarTodos() async {
    _exigirBanco('listar $_nomeEntidade');
    return _ordenados();
  }

  @override
  Future<bool> remover(int id) async {
    _exigirBanco('remover $_nomeEntidade');
    return _registros.remove(id) != null;
  }

  /// Ponto de extensão: as subclasses conferem aqui as restrições UNIQUE que o
  /// banco real teria. A versão genérica não confere nada.
  void conferirRestricoes(T entidade) {}

  void _exigirBanco(String operacao) {
    if (bancoIndisponivel) {
      throw PersistenciaException(operacao, causa: 'banco fora do ar');
    }
  }

  List<T> _ordenados() {
    final ids = _registros.keys.toList();
    ids.sort();
    return ids.map((id) => _registros[id]!).toList();
  }
}

/// Áreas da propriedade na memória.
class AreaRepositoryMemoria extends RepositoryMemoria<Area>
    implements AreaRepository {
  /// Cria um repositório de áreas vazio.
  AreaRepositoryMemoria() : super('área');

  @override
  Future<Area?> buscarPorNome(String nome) async {
    _exigirBanco('buscar área');
    for (final area in _ordenados()) {
      if (_mesmoTexto(area.nome, nome)) {
        return area;
      }
    }
    return null;
  }
}

/// Talhões na memória. Não aceita dois talhões com o mesmo nome na mesma área.
class TalhaoRepositoryMemoria extends RepositoryMemoria<Talhao>
    implements TalhaoRepository {
  /// Cria um repositório de talhões vazio.
  TalhaoRepositoryMemoria() : super('talhão');

  @override
  void conferirRestricoes(Talhao entidade) {
    for (final existente in _ordenados()) {
      if (existente.mesmoRegistro(entidade)) {
        continue;
      }
      final mesmaArea = existente.area.mesmoRegistro(entidade.area);
      if (mesmaArea && _mesmoTexto(existente.nome, entidade.nome)) {
        throw PersistenciaException(
          'salvar talhão',
          causa: 'UNIQUE (area_id, nome): talhão repetido na área',
        );
      }
    }
  }

  @override
  Future<Talhao?> buscarPorAreaENome(int areaId, String nome) async {
    _exigirBanco('buscar talhão');
    for (final talhao in _ordenados()) {
      final daArea = talhao.area.id == areaId;
      if (daArea && _mesmoTexto(talhao.nome, nome)) {
        return talhao;
      }
    }
    return null;
  }

  @override
  Future<List<Talhao>> listarPorArea(int areaId) async {
    _exigirBanco('listar talhão');
    final lista = <Talhao>[];
    for (final talhao in _ordenados()) {
      if (talhao.area.id == areaId) {
        lista.add(talhao);
      }
    }
    return lista;
  }
}

/// Insumos na memória.
class InsumoRepositoryMemoria extends RepositoryMemoria<Insumo>
    implements InsumoRepository {
  /// Cria um repositório de insumos vazio.
  InsumoRepositoryMemoria() : super('insumo');

  @override
  Future<List<Insumo>> listarPorTipo(String tipo) async {
    _exigirBanco('listar insumo');
    final lista = <Insumo>[];
    for (final insumo in _ordenados()) {
      if (_mesmoTexto(insumo.tipo, tipo)) {
        lista.add(insumo);
      }
    }
    return lista;
  }
}

/// Aplicadores na memória (trator, drone e bomba costal).
class AplicadorRepositoryMemoria extends RepositoryMemoria<Aplicador>
    implements AplicadorRepository {
  /// Cria um repositório de aplicadores vazio.
  AplicadorRepositoryMemoria() : super('aplicador');

  @override
  Future<List<Aplicador>> listarPorTipo(String tipo) async {
    _exigirBanco('listar aplicador');
    final lista = <Aplicador>[];
    for (final aplicador in _ordenados()) {
      if (_mesmoTexto(aplicador.tipo, tipo)) {
        lista.add(aplicador);
      }
    }
    return lista;
  }
}

/// Operações na memória.
class OperacaoRepositoryMemoria extends RepositoryMemoria<Operacao>
    implements OperacaoRepository {
  /// Cria um repositório de operações vazio.
  OperacaoRepositoryMemoria() : super('operação');

  @override
  Future<Operacao?> buscarPorDescricao(String descricao) async {
    _exigirBanco('buscar operação');
    for (final operacao in _ordenados()) {
      if (_mesmoTexto(operacao.descricao, descricao)) {
        return operacao;
      }
    }
    return null;
  }
}

/// Aplicações na memória.
class AplicacaoRepositoryMemoria extends RepositoryMemoria<Aplicacao>
    implements AplicacaoRepository {
  /// Cria um repositório de aplicações vazio.
  AplicacaoRepositoryMemoria() : super('aplicação');

  @override
  Future<List<Aplicacao>> listarPorTalhao(int talhaoId) async {
    _exigirBanco('listar aplicação');
    final lista = <Aplicacao>[];
    for (final aplicacao in _ordenados()) {
      if (aplicacao.talhoes.any((talhao) => talhao.id == talhaoId)) {
        lista.add(aplicacao);
      }
    }
    return lista;
  }

  @override
  Future<List<Aplicacao>> listarPorPeriodo(DateTime de, DateTime ate) async {
    _exigirBanco('listar aplicação');
    final inicio = DateTime(de.year, de.month, de.day);
    final fim = DateTime(ate.year, ate.month, ate.day);
    final lista = <Aplicacao>[];
    for (final aplicacao in _ordenados()) {
      final data = aplicacao.data;
      if (!data.isBefore(inicio) && !data.isAfter(fim)) {
        lista.add(aplicacao);
      }
    }
    return lista;
  }
}
