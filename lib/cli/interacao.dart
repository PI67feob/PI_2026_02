import 'dart:math';

import 'package:caderno_fazenda/cli/formato.dart';
import 'package:caderno_fazenda/cli/leitura.dart';
import 'package:caderno_fazenda/cli/terminal.dart';
import 'package:caderno_fazenda/exceptions/agrogestor_exception.dart';
import 'package:caderno_fazenda/exceptions/persistencia_exception.dart';
import 'package:caderno_fazenda/logica/calculo_desperdicio.dart';
import 'package:caderno_fazenda/logica/calculos_calda.dart';
import 'package:caderno_fazenda/models/entidade.dart';

/// Uma linha de menu: o texto que aparece e o que acontece ao escolhê-la.
class OpcaoMenu {
  final String texto;
  final Future<void> Function() acao;

  const OpcaoMenu(this.texto, this.acao);
}

/// A conversa com o usuário: perguntas, listas de escolha e menus.
///
/// Tudo o que o menu pergunta passa por aqui, e é aqui que a resposta é
/// conferida. Se o usuário digita algo que não serve (letra onde era número,
/// id que não existe, data impossível), a pergunta se repete em vez de o
/// programa quebrar. Em toda pergunta, Enter sem escrever nada devolve null:
/// quem chamou decide se isso cancela a operação ou pula um campo opcional.
class Interacao {
  /// Largura mínima da moldura dos títulos.
  static const int _larguraMinima = 50;

  final Terminal _terminal;
  final bool _pausas;
  int _menusAbertos = 0;
  bool _ultimaEmBranco = false;

  /// Com [pausas] ligadas, depois de cada opção do menu o programa espera um
  /// Enter antes de desenhar o menu de novo, para o resultado não sumir da
  /// tela. Fica desligado por padrão: com a entrada vinda de um arquivo ou de
  /// um teste, ninguém está lá para apertar Enter.
  Interacao(this._terminal, {this._pausas = false});

  /// Escreve uma linha.
  ///
  /// Uma linha em branco logo depois de outra é descartada: assim cada trecho
  /// do programa pode começar e terminar com a sua folga sem que o espaço
  /// entre dois trechos dobre.
  void linha([String texto = '']) {
    if (texto.isEmpty) {
      if (_ultimaEmBranco) {
        return;
      }
      _ultimaEmBranco = true;
    } else {
      _ultimaEmBranco = false;
    }
    _terminal.escreverLinha(texto);
  }

  /// Escreve um título de seção, em moldura e separado do que veio antes e
  /// do que vem depois.
  void secao(String texto) {
    final largura = max(_larguraMinima, texto.length + 6);
    linha();
    linha('=' * largura);
    linha('  $texto');
    linha('=' * largura);
    linha();
  }

  /// Escreve um subtítulo sublinhado, separado do que veio antes.
  void subtitulo(String texto) {
    linha();
    linha(texto);
    linha('-' * texto.length);
  }

  /// Escreve o título de um passo de uma tarefa longa ("Passo 2 de 6 -
  /// Aplicador"), para o usuário saber em que ponto está.
  void etapa(int numero, int total, String titulo) {
    subtitulo('Passo $numero de $total - $titulo');
  }

  /// Escreve uma mensagem de que algo deu certo, com uma linha em branco
  /// antes para destacar.
  void sucesso(String texto) {
    linha();
    linha('  [ok] $texto');
  }

  /// Escreve um aviso (algo não foi feito, ou pede atenção), com uma linha em
  /// branco antes.
  void aviso(String texto) {
    linha();
    linha('  [!] $texto');
  }

  /// Espera o usuário apertar Enter, para ele ler a tela com calma.
  ///
  /// Lança [EntradaEncerrada] se a entrada acabou.
  void pausar([String texto = 'Aperte Enter para continuar']) {
    _ultimaEmBranco = false;
    _terminal.escrever('\n$texto... ');
    if (_terminal.lerLinha() == null) {
      throw const EntradaEncerrada();
    }
  }

  /// Faz uma pergunta e devolve a resposta sem espaços nas pontas, vazia se o
  /// usuário só apertou Enter.
  ///
  /// Lança [EntradaEncerrada] se a entrada acabou.
  String perguntar(String rotulo) {
    _ultimaEmBranco = false;
    _terminal.escrever('$rotulo: ');
    final resposta = _terminal.lerLinha();
    if (resposta == null) {
      throw const EntradaEncerrada();
    }
    return resposta.trim();
  }

