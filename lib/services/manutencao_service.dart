import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';
import 'package:caderno_fazenda/exceptions/dose_invalida_exception.dart';
import 'package:caderno_fazenda/exceptions/exclusao_negada_exception.dart';
import 'package:caderno_fazenda/exceptions/registro_nao_encontrado_exception.dart';
import 'package:caderno_fazenda/models/aplicacao.dart';
import 'package:caderno_fazenda/models/aplicacao_insumo.dart';
import 'package:caderno_fazenda/models/aplicador.dart';
import 'package:caderno_fazenda/models/aplicador_fabrica.dart';
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

/// Corrige e exclui o que já está cadastrado.
///
/// Conhece só as interfaces de repositório, nunca o banco, então as regras
/// valem do mesmo jeito na memória e no MySQL.
///
/// **Correções.** Cada `corrigir...` recebe os valores que o registro deve ter
/// depois da correção (nos campos opcionais, `null` significa "sem valor"). Os
/// valores novos são conferidos antes de gravar: se algum for recusado, o
/// registro continua exatamente como estava. A exceção é o talhão, que fica no
/// `TalhaoService`.
///
/// **Exclusões.** Nada que esteja em uso é excluído, para nenhuma aplicação
/// ficar apontando para um registro que não existe mais:
/// - área: só se não tiver talhões;
/// - talhão, insumo, aplicador e operação: só se nenhuma aplicação os usar;
/// - aplicação: sempre pode, e leva junto os seus talhões e insumos.
///
/// As recusas são [ExclusaoNegadaException], com o motivo e o que excluir
/// antes. Todo `excluir...` aceita `apenasConferir: true`, que faz só a
/// conferência e não exclui: o menu usa isso para recusar antes de pedir a
/// confirmação ao usuário.
class ManutencaoService {
  final AreaRepository _areas;
  final TalhaoRepository _talhoes;
  final InsumoRepository _insumos;
  final AplicadorRepository _aplicadores;
  final OperacaoRepository _operacoes;
  final AplicacaoRepository _aplicacoes;

  /// Cria o serviço com os seis repositórios.
  ManutencaoService(
    this._areas,
    this._talhoes,
    this._insumos,
    this._aplicadores,
    this._operacoes,
    this._aplicacoes,
  );

  // ---------------------------------------------------------------------
  // Correções
  // ---------------------------------------------------------------------

  /// Troca o nome de uma área.
  ///
  /// Lança `DadoInvalidoException` se o nome ficar vazio ou já for de outra
  /// área, e `RegistroNaoEncontradoException` se a área não existir.
  Future<Area> corrigirArea(int id, {required String nome}) async {
    final area = await _areas.exigirPorId(id, 'área');
    final conferida = Area(nome: nome);
    final outra = await _areas.buscarPorNome(conferida.nome);
    if (outra != null && !outra.mesmoRegistro(area)) {
      throw DadoInvalidoException(
        'nome da área',
        'já existe a área "${outra.nome}"',
      );
    }
    area.nome = conferida.nome;
    return _areas.salvar(area);
  }

  /// Corrige o nome, o tipo e a marca de um insumo (a [marca] vazia tira a
  /// marca).
  ///
  /// Lança `DadoInvalidoException` se o nome ou o tipo ficarem vazios ou se já
  /// existir outro insumo com o mesmo nome e tipo, e
  /// `RegistroNaoEncontradoException` se o insumo não existir.
  Future<Insumo> corrigirInsumo(
    int id, {
    required String nome,
    required String tipo,
    String? marca,
  }) async {
    final insumo = await _insumos.exigirPorId(id, 'insumo');
    final conferido = Insumo(nome: nome, tipo: tipo, marca: marca);
    final mesmoTipo = await _insumos.listarPorTipo(conferido.tipo);
    for (final outro in mesmoTipo) {
      final mesmoNome = _mesmoTexto(outro.nome, conferido.nome);
      if (mesmoNome && !outro.mesmoRegistro(insumo)) {
        throw DadoInvalidoException(
          'insumo',
          'já existe "${outro.nome}" do tipo ${outro.tipo}',
        );
      }
    }
    insumo.nome = conferido.nome;
    insumo.tipo = conferido.tipo;
    insumo.marca = conferido.marca;
    return _insumos.salvar(insumo);
  }

