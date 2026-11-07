/// Classe-base de todas as exceções de regra de negócio do AgroGestor.
///
/// Os serviços capturam [AgroGestorException] para mostrar ao usuário uma
/// mensagem clara, sem expor detalhes técnicos.
///
/// Padrão das mensagens: começa com o tipo do erro, seguido de dois-pontos e
/// do valor recebido. Exemplo: `Dose inválida: -2 L/ha`.
///
/// As exceções de cálculo de calda (`CaldaException` e filhas) ficam em
/// `lib/logica` e não estendem esta classe; o serviço faz a tradução entre as
/// duas famílias.
abstract class AgroGestorException implements Exception {
  /// Mensagem pronta para ser mostrada ao usuário.
  final String mensagem;

  /// Cria a exceção com a [mensagem] já formatada no padrão do projeto.
  const AgroGestorException(this.mensagem);

  @override
  String toString() => mensagem;
}