  /// Pergunta um texto livre. Devolve null se o usuário só apertou Enter.
  String? perguntarTexto(String rotulo) {
    final resposta = perguntar(rotulo);
    return resposta.isEmpty ? null : resposta;
  }

  /// Pergunta um número, com vírgula ou ponto decimal.
  ///
  /// Repete a pergunta se a resposta não for número ou se não respeitar o
  /// [minimo] (maior que o mínimo se [exclusivo], maior ou igual se não).
  /// Devolve null se o usuário só apertou Enter.
  double? perguntarNumero(
    String rotulo, {
    double? minimo,
    bool exclusivo = false,
  }) {
    while (true) {
      final resposta = perguntar(rotulo);
      if (resposta.isEmpty) {
        return null;
      }
      final valor = _conferirNumero(resposta, minimo, exclusivo);
      if (valor != null) {
        return valor;
      }
    }
  }

  /// Converte a [resposta] em número e confere o [minimo]. Se não servir,
  /// avisa o que está errado e devolve null (quem chamou pergunta de novo).
  double? _conferirNumero(String resposta, double? minimo, bool exclusivo) {
    final valor = lerNumero(resposta);
    if (valor == null) {
      linha('  Número inválido. Use só dígitos, com vírgula ou ponto (2,8).');
      return null;
    }
    if (minimo != null) {
      final valido = exclusivo ? valor > minimo : valor >= minimo;
      if (!valido) {
        final regra = exclusivo ? 'maior que' : 'pelo menos';
        linha('  O valor precisa ser $regra ${formatarCompacto(minimo)}.');
        return null;
      }
    }
    return valor;
  }

  // ---------------------------------------------------------------------
  // Corrigir um valor que já existe: Enter mantém o valor atual
  // ---------------------------------------------------------------------

  /// Pergunta o novo valor de um texto obrigatório. Enter mantém o [atual].
  String editarTexto(String rotulo, String atual) {
    final resposta = perguntar('$rotulo [atual: $atual; Enter = manter]');
    return resposta.isEmpty ? atual : resposta;
  }

  /// Pergunta o novo valor de um texto opcional. Enter mantém o [atual] e
  /// um traço (`-`) apaga o texto, devolvendo null.
  String? editarTextoOpcional(String rotulo, String? atual) {
    final mostrado = atual ?? 'vazio';
    final resposta = perguntar(
      '$rotulo [atual: $mostrado; Enter = manter; - = apagar]',
    );
    if (resposta.isEmpty) {
      return atual;
    }
    return resposta == '-' ? null : resposta;
  }

  /// Mostra as [opcoes] numeradas e pergunta qual passa a valer. [atual] é a
  /// posição (a partir de 0) da opção de hoje, ou null se não há nenhuma.
  /// Enter mantém a atual e `-` tira a escolha (devolve null). Repete a
  /// pergunta se a resposta não for um número da lista.
  int? editarOpcaoOpcional(String rotulo, List<String> opcoes, int? atual) {
    for (var i = 0; i < opcoes.length; i++) {
      linha('  ${i + 1}. ${opcoes[i]}');
    }
    final mostrado = atual == null ? 'nenhum' : opcoes[atual];
    while (true) {
      final resposta = perguntar(
        '$rotulo [atual: $mostrado; Enter = manter; - = tirar]',
      );
      if (resposta.isEmpty) {
        return atual;
      }
      if (resposta == '-') {
        return null;
      }
      final numero = int.tryParse(resposta);
      if (numero != null && numero >= 1 && numero <= opcoes.length) {
        return numero - 1;
      }
      linha(
        '  Escolha um número de 1 a ${opcoes.length}, - para tirar ou Enter '
        'para manter.',
      );
    }
  }

  /// Pergunta o novo valor de um número. Enter mantém o [atual]. Repete a
  /// pergunta se a resposta não for número ou não respeitar o [minimo].
  double editarNumero(
    String rotulo,
    double atual, {
    double? minimo,
    bool exclusivo = false,
  }) {
    while (true) {
      final resposta = perguntar(
        '$rotulo [atual: ${formatarCompacto(atual)}; Enter = manter]',
      );
      if (resposta.isEmpty) {
        return atual;
      }
      final valor = _conferirNumero(resposta, minimo, exclusivo);
      if (valor != null) {
        return valor;
      }
    }
  }

