import 'package:caderno_fazenda/exceptions/agrogestor_exception.dart';

/// Roda [acao] e devolve a mensagem da exceção do sistema que ela lançou.
///
/// Devolve null se nada foi lançado. Erros de outros tipos passam direto e
/// fazem o teste falhar.
String? mensagemDoErro(void Function() acao) {
  try {
    acao();
  } on AgroGestorException catch (erro) {
    return erro.mensagem;
  }
  return null;
}

/// Versão de [mensagemDoErro] para ações assíncronas.
Future<String?> mensagemDoErroAsync(Future<void> Function() acao) async {
  try {
    await acao();
  } on AgroGestorException catch (erro) {
    return erro.mensagem;
  }
  return null;
}
