import 'package:caderno_fazenda/logica/alertas_operacionais.dart';

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
    ResultadoCapacidade.dentroDaCapacidade => 'cabe no aplicador',
    ResultadoCapacidade.excedeu => 'EXCEDEU a capacidade do aplicador',
    ResultadoCapacidade.entradaInvalida =>
      'valores inválidos (volume negativo ou capacidade zero)',
  };
}
