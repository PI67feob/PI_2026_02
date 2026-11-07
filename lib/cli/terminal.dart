import 'dart:convert';
import 'dart:io';

/// Entrada e saída de texto do menu.
///
/// O menu só conversa com o usuário por esta interface. No programa de verdade
/// quem responde é o [TerminalConsole] (teclado e tela); nos testes entra um
/// terminal com respostas prontas, e o menu roda sem ninguém digitando.
abstract interface class Terminal {
  /// Escreve [texto] sem pular a linha. Usado nas perguntas.
  void escrever(String texto);

  /// Escreve [texto] e pula a linha.
  void escreverLinha([String texto = '']);

  /// Lê uma linha digitada pelo usuário.
  ///
  /// Devolve null quando a entrada acaba: Ctrl+D no Linux e no macOS, Ctrl+Z
  /// seguido de Enter no Windows, ou um arquivo redirecionado que chegou ao
  /// fim.
  String? lerLinha();
}

/// O terminal de verdade: lê do teclado e escreve na tela.
class TerminalConsole implements Terminal {
  const TerminalConsole();

  // Lê em UTF-8 e, se chegar um byte inválido, troca por "�" em vez de
  // derrubar o programa. Isso acontece no Windows com acento digitado e sem
  // `chcp 65001`.
  static const _codificacao = Utf8Codec(allowMalformed: true);

  @override
  void escrever(String texto) {
    stdout.write(texto);
  }

  @override
  void escreverLinha([String texto = '']) {
    stdout.writeln(texto);
  }

  @override
  String? lerLinha() {
    return stdin.readLineSync(encoding: _codificacao);
  }
}

/// Sinal de que a entrada acabou no meio de uma pergunta.
///
/// Quem conversa com o usuário deixa passar; o menu principal captura e
/// encerra o programa com educação.
class EntradaEncerrada implements Exception {
  const EntradaEncerrada();

  @override
  String toString() => 'EntradaEncerrada: a entrada de texto acabou';
}
