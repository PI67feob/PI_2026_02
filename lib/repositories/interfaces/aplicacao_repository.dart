import 'package:caderno_fazenda/models/aplicacao.dart';
import 'package:caderno_fazenda/repositories/interfaces/repository.dart';

/// Persistência das aplicações (tabelas `aplicacao`, `aplicacao_talhao` e
/// `aplicacao_insumo`).
///
/// Uma [Aplicacao] ocupa três tabelas. Na versão MySQL, `salvar` precisa
/// gravar as três dentro de uma transação: ou grava tudo, ou não grava nada.
abstract interface class AplicacaoRepository implements Repository<Aplicacao> {
  /// Lista as aplicações que incluem o talhão [talhaoId], em ordem crescente
  /// de id.
  Future<List<Aplicacao>> listarPorTalhao(int talhaoId);

  /// Lista as aplicações feitas entre os dias [de] e [ate], inclusive.
  /// O horário dos dois parâmetros é ignorado.
  Future<List<Aplicacao>> listarPorPeriodo(DateTime de, DateTime ate);
}