  /// Pergunta o novo valor de um número opcional, que pode estar vazio.
  /// Enter mantém o [atual] e um traço (`-`) apaga o valor, devolvendo null.
  /// Repete a pergunta se a resposta não servir.
  double? editarNumeroOpcional(
    String rotulo,
    double? atual, {
    double? minimo,
    bool exclusivo = false,
  }) {
    final mostrado = atual == null ? 'vazio' : formatarCompacto(atual);
    while (true) {
      final resposta = perguntar(
        '$rotulo [atual: $mostrado; Enter = manter; - = apagar]',
      );
      if (resposta.isEmpty) {
        return atual;
      }
      if (resposta == '-') {
        return null;
      }
      final valor = _conferirNumero(resposta, minimo, exclusivo);
      if (valor != null) {
        return valor;
      }
    }
  }

  /// Pergunta a nova data (dia/mês/ano). Enter mantém a [atual]. Repete a
  /// pergunta se a data não existir.
  DateTime editarData(String rotulo, DateTime atual) {
    while (true) {
      final resposta = perguntar(
        '$rotulo [atual: ${formatarData(atual)}; Enter = manter]',
      );
      if (resposta.isEmpty) {
        return atual;
      }
      final data = lerData(resposta);
      if (data != null) {
        return data;
      }
      linha(
        '  Data inválida. Use dia/mês/ano, por exemplo ${formatarData(atual)}.',
      );
    }
  }

  /// Pergunta sim ou não. Enter sem resposta vale [padrao]. Repete a pergunta
  /// se não entender a resposta.
  bool confirmar(String rotulo, {bool padrao = false}) {
    final dica = padrao ? 'S/n' : 's/N';
    while (true) {
      final resposta = perguntar('$rotulo ($dica)');
      if (resposta.isEmpty) {
        return padrao;
      }
      final sim = lerSimNao(resposta);
      if (sim != null) {
        return sim;
      }
      linha('  Responda com s (sim) ou n (não).');
    }
  }

  /// Pergunta uma data como dia/mês/ano. Enter sem resposta vale [hoje].
  /// Repete a pergunta se a data não existir.
  DateTime perguntarData(String rotulo, DateTime hoje) {
    final padrao = DateTime(hoje.year, hoje.month, hoje.day);
    while (true) {
      final resposta = perguntar('$rotulo [Enter = ${formatarData(padrao)}]');
      if (resposta.isEmpty) {
        return padrao;
      }
      final data = lerData(resposta);
      if (data != null) {
        return data;
      }
      linha(
        '  Data inválida. Use dia/mês/ano, por exemplo ${formatarData(padrao)}.',
      );
    }
  }

  /// Lista os [itens] com o id de cada um e pede que o usuário digite o id de
  /// um deles. Repete a pergunta se o id não estiver na lista. Devolve null
  /// se o usuário só apertou Enter.
  T? escolherPorId<T extends Entidade>(
    String rotulo,
    List<T> itens,
    String Function(T item) descrever,
  ) {
    for (final item in itens) {
      linha('  [${item.id}] ${descrever(item)}');
    }
    while (true) {
      final resposta = perguntar(rotulo);
      if (resposta.isEmpty) {
        return null;
      }
      final id = int.tryParse(resposta);
      final escolhido = id == null ? null : _acharPorId(itens, id);
      if (escolhido != null) {
        return escolhido;
      }
      linha('  Esse id não está na lista. Digite um dos números entre [ ].');
    }
  }

  /// Igual a [escolherPorId], mas aceita vários ids de uma vez (`1,2`).
  /// Repete a pergunta se algum id não estiver na lista ou aparecer duas vezes.
  List<T>? escolherVariosPorId<T extends Entidade>(
    String rotulo,
    List<T> itens,
    String Function(T item) descrever,
  ) {
    for (final item in itens) {
      linha('  [${item.id}] ${descrever(item)}');
    }
    while (true) {
      final resposta = perguntar(rotulo);
      if (resposta.isEmpty) {
        return null;
      }
      final ids = lerIds(resposta);
      if (ids == null) {
        linha('  Digite os ids separados por vírgula (por exemplo 1,2).');
        continue;
      }
      if (ids.toSet().length != ids.length) {
        linha('  Há um id repetido. Digite cada um só uma vez.');
        continue;
      }
      final escolhidos = <T>[];
      int? desconhecido;
      for (final id in ids) {
        final achado = _acharPorId(itens, id);
        if (achado == null) {
          desconhecido = id;
          break;
        }
        escolhidos.add(achado);
      }
      if (desconhecido != null) {
        linha('  O id $desconhecido não está na lista.');
        continue;
      }
      return escolhidos;
    }
  }

