import 'package:caderno_fazenda/cli/formato.dart';
import 'package:caderno_fazenda/cli/interacao.dart';
import 'package:caderno_fazenda/logica/alertas_operacionais.dart';
import 'package:caderno_fazenda/logica/calculo_desperdicio.dart';
import 'package:caderno_fazenda/logica/calculos_calda.dart';
import 'package:caderno_fazenda/logica/normalizacao_dose.dart';
import 'package:caderno_fazenda/services/parametros_operacionais.dart';

/// A calculadora: uma opção para cada função de `lib/logica`.
///
/// Mostra as funções puras de lógica de programação funcionando uma a uma, sem
/// passar por serviço nem por banco: o usuário digita as entradas, a função
/// responde. Quando a função recusa o valor (área negativa, unidade
/// desconhecida, conversão entre massa e volume), a exceção própria dela chega
/// até [Interacao.executarProtegido], que mostra a mensagem.
///
/// Os valores padrão de tolerância, limite da chuva e fator de compra vêm dos
/// parâmetros operacionais em uso no menu, por isso [_parametros] é uma função:
/// se o usuário mudar os parâmetros, a calculadora enxerga a mudança.
class MenuCalculadora {
  final Interacao _ui;
  final ParametrosOperacionais Function() _parametros;

  MenuCalculadora(this._ui, this._parametros);

  /// Abre o menu da calculadora e só volta quando o usuário escolher sair.
  Future<void> executar() {
    return _ui.menu('CALCULADORA (funções de lib/logica)', [
      OpcaoMenu('Volume de calda (área x taxa)', _volumeDaCalda),
      OpcaoMenu('Quantidade de produto por hectare', _produtoPorHectare),
      OpcaoMenu(
        'Quantidade de produto por 1000 L de calda',
        _produtoPor1000Litros,
      ),
      OpcaoMenu(
        'Normalizar uma dose (líquido para L/ha, sólido para kg/ha)',
        _normalizarDose,
      ),
      OpcaoMenu('Converter unidades (mL, L, g, kg, ton)', _converter),
      OpcaoMenu('Chuva: precisa reaplicar?', _chuva),
      OpcaoMenu('Capacidade: quantas viagens o aplicador faz?', _capacidade),
      OpcaoMenu('Sobredose: passou do previsto?', _sobredose),
      OpcaoMenu('Desvio e percentual de desperdício', _desperdicio),
      OpcaoMenu('Quantidade a comprar (fator de compra)', _quantidadeAComprar),
    ], dica: 'Cada opção chama uma função da lógica. Enter em branco cancela.');
  }

  /// Pergunta os [rotulos] em ordem e devolve os números digitados, ou null se
  /// o usuário cancelou (Enter em branco) em alguma pergunta.
  ///
  /// Não impõe mínimo: quem recusa valor negativo ou zero é a própria função
  /// de cálculo, e a calculadora existe para mostrar essa recusa.
  List<double>? _pedirNumeros(List<String> rotulos) {
    final valores = <double>[];
    for (final rotulo in rotulos) {
      final valor = _ui.perguntarNumero(rotulo);
      if (valor == null) {
        return null;
      }
      valores.add(valor);
    }
    return valores;
  }

  Future<void> _volumeDaCalda() async {
    _ui.linha('\nFunção: volumeCalda (calculos_calda.dart) = área x taxa');
    final valores = _pedirNumeros(['Área (ha)', 'Taxa de aplicação (L/ha)']);
    if (valores == null) {
      return;
    }
    final [area, taxa] = valores;
    final volume = volumeCalda(area, taxa);
    _ui.linha('Volume de calda: ${formatarNumero(volume)} L');
  }