  /// Corrige o modelo e as capacidades de um aplicador. O tipo (trator, drone
  /// ou bomba costal) não muda. Os três valores são os que o aplicador terá
  /// depois: `null` tira o valor.
  ///
  /// Lança `DadoInvalidoException` se alguma capacidade não for maior que
  /// zero, e `RegistroNaoEncontradoException` se o aplicador não existir.
  Future<Aplicador> corrigirAplicador(
    int id, {
    String? modelo,
    double? capacidadeMaximaL,
    double? capacidadeMaximaKg,
  }) async {
    final aplicador = await _aplicadores.exigirPorId(id, 'aplicador');
    // Um aplicador do mesmo tipo montado só para conferir os valores novos.
    final conferido = criarAplicador(
      aplicador.tipo,
      modelo: modelo,
      capacidadeMaximaL: capacidadeMaximaL,
      capacidadeMaximaKg: capacidadeMaximaKg,
    );
    aplicador.modelo = conferido.modelo;
    aplicador.capacidadeMaximaL = conferido.capacidadeMaximaL;
    aplicador.capacidadeMaximaKg = conferido.capacidadeMaximaKg;
    return _aplicadores.salvar(aplicador);
  }

  /// Troca a descrição de uma operação.
  ///
  /// Lança `DadoInvalidoException` se a descrição ficar vazia ou já for de
  /// outra operação, e `RegistroNaoEncontradoException` se a operação não
  /// existir.
  Future<Operacao> corrigirOperacao(int id, {required String descricao}) async {
    final operacao = await _operacoes.exigirPorId(id, 'operação');
    final conferida = Operacao(descricao: descricao);
    final outra = await _operacoes.buscarPorDescricao(conferida.descricao);
    if (outra != null && !outra.mesmoRegistro(operacao)) {
      throw DadoInvalidoException(
        'descrição da operação',
        'já existe a operação "${outra.descricao}"',
      );
    }
    operacao.descricao = conferida.descricao;
    return _operacoes.salvar(operacao);
  }

  /// Corrige a data, a observação e as doses realizadas de uma aplicação.
  ///
  /// A [data] e a [observacao] são as que a aplicação terá depois (`null` na
  /// observação tira o texto). As [dosesRealizadas] trazem só as doses que
  /// mudam, pelo id do insumo; as outras ficam como estão. Talhões, insumos,
  /// aplicador, operação e doses previstas não mudam: para isso, exclua a
  /// aplicação e registre outra.
  ///
  /// Lança `DoseInvalidaException` se uma dose for negativa, e
  /// `DadoInvalidoException` se um insumo da lista não fizer parte da
  /// aplicação. Em qualquer recusa a aplicação continua como estava.
  Future<Aplicacao> corrigirAplicacao(
    int id, {
    required DateTime data,
    String? observacao,
    Map<int, double> dosesRealizadas = const {},
  }) async {
    final aplicacao = await _aplicacoes.exigirPorId(id, 'aplicação');
    // Primeiro confere todas as doses; só depois altera alguma coisa.
    final mudancas = <(AplicacaoInsumo, double)>[];
    for (final entrada in dosesRealizadas.entries) {
      final item = _itemDoInsumo(aplicacao, entrada.key);
      if (item == null) {
        throw DadoInvalidoException(
          'insumos',
          'o insumo ${entrada.key} não faz parte da aplicação',
        );
      }
      final dose = entrada.value;
      if (!dose.isFinite || dose < 0) {
        throw DoseInvalidaException(dose, item.unidade.texto);
      }
      mudancas.add((item, dose));
    }
    aplicacao.data = data;
    aplicacao.observacao = observacao;
    for (final (item, dose) in mudancas) {
      item.registrarDoseRealizada(dose);
    }
    return _aplicacoes.salvar(aplicacao);
  }

