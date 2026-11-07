import 'package:caderno_fazenda/exceptions/talhao_invalido_exception.dart';
import 'package:caderno_fazenda/models/talhao.dart';
import 'package:caderno_fazenda/repositories/interfaces/area_repository.dart';
import 'package:caderno_fazenda/repositories/interfaces/repository.dart';
import 'package:caderno_fazenda/repositories/interfaces/talhao_repository.dart';

/// Regras de negócio dos talhões.
///
/// Conhece só as interfaces de repositório, nunca o banco. A regra principal
/// é a de unicidade: o nome do talhão só pode se repetir em áreas diferentes.
class TalhaoService {
  final AreaRepository _areas;
  final TalhaoRepository _talhoes;

  /// Cria o serviço com os repositórios de áreas e de talhões.
  TalhaoService(this._areas, this._talhoes);

  /// Cadastra um talhão numa área que já existe.
  ///
  /// Lança `RegistroNaoEncontradoException` se a área não existir,
  /// [TalhaoInvalidoException] se já houver um talhão com o mesmo nome na área
  /// ou se os hectares não forem maiores que zero, e `DadoInvalidoException`
  /// se o nome estiver vazio.
  Future<Talhao> cadastrar({
    required int areaId,
    required String nome,
    required double hectares,
    int? id,
  }) async {
    final area = await _areas.exigirPorId(areaId, 'área');
    final existente = await _talhoes.buscarPorAreaENome(areaId, nome);
    if (existente != null) {
      throw TalhaoInvalidoException(nome, motivo: 'já existe nesta área');
    }
    final talhao = Talhao(nome: nome, hectares: hectares, area: area, id: id);
    return _talhoes.salvar(talhao);
  }

  /// Lista os talhões de uma área. Lança `RegistroNaoEncontradoException` se
  /// a área não existir.
  Future<List<Talhao>> listarPorArea(int areaId) async {
    await _areas.exigirPorId(areaId, 'área');
    return _talhoes.listarPorArea(areaId);
  }

  /// Corrige o tamanho de um talhão. Lança [TalhaoInvalidoException] se os
  /// hectares não forem maiores que zero.
  Future<Talhao> corrigirHectares(int talhaoId, double hectares) async {
    final talhao = await _talhoes.exigirPorId(talhaoId, 'talhão');
    talhao.hectares = hectares;
    return _talhoes.salvar(talhao);
  }
}