  /// Mostra as [opcoes] numeradas a partir de 1 e devolve a posição (a partir
  /// de 0) da escolhida. Devolve null se o usuário só apertou Enter.
  int? escolherOpcao(String rotulo, List<String> opcoes) {
    for (var i = 0; i < opcoes.length; i++) {
      linha('  ${i + 1}. ${opcoes[i]}');
    }
    while (true) {
      final resposta = perguntar(rotulo);
      if (resposta.isEmpty) {
        return null;
      }
      final numero = int.tryParse(resposta);
      if (numero != null && numero >= 1 && numero <= opcoes.length) {
        return numero - 1;
      }
      linha('  Escolha um número de 1 a ${opcoes.length}.');
    }
  }

  /// Mostra um menu e executa a opção escolhida, de novo e de novo, até o
  /// usuário digitar 0.
  ///
  /// Cada opção roda dentro de [executarProtegido]: se der erro, a mensagem
  /// aparece e o menu continua. A [dica] aparece logo abaixo do título.
  Future<void> menu(
    String titulo,
    List<OpcaoMenu> opcoes, {
    String saida = 'Voltar',
    String? dica,
  }) async {
    _menusAbertos++;
    while (true) {
      secao(titulo);
      if (dica != null) {
        linha(dica);
        linha();
      }
      for (var i = 0; i < opcoes.length; i++) {
        linha('  ${i + 1}. ${opcoes[i].texto}');
      }
      linha();
      linha('  0. $saida');
      linha();
      final numero = _perguntarOpcaoDoMenu(opcoes.length);
      if (numero == 0) {
        return;
      }
      linha();
      final abertosAntes = _menusAbertos;
      await executarProtegido(opcoes[numero - 1].acao);
      // Se a opção abriu outro menu, quem fecha aquele já deu a pausa que
      // precisava: pausar de novo aqui seria só uma tecla a mais.
      if (_pausas && _menusAbertos == abertosAntes) {
        pausar('Aperte Enter para voltar ao menu');
      }
    }
  }

  /// Pergunta a opção do menu até vir um número de 0 a [quantidade]. Em caso
  /// de engano, avisa e pergunta de novo sem desenhar o menu outra vez.
  int _perguntarOpcaoDoMenu(int quantidade) {
    while (true) {
      final resposta = perguntar('Escolha uma opção');
      final numero = int.tryParse(resposta);
      if (numero != null && numero >= 0 && numero <= quantidade) {
        return numero;
      }
      aviso('Opção inválida. Digite o número de uma das opções.');
      linha();
    }
  }

  /// Roda [acao] e, se o sistema recusar a operação, mostra o motivo em vez de
  /// derrubar o programa.
  ///
  /// Trata os quatro grupos de erro que existem no projeto:
  /// - [PersistenciaException]: falha ao falar com o banco;
  /// - [AgroGestorException]: regra do domínio (dado inválido, registro que
  ///   não existe...);
  /// - [CaldaException] e [DesperdicioException]: as funções de cálculo da
  ///   lógica de programação, que têm exceções próprias;
  /// - qualquer outra [Exception], para o menu nunca fechar por um imprevisto.
  ///
  /// Só deixa passar a [EntradaEncerrada], que é o fim da conversa.
  Future<void> executarProtegido(Future<void> Function() acao) async {
    try {
      await acao();
    } on EntradaEncerrada {
      rethrow;
    } on PersistenciaException catch (erro) {
      aviso('Não foi possível acessar os dados: ${erro.mensagem}');
      linha('      Causa técnica: ${erro.causa}');
    } on AgroGestorException catch (erro) {
      aviso('Não foi possível concluir: $erro');
    } on CaldaException catch (erro) {
      aviso('Erro de cálculo: ${erro.message}');
    } on DesperdicioException catch (erro) {
      aviso('Erro de cálculo: ${erro.message}');
    } on Exception catch (erro) {
      aviso('Erro inesperado: $erro');
    }
  }

  T? _acharPorId<T extends Entidade>(List<T> itens, int id) {
    for (final item in itens) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }
}