  // ---------------------------------------------------------------------
  // Exclusões
  // ---------------------------------------------------------------------

  /// Exclui uma área que não tem talhões e devolve a área excluída.
  ///
  /// Lança [ExclusaoNegadaException] se ela ainda tiver talhões e
  /// `RegistroNaoEncontradoException` se não existir. Com [apenasConferir],
  /// só confere e não exclui.
  Future<Area> excluirArea(int id, {bool apenasConferir = false}) async {
    final area = await _areas.exigirPorId(id, 'área');
    final talhoes = await _talhoes.listarPorArea(id);
    if (talhoes.isNotEmpty) {
      final nomes = [for (final talhao in talhoes) talhao.nome];
      final tem = talhoes.length == 1
          ? 'tem o talhão ${nomes.first}; exclua-o antes'
          : 'tem os talhões ${_enumerar(nomes)}; exclua-os antes';
      throw ExclusaoNegadaException('área ${area.nome}', tem);
    }
    if (!apenasConferir) {
      await _remover(_areas, id, 'área');
    }
    return area;
  }

  /// Exclui um talhão que nenhuma aplicação usa e devolve o talhão excluído.
  ///
  /// Lança [ExclusaoNegadaException] se alguma aplicação o usar e
  /// `RegistroNaoEncontradoException` se não existir. Com [apenasConferir],
  /// só confere e não exclui.
  Future<Talhao> excluirTalhao(int id, {bool apenasConferir = false}) async {
    final talhao = await _talhoes.exigirPorId(id, 'talhão');
    final usos = await _aplicacoes.listarPorTalhao(id);
    if (usos.isNotEmpty) {
      throw _emUso('talhão ${talhao.nome}', usos);
    }
    if (!apenasConferir) {
      await _remover(_talhoes, id, 'talhão');
    }
    return talhao;
  }

  /// Exclui um insumo que nenhuma aplicação usa e devolve o insumo excluído.
  ///
  /// Lança [ExclusaoNegadaException] se alguma aplicação o usar e
  /// `RegistroNaoEncontradoException` se não existir. Com [apenasConferir],
  /// só confere e não exclui.
  Future<Insumo> excluirInsumo(int id, {bool apenasConferir = false}) async {
    final insumo = await _insumos.exigirPorId(id, 'insumo');
    final usos = await _aplicacoesQue((aplicacao) {
      return aplicacao.insumos.any((item) => item.insumo.id == id);
    });
    if (usos.isNotEmpty) {
      throw _emUso('insumo ${insumo.nome}', usos);
    }
    if (!apenasConferir) {
      await _remover(_insumos, id, 'insumo');
    }
    return insumo;
  }

  /// Exclui um aplicador que nenhuma aplicação usa e devolve o aplicador
  /// excluído.
  ///
  /// Lança [ExclusaoNegadaException] se alguma aplicação o usar e
  /// `RegistroNaoEncontradoException` se não existir. Com [apenasConferir],
  /// só confere e não exclui.
  Future<Aplicador> excluirAplicador(
    int id, {
    bool apenasConferir = false,
  }) async {
    final aplicador = await _aplicadores.exigirPorId(id, 'aplicador');
    final usos = await _aplicacoesQue((aplicacao) {
      return aplicacao.aplicador.id == id;
    });
    if (usos.isNotEmpty) {
      final nome = '${aplicador.tipo} ${aplicador.modelo ?? aplicador.id}';
      throw _emUso('aplicador $nome', usos);
    }
    if (!apenasConferir) {
      await _remover(_aplicadores, id, 'aplicador');
    }
    return aplicador;
  }

