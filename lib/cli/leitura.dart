/// Funções que transformam o que o usuário digitou em número, data e lista.
///
/// Todas devolvem null quando o texto não faz sentido, para o menu perguntar
/// de novo em vez de quebrar.
library;

final RegExp _padraoNumero = RegExp(r'^-?\d+([.,]\d+)?$');
final RegExp _padraoData = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$');
final RegExp _padraoSeparador = RegExp(r'[\s,;]+');

/// Lê um número escrito com vírgula ou ponto decimal: `2,8` e `2.8` dão 2.8.
///
/// Aceita o sinal de menos (as funções de cálculo sabem recusar valores
/// negativos). Não aceita separador de milhar, letras nem texto vazio.
double? lerNumero(String texto) {
  final limpo = texto.trim();
  if (!_padraoNumero.hasMatch(limpo)) {
    return null;
  }
  return double.parse(limpo.replaceAll(',', '.'));
}

/// Lê uma data escrita como dia/mês/ano (`06/11/2026`).
///
/// Devolve null se o texto estiver em outro formato ou se a data não existir
/// (`31/02/2026`).
DateTime? lerData(String texto) {
  final partes = _padraoData.firstMatch(texto.trim());
  if (partes == null) {
    return null;
  }
  final dia = int.parse(partes.group(1)!);
  final mes = int.parse(partes.group(2)!);
  final ano = int.parse(partes.group(3)!);
  final data = DateTime(ano, mes, dia);
  // O DateTime "corrige" datas impossíveis (31/02 vira 03/03): se o dia ou o
  // mês mudou, a data digitada não existe.
  if (data.day != dia || data.month != mes || data.year != ano) {
    return null;
  }
  return data;
}

/// Lê uma lista de números inteiros separados por vírgula, ponto e vírgula ou
/// espaço: `1,2` e `1 2` dão [1, 2]. Devolve null se algum item não for inteiro
/// ou se a lista estiver vazia.
List<int>? lerIds(String texto) {
  final partes = texto
      .split(_padraoSeparador)
      .where((parte) => parte.isNotEmpty)
      .toList();
  if (partes.isEmpty) {
    return null;
  }
  final ids = <int>[];
  for (final parte in partes) {
    final id = int.tryParse(parte);
    if (id == null) {
      return null;
    }
    ids.add(id);
  }
  return ids;
}

/// Lê uma resposta de sim ou não: `s` e `sim` dão true; `n`, `nao` e `não`
/// dão false. Devolve null para qualquer outra coisa.
bool? lerSimNao(String texto) {
  switch (texto.trim().toLowerCase()) {
    case 's':
    case 'sim':
      return true;
    case 'n':
    case 'nao':
    case 'não':
      return false;
    default:
      return null;
  }
}
