import 'dart:io';

import 'package:caderno_fazenda/exceptions/agrogestor_exception.dart';
import 'package:caderno_fazenda/exceptions/persistencia_exception.dart';
import 'package:caderno_fazenda/logica/alertas_operacionais.dart';
import 'package:caderno_fazenda/models/aplicador.dart';
import 'package:caderno_fazenda/models/area.dart';
import 'package:caderno_fazenda/models/drone.dart';
import 'package:caderno_fazenda/models/insumo.dart';
import 'package:caderno_fazenda/models/operacao.dart';
import 'package:caderno_fazenda/models/talhao.dart';
import 'package:caderno_fazenda/repositories/configuracao_banco.dart';
import 'package:caderno_fazenda/repositories/interfaces/aplicacao_repository.dart';
import 'package:caderno_fazenda/repositories/interfaces/aplicador_repository.dart';
import 'package:caderno_fazenda/repositories/interfaces/area_repository.dart';
import 'package:caderno_fazenda/repositories/interfaces/insumo_repository.dart';
import 'package:caderno_fazenda/repositories/interfaces/operacao_repository.dart';
import 'package:caderno_fazenda/repositories/interfaces/talhao_repository.dart';
import 'package:caderno_fazenda/repositories/memoria/repositorios_memoria.dart';
import 'package:caderno_fazenda/repositories/mysql/aplicacao_repository_mysql.dart';
import 'package:caderno_fazenda/repositories/mysql/aplicador_repository_mysql.dart';
import 'package:caderno_fazenda/repositories/mysql/area_repository_mysql.dart';
import 'package:caderno_fazenda/repositories/mysql/conexao_mysql.dart';
import 'package:caderno_fazenda/repositories/mysql/insumo_repository_mysql.dart';
import 'package:caderno_fazenda/repositories/mysql/operacao_repository_mysql.dart';
import 'package:caderno_fazenda/repositories/mysql/talhao_repository_mysql.dart';
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
/// volume de calda, aplica as regras de chuva e de sobredose e totaliza o
/// desperdício. No fim, provoca erros de propósito para mostrar o tratamento
/// de exceções.
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
    await _demonstracao(_Repositorios.memoria());
    return;
  }

  ConexaoMysql? banco;
  try {
    banco = await ConexaoMysql.abrir(ConfiguracaoBanco.doAmbiente());
    await _demonstracao(_Repositorios.mysql(banco));
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

/// Os seis repositórios que a demonstração usa, em memória ou no MySQL.
class _Repositorios {
  final String origem;
  final AreaRepository areas;
  final TalhaoRepository talhoes;
  final InsumoRepository insumos;
  final AplicadorRepository aplicadores;
  final OperacaoRepository operacoes;
  final AplicacaoRepository aplicacoes;

  _Repositorios({
    required this.origem,
    required this.areas,
    required this.talhoes,
    required this.insumos,
    required this.aplicadores,
    required this.operacoes,
    required this.aplicacoes,
  });

  factory _Repositorios.memoria() {
    return _Repositorios(
      origem: 'dados em memória',
      areas: AreaRepositoryMemoria(),
      talhoes: TalhaoRepositoryMemoria(),
      insumos: InsumoRepositoryMemoria(),
      aplicadores: AplicadorRepositoryMemoria(),
      operacoes: OperacaoRepositoryMemoria(),
      aplicacoes: AplicacaoRepositoryMemoria(),
    );
  }

  factory _Repositorios.mysql(ConexaoMysql banco) {
    final talhoes = TalhaoRepositoryMysql(banco);
    final insumos = InsumoRepositoryMysql(banco);
    final aplicadores = AplicadorRepositoryMysql(banco);
    final operacoes = OperacaoRepositoryMysql(banco);
    return _Repositorios(
      origem: 'MySQL na AWS',
      areas: AreaRepositoryMysql(banco),
      talhoes: talhoes,
      insumos: insumos,
      aplicadores: aplicadores,
      operacoes: operacoes,
      aplicacoes: AplicacaoRepositoryMysql(
        banco,
        operacoes: operacoes,
        aplicadores: aplicadores,
        talhoes: talhoes,
        insumos: insumos,
      ),
    );
  }
}

Future<void> _demonstracao(_Repositorios repositorios) async {
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
  final sede =
      await areas.buscarPorNome('Sede') ??
      await areas.salvar(Area(nome: 'Sede'));
  final idSede = sede.id!;

  Future<Talhao> talhao(String nome, double hectares) async {
    final existente = await talhoes.buscarPorAreaENome(idSede, nome);
    return existente ??
        await talhaoService.cadastrar(
          areaId: idSede,
          nome: nome,
          hectares: hectares,
        );
  }

  final chico1 = await talhao('Chico1', 2.8);
  final chico2 = await talhao('Chico2', 3.8);

  final drone =
      await _acharDrone(aplicadores, 'DJI') ??
      await aplicadores.salvar(
        Drone(modelo: 'DJI', capacidadeMaximaL: 70, capacidadeMaximaKg: 70),
      );
  final operacao =
      await operacoes.buscarPorDescricao('Pulverização') ??
      await operacoes.salvar(Operacao(descricao: 'Pulverização'));
  final orkestra = await _acharInsumo(insumos, 'Orkestra SC', 'Fungicida');
  final boro = await _acharInsumo(insumos, 'Boro Super', 'Fertilizante');
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
    print('    previsto: ${_n(totais.totalPrevisto, 3)} $medida');
    print('    realizado: ${_n(totais.totalRealizado, 3)} $medida');
    print('    desperdício: ${_n(totais.volumeDesperdicado, 3)} $medida');
    print('    percentual: ${_n(totais.percentual, 1)}%');
  }

  _titulo('4. Erros tratados (nada é gravado)');
  Future<void> talhaoRepetido() async {
    await talhaoService.cadastrar(areaId: idSede, nome: 'chico1', hectares: 1);
  }

  await _tentar('taxa de 20 L/ha no drone', () => registrar(20));
  await _tentar('talhão com nome repetido', talhaoRepetido);
  if (aplicacoes is AplicacaoRepositoryMemoria) {
    aplicacoes.bancoIndisponivel = true;
    await _tentar('banco fora do ar', () => registrar(10));
    aplicacoes.bancoIndisponivel = false;
  }

  final gravadas = await aplicacoes.listarTodos();
  print('\nAplicações gravadas ao final: ${gravadas.length}');
}