  Future<void> _produtoPorHectare() async {
    _ui.linha(
      '\nFunção: quantidadeProdutoPorHa (calculos_calda.dart) = área x dose',
    );
    final valores = _pedirNumeros(['Área (ha)', 'Dose por hectare']);
    if (valores == null) {
      return;
    }
    final [area, dose] = valores;
    final quantidade = quantidadeProdutoPorHa(area, dose);
    _ui.linha(
      'Quantidade de produto: ${formatarCompacto(quantidade)} '
      '(na mesma unidade da dose, por exemplo L ou kg)',
    );
  }

  Future<void> _produtoPor1000Litros() async {
    _ui.linha(
      '\nFunção: quantidadeProdutoPor1000L (calculos_calda.dart) '
      '= volume / 1000 x dose',
    );
    final valores = _pedirNumeros([
      'Volume de calda (L)',
      'Dose para cada 1000 L de calda',
    ]);
    if (valores == null) {
      return;
    }
    final [volume, dose] = valores;
    final quantidade = quantidadeProdutoPor1000L(volume, dose);
    _ui.linha(
      'Quantidade de produto: ${formatarCompacto(quantidade)} '
      '(na mesma unidade da dose, por exemplo L ou kg)',
    );
  }

  Future<void> _normalizarDose() async {
    _ui.linha('\nFunção: normalizarDoseInformada (normalizacao_dose.dart)');
    _ui.linha('  Líquido: L/ha, mL/ha, L/1000L  ->  L/ha (normalizarDose)');
    _ui.linha('  Sólido:  kg/ha, g/ha  ->  kg/ha (normalizarDoseMassa)');
    _ui.linha('  kg/1000L e g/1000L ainda estão pendentes com o agrônomo.');
    final dose = _ui.perguntarNumero('Dose');
    if (dose == null) {
      return;
    }
    final unidade = _ui.perguntarTexto('Unidade da dose');
    if (unidade == null) {
      return;
    }
    final taxa = _ui.perguntarNumero(
      'Taxa de aplicação (L/ha), só entra na conta em L/1000L',
    );
    if (taxa == null) {
      return;
    }
    final normalizada = normalizarDoseInformada(dose, unidade, taxa);
    final entrada = formatarCompacto(dose, 6);
    final saida = formatarCompacto(normalizada.valor, 6);
    _ui.linha('$entrada $unidade = $saida ${normalizada.unidade}');
  }

  Future<void> _converter() async {
    _ui.linha('\nFunção: converterUnidade (calculos_calda.dart)');
    _ui.linha('  Volume: ml, l.  Massa: g, kg, ton.');
    _ui.linha('  De volume para massa (ou o contrário) precisa da densidade.');
    final valor = _ui.perguntarNumero('Valor');
    if (valor == null) {
      return;
    }
    final origem = _ui.perguntarTexto('De (ml, l, g, kg ou ton)');
    if (origem == null) {
      return;
    }
    final destino = _ui.perguntarTexto('Para (ml, l, g, kg ou ton)');
    if (destino == null) {
      return;
    }
    final resultado = converterUnidade(valor, origem, destino);
    final entrada = formatarCompacto(valor, 6);
    final saida = formatarCompacto(resultado, 6);
    _ui.linha('$entrada $origem = $saida $destino');
  }

  Future<void> _chuva() async {
    final limitePadrao = _parametros().limiteChuvaHoras;
    _ui.linha('\nFunção: avaliarChuva (alertas_operacionais.dart)');
    _ui.linha('  Chuva em menos horas que o limite: reaplicar.');
    final horas = _ui.perguntarNumero(
      'Horas entre o fim da aplicação e a chuva',
    );
    if (horas == null) {
      return;
    }
    final limite =
        _ui.perguntarNumero(
          'Limite em horas [Enter = ${formatarCompacto(limitePadrao)}]',
        ) ??
        limitePadrao;
    _ui.linha('  Chuva exatamente no limite: a fazenda ainda não definiu.');
    final noLimite = _ui.confirmar(
      'Reaplicar se a chuva vier exatamente no limite?',
    );
    final decisao = avaliarChuva(
      horas,
      limiteHoras: limite,
      reaplicarNoLimite: noLimite,
    );
    _ui.linha('Resultado: ${descreverChuva(decisao)}');
  }

