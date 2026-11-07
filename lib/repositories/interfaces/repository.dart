import 'package:caderno_fazenda/exceptions/registro_nao_encontrado_exception.dart';
import 'package:caderno_fazenda/models/entidade.dart';

/// Contrato básico de persistência de uma entidade.
///
/// É por aqui que a regra de negócio conversa com o banco sem conhecê-lo: os
/// serviços só enxergam esta interface. Hoje quem a implementa é a versão em
/// memória (`lib/repositories/memoria`); a versão MySQL entra depois, em
/// `lib/repositories/mysql`, sem mudar uma linha dos serviços.
///
/// Todos os métodos são assíncronos (devolvem `Future`) porque os drivers de
/// MySQL para Dart são assíncronos. Qualquer falha de comunicação com o banco
/// vira `PersistenciaException`: erro técnico do driver não pode vazar.
abstract interface class Repository<T extends Entidade> {
  /// Grava a [entidade] e a devolve já com o id definido.
  ///
  /// Sem id, é uma inserção e o repositório gera o id. Com id, é uma
  /// atualização do registro que tem esse id.
  Future<T> salvar(T entidade);

  /// Procura o registro pelo [id]; devolve null se ele não existir.
  Future<T?> buscarPorId(int id);

  /// Lista todos os registros, em ordem crescente de id.
  Future<List<T>> listarTodos();

  /// Remove o registro de [id]. Devolve true se ele existia.
  Future<bool> remover(int id);
}

/// Atalho usado pelos serviços: busca pelo id e falha se não achar.
extension BuscaObrigatoria<T extends Entidade> on Repository<T> {
  /// Devolve o registro de [id].
  ///
  /// Lança [RegistroNaoEncontradoException] (com o nome da [entidade] na
  /// mensagem) se ele não existir.
  Future<T> exigirPorId(int id, String entidade) async {
    final encontrado = await buscarPorId(id);
    if (encontrado == null) {
      throw RegistroNaoEncontradoException(entidade, id);
    }
    return encontrado;
  }
}