/// Procura o drone de [modelo] já cadastrado, ou devolve null.
Future<Aplicador?> _acharDrone(
  AplicadorRepository aplicadores,
  String modelo,
) async {
  for (final aplicador in await aplicadores.listarPorTipo('drone')) {
    if (aplicador.modelo == modelo) {
      return aplicador;
    }
  }
  return null;
}

/// Devolve o insumo [nome] do [tipo] dado, cadastrando-o se ainda não existir.
Future<Insumo> _acharInsumo(
  InsumoRepository insumos,
  String nome,
  String tipo,
) async {
  for (final insumo in await insumos.listarPorTipo(tipo)) {
    if (insumo.nome == nome) {
      return insumo;
    }
  }
  return insumos.salvar(Insumo(nome: nome, tipo: tipo));
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
  print('  Aplicação ${aplicacao.id} em ${_data(aplicacao.data)}');
  print('  Aplicador: ${aplicador.descreverCapacidade()}');
  print('  Registrado em: ${aplicador.origemDoRegistro()}');
  print('  Área total: ${_n(aplicacao.areaTotalHa)} ha');

  final volume = resultado.volumeCaldaL;
  if (volume != null) {
    print('  Volume de calda: ${_n(volume)} L');
  }
  final massa = resultado.massaProdutosKg;
  if (massa != null) {
    print('  Massa de produtos sólidos: ${_n(massa)} kg');
  }
  print('  Chuva: ${_textoChuva(resultado.chuva)}');

  for (final avaliacao in resultado.insumos) {
    final item = avaliacao.item;
    final unidade = item.unidade.texto;
    final medida = unidade.split('/').first;
    print('  - ${item.insumo.nome}');
    print('      dose prevista: ${_n(item.dosePrevista, 3)} $unidade');
    final realizada = item.doseRealizada;
    if (realizada != null) {
      print('      dose realizada: ${_n(realizada, 3)} $unidade');
    }
    final prevista = _n(avaliacao.quantidadePrevista, 3);
    print('      quantidade prevista: $prevista $medida');
    final comprar = _n(avaliacao.quantidadeAComprar, 3);
    print('      quantidade a comprar (fator 0,95): $comprar $medida');
    final percentual = avaliacao.percentualDesperdicio;
    if (percentual != null) {
      print('      desperdício: ${_n(percentual, 1)}%');
    }
    print('      sobredose: ${_textoStatus(avaliacao.statusSobredose)}');
  }
}

String _textoChuva(DecisaoChuva? decisao) {
  return switch (decisao) {
    DecisaoChuva.reaplicar => 'choveu antes do limite: REAPLICAR',
    DecisaoChuva.naoReaplicar => 'choveu depois do limite: não reaplicar',
    DecisaoChuva.entradaInvalida => 'horas inválidas',
    null => 'não informada',
  };
}

String _textoStatus(StatusSobredose? status) {
  return switch (status) {
    StatusSobredose.ok => 'ok',
    StatusSobredose.atencao => 'atenção (dentro da tolerância)',
    StatusSobredose.critico => 'CRÍTICO (acima da tolerância)',
    StatusSobredose.entradaInvalida => 'dose inválida',
    null => 'sem dose realizada',
  };
}

void _titulo(String texto) {
  print('\n== $texto ==');
}

/// Número com vírgula decimal, como se escreve no Brasil.
String _n(double valor, [int casas = 2]) {
  return valor.toStringAsFixed(casas).replaceAll('.', ',');
}

String _data(DateTime data) {
  final dia = data.day.toString().padLeft(2, '0');
  final mes = data.month.toString().padLeft(2, '0');
  return '$dia/$mes/${data.year}';
}