  Future<void> _capacidade() async {
    _ui.linha(
      '\nFunções: avaliarCapacidade (alertas_operacionais.dart) e '
      'viagensNecessarias (calculos_calda.dart)',
    );
    _ui.linha(
      '  A capacidade vale por viagem: passar dela só pede mais viagens.',
    );
    final valores = _pedirNumeros([
      'Volume de calda (L)',
      'Capacidade máxima do aplicador por viagem (L)',
    ]);
    if (valores == null) {
      return;
    }
    final [volume, capacidade] = valores;
    final resultado = avaliarCapacidade(volume, capacidade);
    _ui.linha('Resultado: ${descreverResultadoCapacidade(resultado)}');
    if (resultado != ResultadoCapacidade.entradaInvalida) {
      final viagens = viagensNecessarias(volume, capacidade);
      final texto = descreverViagens(viagens, capacidade, 'L');
      _ui.linha('Viagens necessárias: $texto');
    }
  }

  Future<void> _sobredose() async {
    final toleranciaPadrao = _parametros().toleranciaSobredosePercentual;
    _ui.linha('\nFunção: avaliarSobredose (alertas_operacionais.dart)');
    _ui.linha(
      '  As duas doses precisam estar na mesma unidade (L/ha ou kg/ha).',
    );
    final valores = _pedirNumeros(['Dose prevista', 'Dose realizada']);
    if (valores == null) {
      return;
    }
    final [prevista, realizada] = valores;
    final tolerancia =
        _ui.perguntarNumero(
          'Tolerância em % [Enter = ${formatarCompacto(toleranciaPadrao)}]',
        ) ??
        toleranciaPadrao;
    final status = avaliarSobredose(
      prevista,
      realizada,
      toleranciaPercentual: tolerancia,
    );
    _ui.linha('Resultado: ${descreverSobredose(status)}');
    if (status != StatusSobredose.entradaInvalida) {
      final excesso = percentualDesperdicio(prevista, realizada);
      _ui.linha('Excesso sobre o previsto: ${formatarNumero(excesso, 1)}%');
    }
  }

  Future<void> _desperdicio() async {
    _ui.linha(
      '\nFunções: desvioDose e percentualDesperdicio '
      '(calculo_desperdicio.dart)',
    );
    _ui.linha(
      '  As duas doses precisam estar na mesma unidade (L/ha ou kg/ha).',
    );
    final valores = _pedirNumeros(['Dose prevista', 'Dose realizada']);
    if (valores == null) {
      return;
    }
    final [prevista, realizada] = valores;
    final desvio = desvioDose(prevista, realizada);
    _ui.linha('Desvio (realizada - prevista): ${formatarCompacto(desvio)}');
    final percentual = percentualDesperdicio(prevista, realizada);
    _ui.linha('Percentual de desperdício: ${formatarNumero(percentual, 1)}%');
    if (desvio < 0) {
      _ui.linha('  Aplicar menos que o previsto não conta como desperdício.');
    }
  }

  Future<void> _quantidadeAComprar() async {
    final fatorPadrao = _parametros().fatorCompra;
    _ui.linha('\nFunção: quantidadeAComprar (calculo_desperdicio.dart)');
    final quantidade = _ui.perguntarNumero('Quantidade calculada (L ou kg)');
    if (quantidade == null) {
      return;
    }
    final fator =
        _ui.perguntarNumero(
          'Fator de compra [Enter = ${formatarCompacto(fatorPadrao, 2)}]',
        ) ??
        fatorPadrao;
    final comprar = quantidadeAComprar(quantidade, fator: fator);
    _ui.linha('Quantidade a comprar: ${formatarCompacto(comprar, 3)}');
  }
}