  /// Exclui uma operação que nenhuma aplicação usa e devolve a operação
  /// excluída.
  ///
  /// Lança [ExclusaoNegadaException] se alguma aplicação a usar e
  /// `RegistroNaoEncontradoException` se não existir. Com [apenasConferir],
  /// só confere e não exclui.
  Future<Operacao> excluirOperacao(
    int id, {
    bool apenasConferir = false,
  }) async {
    final operacao = await _operacoes.exigirPorId(id, 'operação');
    final usos = await _aplicacoesQue((aplicacao) {
      return aplicacao.operacao.id == id;
    });
    if (usos.isNotEmpty) {
      throw _emUso('operação ${operacao.descricao}', usos, feminino: true);
    }
    if (!apenasConferir) {
      await _remover(_operacoes, id, 'operação');
    }
    return operacao;
  }

  /// Exclui uma aplicação, com os seus talhões e insumos, e devolve a
  /// aplicação excluída. Nenhum cadastro (talhão, insumo...) é afetado.
  ///
  /// Lança `RegistroNaoEncontradoException` se a aplicação não existir. Com
  /// [apenasConferir], só confere que ela existe e não exclui.
  Future<Aplicacao> excluirAplicacao(
    int id, {
    bool apenasConferir = false,
  }) async {
    final aplicacao = await _aplicacoes.exigirPorId(id, 'aplicação');
    if (!apenasConferir) {
      await _remover(_aplicacoes, id, 'aplicação');
    }
    return aplicacao;
  }

  // ---------------------------------------------------------------------
  // Apoio
  // ---------------------------------------------------------------------

  AplicacaoInsumo? _itemDoInsumo(Aplicacao aplicacao, int insumoId) {
    for (final item in aplicacao.insumos) {
      if (item.insumo.id == insumoId) {
        return item;
      }
    }
    return null;
  }

  Future<List<Aplicacao>> _aplicacoesQue(
    bool Function(Aplicacao aplicacao) usa,
  ) async {
    final todas = await _aplicacoes.listarTodos();
    return [
      for (final aplicacao in todas)
        if (usa(aplicacao)) aplicacao,
    ];
  }

  /// Remove pelo repositório; se o registro já tinha sumido, avisa.
  Future<void> _remover(
    Repository<Entidade> repositorio,
    int id,
    String entidade,
  ) async {
    final removido = await repositorio.remover(id);
    if (!removido) {
      throw RegistroNaoEncontradoException(entidade, id);
    }
  }

  /// A recusa de exclusão por uso. O particípio concorda com o registro:
  /// "usado" ou, com [feminino], "usada".
  ExclusaoNegadaException _emUso(
    String registro,
    List<Aplicacao> aplicacoes, {
    bool feminino = false,
  }) {
    final participio = feminino ? 'usada' : 'usado';
    final ids = [for (final aplicacao in aplicacoes) '${aplicacao.id}'];
    final motivo = aplicacoes.length == 1
        ? '$participio na aplicação ${ids.first}; exclua-a antes'
        : '$participio nas aplicações ${_enumerar(ids)}; exclua-as antes';
    return ExclusaoNegadaException(registro, motivo);
  }

  /// Junta os [itens] em texto corrido: `a`, `a e b`, `a, b e c`. Com mais de
  /// cinco, mostra cinco e conta o resto: `a, b, c, d, e e mais 3`.
  String _enumerar(List<String> itens) {
    const maximo = 5;
    if (itens.length > maximo) {
      final mostrados = itens.take(maximo).join(', ');
      return '$mostrados e mais ${itens.length - maximo}';
    }
    if (itens.length == 1) {
      return itens.first;
    }
    final inicio = itens.sublist(0, itens.length - 1).join(', ');
    return '$inicio e ${itens.last}';
  }

  bool _mesmoTexto(String a, String b) {
    return a.trim().toLowerCase() == b.trim().toLowerCase();
  }
}
