import 'package:caderno_fazenda/cli/terminal.dart';

/// Terminal de mentira para os testes do menu: lê respostas de uma lista e
/// guarda tudo o que o programa escreveu.
///
/// Cada resposta lida também é copiada para a [saida], como acontece na tela
/// de verdade, para o texto ficar na ordem em que o usuário veria.
class TerminalSimulado implements Terminal {
  final List<String> _respostas;
  final StringBuffer _saida = StringBuffer();
  int _proxima = 0;

  /// Cria o terminal com as [respostas] que o "usuário" vai digitar, na
  /// ordem. Quando elas acabam, a entrada se encerra (como um Ctrl+D).
  TerminalSimulado(List<String> respostas) : _respostas = List.of(respostas);

  /// Tudo o que o programa escreveu e o que foi "digitado", em ordem.
  String get saida => _saida.toString();

  /// Quantas respostas ainda não foram lidas.
  int get respostasRestantes => _respostas.length - _proxima;

  @override
  void escrever(String texto) {
    _saida.write(texto);
  }

  @override
  void escreverLinha([String texto = '']) {
    _saida.writeln(texto);
  }

  @override
  String? lerLinha() {
    if (_proxima >= _respostas.length) {
      return null;
    }
    final resposta = _respostas[_proxima];
    _proxima++;
    _saida.writeln(resposta);
    return resposta;
  }
}
