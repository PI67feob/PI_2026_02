import 'dart:io';

import 'package:caderno_fazenda/cli/dados_exemplo.dart';
import 'package:caderno_fazenda/cli/formato.dart';
import 'package:caderno_fazenda/exceptions/agrogestor_exception.dart';
import 'package:caderno_fazenda/exceptions/persistencia_exception.dart';
import 'package:caderno_fazenda/repositories/configuracao_banco.dart';
import 'package:caderno_fazenda/repositories/memoria/repositorios_memoria.dart';
import 'package:caderno_fazenda/repositories/mysql/conexao_mysql.dart';
import 'package:caderno_fazenda/repositories/repositorios.dart';
import 'package:caderno_fazenda/services/aplicacao_service.dart';
import 'package:caderno_fazenda/services/dose_informada.dart';
import 'package:caderno_fazenda/services/parametros_operacionais.dart';
import 'package:caderno_fazenda/services/resultado_aplicacao.dart';
import 'package:caderno_fazenda/services/talhao_service.dart';

/// Demonstração do Caderno de Campo no terminal.
///
/// Sem argumento (`dart run bin/main.dart`), usa os repositórios provisórios
/// em memória e não precisa de banco. Com `--mysql`
/// (`dart run bin/main.dart --mysql`), grava no MySQL da AWS: as variáveis
/// `DB_*` precisam estar exportadas e o `global-bundle.pem` na raiz do projeto
/// (veja `.env.example`).
///
/// O programa cadastra dados de exemplo da fazenda e registra uma aplicação,
/// mostrando o que o sistema decide em cada passo: converte as doses, calcula o
/// volume de calda e as viagens do aplicador, aplica as regras de chuva e de
/// sobredose e totaliza o desperdício. No fim, provoca erros de propósito para
/// mostrar o tratamento de exceções.
///
/// Os cadastros (área, talhões, aplicador, operação e insumos) só são criados
/// se ainda não existirem, então dá para rodar `--mysql` várias vezes sem
/// duplicar nada. Cada execução registra uma nova aplicação, e o banco guarda
/// as das execuções anteriores.
///
/// As doses, a taxa e a tolerância são só exemplos para a demonstração: os
/// valores reais vêm das fichas da fazenda e do agrônomo.
Future<void> main(List<String> argumentos) async {
  if (!argumentos.contains('--mysql')) {
    await _demonstracao(Repositorios.memoria());
    return;
  }

  ConexaoMysql? banco;
  try {
    banco = await ConexaoMysql.abrir(ConfiguracaoBanco.doAmbiente());
    await _demonstracao(Repositorios.mysql(banco));
  } on PersistenciaException catch (erro) {
    stderr.writeln('\nFALHOU: ${erro.mensagem}');
    stderr.writeln('Causa técnica: ${erro.causa}');
    exitCode = 1;
  } on AgroGestorException catch (erro) {
    stderr.writeln('\nFALHOU: $erro');
    exitCode = 1;
  } finally {
    await banco?.fechar();
  }
}

