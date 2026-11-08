import 'package:caderno_fazenda/logica/alertas_operacionais.dart';
import 'package:caderno_fazenda/models/aplicacao.dart';
import 'package:caderno_fazenda/models/insumo.dart';
import 'package:caderno_fazenda/models/talhao.dart';

/// Número com [casas] casas decimais fixas e vírgula, como se escreve no
/// Brasil: `formatarNumero(2.8)` devolve `2,80`.
String formatarNumero(double valor, [int casas = 2]) {
  return valor.toStringAsFixed(casas).replaceAll('.', ',');
}

/// Número com no máximo [maximoCasas] casas, sem zeros sobrando à direita:
/// `10` vira `10` e `0.3450` vira `0,345`.
String formatarCompacto(double valor, [int maximoCasas = 4]) {
  var texto = valor.toStringAsFixed(maximoCasas);
  if (texto.contains('.')) {
    texto = texto.replaceFirst(RegExp(r'0+$'), '');
    texto = texto.replaceFirst(RegExp(r'\.$'), '');
  }
  if (texto == '-0') {
    texto = '0';
  }
  return texto.replaceAll('.', ',');
}

/// Data no formato dia/mês/ano: `06/11/2026`.
String formatarData(DateTime data) {
  final dia = data.day.toString().padLeft(2, '0');
  final mes = data.month.toString().padLeft(2, '0');
  return '$dia/$mes/${data.year}';
}

/// Texto da decisão da regra da chuva. `null` quando a chuva não foi
/// informada.
String descreverChuva(DecisaoChuva? decisao) {
  return switch (decisao) {
    DecisaoChuva.reaplicar => 'choveu antes do limite: REAPLICAR',
    DecisaoChuva.naoReaplicar => 'choveu depois do limite: não reaplicar',
    DecisaoChuva.entradaInvalida => 'horas inválidas',
    null => 'não informada',
  };
}

/// Texto do resultado da regra da sobredose. `null` quando a dose realizada
/// não foi informada.
String descreverSobredose(StatusSobredose? status) {
  return switch (status) {
    StatusSobredose.ok => 'ok',
    StatusSobredose.atencao => 'atenção (dentro da tolerância)',
    StatusSobredose.critico => 'CRÍTICO (acima da tolerância)',
    StatusSobredose.entradaInvalida => 'dose inválida',
    null => 'sem dose realizada',
  };
}

/// Texto do resultado da regra da capacidade do aplicador.
String descreverResultadoCapacidade(ResultadoCapacidade resultado) {
  return switch (resultado) {
    ResultadoCapacidade.dentroDaCapacidade => 'cabe numa viagem só',
    ResultadoCapacidade.excedeu =>
      'não cabe numa viagem só (precisa de mais de uma)',
    ResultadoCapacidade.entradaInvalida =>
      'valores inválidos (volume negativo ou capacidade zero)',
  };
}

/// Texto das viagens que o aplicador faz para levar uma carga.
///
/// [viagens] é nulo quando o aplicador não tem capacidade cadastrada para a
/// [unidade] (`L` ou `kg`): aí o cálculo não é possível. Com [viagens] e
/// [capacidade] informados, o texto é como `2 viagens (até 70 L por viagem)`.
String descreverViagens(int? viagens, double? capacidade, String unidade) {
  if (viagens == null || capacidade == null) {
    return 'não calculadas (aplicador sem capacidade em $unidade)';
  }
  final quantas = viagens == 1 ? '1 viagem' : '$viagens viagens';
  return '$quantas (até ${formatarCompacto(capacidade)} $unidade por viagem)';
}

/// Escolhe entre o [singular] e o [plural] conforme a [quantidade]:
/// `plural(1, 'talhão', 'talhões')` devolve `talhão`.
String plural(int quantidade, String singular, String plural) {
  return quantidade == 1 ? singular : plural;
}

/// Um insumo em uma linha: `Orkestra SC (Fungicida)` ou, com marca,
/// `Orkestra SC (Fungicida, BASF)`.
String descreverInsumo(Insumo insumo) {
  final marca = insumo.marca;
  if (marca == null) {
    return '${insumo.nome} (${insumo.tipo})';
  }
  return '${insumo.nome} (${insumo.tipo}, $marca)';
}

/// Um talhão em uma linha: `Sede / Chico1 - 2,80 ha`.
String descreverTalhao(Talhao talhao) {
  return '${talhao.area.nome} / ${talhao.nome} - '
      '${formatarNumero(talhao.hectares)} ha';
}

/// Uma aplicação em uma linha, para escolher em uma lista:
/// `06/11/2026 | Pulverização | drone | Chico1, Chico2 (6,60 ha) | 2 insumos`.
String descreverAplicacao(Aplicacao aplicacao) {
  final talhoes = aplicacao.talhoes.map((t) => t.nome).join(', ');
  final area = formatarNumero(aplicacao.areaTotalHa);
  final quantidade = aplicacao.insumos.length;
  final palavra = plural(quantidade, 'insumo', 'insumos');
  return '${formatarData(aplicacao.data)} | ${aplicacao.operacao.descricao} | '
      '${aplicacao.aplicador.tipo} | $talhoes ($area ha) | '
      '$quantidade $palavra';
}