Future<void> _demonstracao(Repositorios repositorios) async {
  _titulo('Caderno de Campo - demonstração (${repositorios.origem})');

  final areas = repositorios.areas;
  final talhoes = repositorios.talhoes;
  final insumos = repositorios.insumos;
  final aplicadores = repositorios.aplicadores;
  final operacoes = repositorios.operacoes;
  final aplicacoes = repositorios.aplicacoes;

  // A tolerância é só um exemplo: quem define o valor é o agrônomo.
  final parametros = ParametrosOperacionais(toleranciaSobredosePercentual: 10);
  final talhaoService = TalhaoService(areas, talhoes);
  final aplicacaoService = AplicacaoService(
    operacoes,
    aplicadores,
    talhoes,
    insumos,
    aplicacoes,
    parametros,
  );

  _titulo('1. Cadastros');
  final exemplo = await garantirDadosExemplo(repositorios);
  final idSede = exemplo.sede.id!;
  final chico1 = exemplo.chico1;
  final chico2 = exemplo.chico2;
  final drone = exemplo.drone;
  final operacao = exemplo.operacao;
  final orkestra = exemplo.orkestra;
  final boro = exemplo.boro;
  print('  ${chico1.obterDados()}');
  print('  ${chico2.obterDados()}');
  print('  ${drone.descreverCapacidade()}');

  // As doses chegam como estão na ficha de papel, em unidades diferentes:
  // o serviço converte tudo para L/ha (líquido) ou kg/ha (sólido).
  final doseOrkestra = DoseInformada(
    insumoId: orkestra.id!,
    dosePrevista: 300,
    doseRealizada: 345,
    unidade: 'mL/ha',
  );
  final doseBoro = DoseInformada(
    insumoId: boro.id!,
    dosePrevista: 500,
    doseRealizada: 450,
    unidade: 'g/ha',
  );

  Future<ResultadoAplicacao> registrar(double taxa, {double? chuva}) {
    return aplicacaoService.registrar(
      data: DateTime(2026, 11, 6),
      operacaoId: operacao.id!,
      aplicadorId: drone.id!,
      talhaoIds: [chico1.id!, chico2.id!],
      doses: [doseOrkestra, doseBoro],
      taxaLitrosPorHa: taxa,
      horasAteChuva: chuva,
    );
  }

  _titulo('2. Registro de uma aplicação (fluxo principal)');
  final resultado = await registrar(10, chuva: 2.5);
  _mostrar(resultado);

  _titulo('3. Resumo de desperdício (todas as aplicações gravadas)');
  final resumo = await aplicacaoService.resumoDesperdicio();
  for (final totais in resumo.values) {
    final medida = totais.unidade.split('/').first;
    print('  ${totais.unidade}');
    print('    previsto: ${formatarNumero(totais.totalPrevisto, 3)} $medida');
    print('    realizado: ${formatarNumero(totais.totalRealizado, 3)} $medida');
    print(
      '    desperdício: ${formatarNumero(totais.volumeDesperdicado, 3)} $medida',
    );
    print('    percentual: ${formatarNumero(totais.percentual, 1)}%');
  }

  // A capacidade do drone vale por voo: passar dela não é erro, só pede mais
  // viagens. Aqui só se calcula a carga; nada é gravado.
  _titulo('4. Aplicação com mais de uma viagem (só calcula, não grava)');
  final carga = await aplicacaoService.calcularCarga(
    aplicadorId: drone.id!,
    talhaoIds: [chico1.id!, chico2.id!],
    doses: [doseOrkestra, doseBoro],
    taxaLitrosPorHa: 20,
  );
  final volumeGrande = carga.volumeCaldaL;
  if (volumeGrande != null) {
    print('  Taxa de 20 L/ha: calda de ${formatarNumero(volumeGrande)} L');
    final viagens = descreverViagens(
      carga.viagensCalda,
      drone.capacidadeMaximaL,
      'L',
    );
    print('  Viagens da calda: $viagens');
  }

  _titulo('5. Erros tratados (nada é gravado)');
  Future<void> talhaoRepetido() async {
    await talhaoService.cadastrar(areaId: idSede, nome: 'chico1', hectares: 1);
  }

  await _tentar('taxa de aplicação zero', () => registrar(0));
  await _tentar('talhão com nome repetido', talhaoRepetido);
  if (aplicacoes is AplicacaoRepositoryMemoria) {
    aplicacoes.bancoIndisponivel = true;
    await _tentar('banco fora do ar', () => registrar(10));
    aplicacoes.bancoIndisponivel = false;
  }

  final gravadas = await aplicacoes.listarTodos();
  print('\nAplicações gravadas ao final: ${gravadas.length}');
}

/// Executa [acao] e mostra a mensagem se o sistema recusar a operação.
Future<void> _tentar(String descricao, Future<void> Function() acao) async {
  try {
    await acao();
    print('  $descricao: aceito');
  } on AgroGestorException catch (erro) {
    print('  $descricao -> $erro');
  }
}

/// Mostra o que o serviço calculou para a aplicação.
void _mostrar(ResultadoAplicacao resultado) {
  final aplicacao = resultado.aplicacao;
  final aplicador = aplicacao.aplicador;
  print('  Aplicação ${aplicacao.id} em ${formatarData(aplicacao.data)}');
  print('  Aplicador: ${aplicador.descreverCapacidade()}');
  print('  Registrado em: ${aplicador.origemDoRegistro()}');
  print('  Área total: ${formatarNumero(aplicacao.areaTotalHa)} ha');

  final volume = resultado.volumeCaldaL;
  if (volume != null) {
    print('  Volume de calda: ${formatarNumero(volume)} L');
    final capacidade = aplicador.capacidadeMaximaL;
    final viagens = descreverViagens(resultado.viagensCalda, capacidade, 'L');
    print('  Viagens da calda: $viagens');
  }
  final massa = resultado.massaProdutosKg;
  if (massa != null) {
    print('  Massa de produtos sólidos: ${formatarNumero(massa)} kg');
    final capacidade = aplicador.capacidadeMaximaKg;
    final viagens = descreverViagens(
      resultado.viagensSolidos,
      capacidade,
      'kg',
    );
    print('  Viagens dos sólidos: $viagens');
  }
  print('  Chuva: ${descreverChuva(resultado.chuva)}');

  for (final avaliacao in resultado.insumos) {
    final item = avaliacao.item;
    final unidade = item.unidade.texto;
    final medida = unidade.split('/').first;
    print('  - ${item.insumo.nome}');
    print(
      '      dose prevista: ${formatarNumero(item.dosePrevista, 3)} $unidade',
    );
    final realizada = item.doseRealizada;
    if (realizada != null) {
      print('      dose realizada: ${formatarNumero(realizada, 3)} $unidade');
    }
    final prevista = formatarNumero(avaliacao.quantidadePrevista, 3);
    print('      quantidade prevista: $prevista $medida');
    final comprar = formatarNumero(avaliacao.quantidadeAComprar, 3);
    print('      quantidade a comprar (fator 0,95): $comprar $medida');
    final percentual = avaliacao.percentualDesperdicio;
    if (percentual != null) {
      print('      desperdício: ${formatarNumero(percentual, 1)}%');
    }
    print('      sobredose: ${descreverSobredose(avaliacao.statusSobredose)}');
  }
}

void _titulo(String texto) {
  print('\n== $texto ==');
}
