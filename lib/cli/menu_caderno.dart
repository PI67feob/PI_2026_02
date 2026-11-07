import 'package:caderno_fazenda/cli/dados_exemplo.dart';
import 'package:caderno_fazenda/cli/formato.dart';
import 'package:caderno_fazenda/cli/interacao.dart';
import 'package:caderno_fazenda/cli/menu_calculadora.dart';
import 'package:caderno_fazenda/cli/terminal.dart';
import 'package:caderno_fazenda/exceptions/capacidade_excedida_exception.dart';
import 'package:caderno_fazenda/logica/alertas_operacionais.dart';
import 'package:caderno_fazenda/logica/calculo_desperdicio.dart';
import 'package:caderno_fazenda/models/aplicacao.dart';
import 'package:caderno_fazenda/models/aplicador_fabrica.dart';
import 'package:caderno_fazenda/models/area.dart';
import 'package:caderno_fazenda/models/insumo.dart';
import 'package:caderno_fazenda/models/operacao.dart';
import 'package:caderno_fazenda/models/talhao.dart';
import 'package:caderno_fazenda/repositories/repositorios.dart';
import 'package:caderno_fazenda/services/aplicacao_service.dart';
import 'package:caderno_fazenda/services/dose_informada.dart';
import 'package:caderno_fazenda/services/parametros_operacionais.dart';
import 'package:caderno_fazenda/services/resultado_aplicacao.dart';
import 'package:caderno_fazenda/services/talhao_service.dart';

/// Tolerância de sobredose usada até alguém mudá-la em "Parâmetros".
///
/// É só um exemplo, o mesmo da demonstração: quem define o valor aceitável é o
/// agrônomo.
const double toleranciaDeExemplo = 10;

/// As unidades em que uma dose pode ser digitada, como estão na ficha de papel.
const List<String> _unidadesDeDose = [
  'mL/ha',
  'L/ha',
  'L/1000L',
  'g/ha',
  'kg/ha',
];

/// O menu interativo do Caderno de Campo.
///
/// Junta tudo o que o projeto tem em um programa que dá para usar: cadastros
/// pelos modelos (`Area`, `Talhao`, `Insumo`, `Aplicador` e suas subclasses,
/// `Operacao`), o registro de aplicação pelo `AplicacaoService`, as consultas
/// pelos repositórios e a calculadora, que chama direto as funções de
/// `lib/logica`.
///
/// O menu não sabe de onde vêm os dados: recebe os [Repositorios] (memória ou
/// MySQL) e um [Terminal] (teclado e tela, ou respostas prontas nos testes).
/// Quando o sistema recusa uma operação, a mensagem aparece e o menu continua.
class MenuCaderno {
  final Repositorios _repositorios;
  final Interacao _ui;
  final DateTime Function() _agora;
  ParametrosOperacionais _parametros;

  /// Cria o menu sobre [repositorios], conversando pelo [terminal].
  ///
  /// Os [parametros] começam com a [toleranciaDeExemplo], o limite de 3 horas
  /// de chuva e o fator de compra de 0,95, e o usuário pode alterá-los no
  /// menu. O relógio [agora] existe para os testes fixarem a data de hoje.
  MenuCaderno(
    this._repositorios,
    Terminal terminal, {
    ParametrosOperacionais? parametros,
    DateTime Function()? agora,
  }) : _ui = Interacao(terminal),
       _agora = agora ?? DateTime.now,
       _parametros =
           parametros ??
           ParametrosOperacionais(
             toleranciaSobredosePercentual: toleranciaDeExemplo,
           );

  TalhaoService get _talhaoService {
    return TalhaoService(_repositorios.areas, _repositorios.talhoes);
  }

  AplicacaoService get _aplicacaoService {
    return AplicacaoService(
      _repositorios.operacoes,
      _repositorios.aplicadores,
      _repositorios.talhoes,
      _repositorios.insumos,
      _repositorios.aplicacoes,
      _parametros,
    );
  }

  /// Mostra o menu principal e só volta quando o usuário sair (opção 0) ou a
  /// entrada de texto acabar.
  Future<void> executar() async {
    _boasVindas();
    try {
      await _ui.menu('MENU PRINCIPAL', [
        OpcaoMenu(
          'Cadastros (área, talhão, insumo, aplicador, operação)',
          _menuCadastros,
        ),
        OpcaoMenu('Registrar aplicação', _registrarAplicacao),
        OpcaoMenu('Consultas (listar cadastros e aplicações)', _menuConsultas),
        OpcaoMenu('Resumo de desperdício', _resumoDesperdicio),
        OpcaoMenu('Calculadora (funções da lógica)', _abrirCalculadora),
        OpcaoMenu(
          'Parâmetros (tolerância, chuva, fator de compra)',
          _parametrosOperacionais,
        ),
        OpcaoMenu('Carregar dados de exemplo', _carregarExemplo),
      ], saida: 'Sair');
      _ui.linha('\nAté logo!');
    } on EntradaEncerrada {
      _ui.linha('\n\nA entrada de texto acabou. Até logo!');
    }
  }

  void _boasVindas() {
    _ui.linha('==================================================');
    _ui.linha('  CADERNO DE CAMPO - controle de insumos agrícolas');
    _ui.linha('  Dados: ${_repositorios.origem}');
    _ui.linha('==================================================');
    if (!_repositorios.persistente) {
      _ui.linha('Atenção: nada fica salvo, tudo some quando você sair.');
      _ui.linha('Para gravar no banco: dart run bin/caderno.dart --mysql');
    }
    _ui.linha('Primeira vez? Use "Carregar dados de exemplo" (opção 7).');
    final tolerancia = formatarCompacto(
      _parametros.toleranciaSobredosePercentual,
    );
    _ui.linha(
      'Tolerância de sobredose: $tolerancia% (só um exemplo; '
      'mude em "Parâmetros").',
    );
  }

  void _mostrarParametros() {
    final p = _parametros;
    final tolerancia = formatarCompacto(p.toleranciaSobredosePercentual);
    final chuva = formatarCompacto(p.limiteChuvaHoras);
    final compra = formatarCompacto(p.fatorCompra, 2);
    _ui.linha('Parâmetros em uso:');
    _ui.linha(
      '  - tolerância de sobredose: $tolerancia% '
      '(só um exemplo: quem define é o agrônomo)',
    );
    _ui.linha('  - chuva: reaplicar se chover em menos de $chuva h');
    _ui.linha('  - fator de compra: $compra');
  }

  // ---------------------------------------------------------------------
  // Cadastros
  // ---------------------------------------------------------------------

  Future<void> _menuCadastros() {
    return _ui.menu('CADASTROS', [
      OpcaoMenu('Nova área', _novaArea),
      OpcaoMenu('Novo talhão', _novoTalhao),
      OpcaoMenu('Novo insumo', _novoInsumo),
      OpcaoMenu(
        'Novo aplicador (trator, drone ou bomba costal)',
        _novoAplicador,
      ),
      OpcaoMenu('Nova operação', _novaOperacao),
      OpcaoMenu('Corrigir os hectares de um talhão', _corrigirHectares),
    ], dica: 'Enter em branco cancela.');
  }

  Future<void> _novaArea() async {
    final nome = _ui.perguntarTexto('Nome da área (ex.: Sede)');
    if (nome == null) {
      return;
    }
    final existente = await _repositorios.areas.buscarPorNome(nome);
    if (existente != null) {
      _ui.linha('Já existe a área "${existente.nome}" (id ${existente.id}).');
      return;
    }
    final area = await _repositorios.areas.salvar(Area(nome: nome));
    _ui.linha('Área cadastrada: [${area.id}] ${area.nome}');
  }

  Future<void> _novoTalhao() async {
    final areas = await _repositorios.areas.listarTodos();
    if (areas.isEmpty) {
      _ui.linha('Cadastre uma área antes de criar o talhão.');
      return;
    }
    _ui.linha('Áreas:');
    final area = _ui.escolherPorId('Id da área', areas, (a) => a.nome);
    if (area == null) {
      return;
    }
    final nome = _ui.perguntarTexto('Nome do talhão (ex.: Chico1)');
    if (nome == null) {
      return;
    }
    final hectares = _ui.perguntarNumero(
      'Tamanho em hectares',
      minimo: 0,
      exclusivo: true,
    );
    if (hectares == null) {
      return;
    }
    final talhao = await _talhaoService.cadastrar(
      areaId: area.id!,
      nome: nome,
      hectares: hectares,
    );
    _ui.linha('Talhão cadastrado: ${talhao.obterDados()}');
  }

  Future<void> _corrigirHectares() async {
    final talhoes = await _repositorios.talhoes.listarTodos();
    if (talhoes.isEmpty) {
      _ui.linha('Nenhum talhão cadastrado.');
      return;
    }
    _ui.linha('Talhões:');
    final talhao = _ui.escolherPorId('Id do talhão', talhoes, _descreverTalhao);
    if (talhao == null) {
      return;
    }
    final hectares = _ui.perguntarNumero(
      'Novo tamanho em hectares',
      minimo: 0,
      exclusivo: true,
    );
    if (hectares == null) {
      return;
    }
    final corrigido = await _talhaoService.corrigirHectares(
      talhao.id!,
      hectares,
    );
    _ui.linha('Talhão atualizado: ${corrigido.obterDados()}');
  }

  Future<void> _novoInsumo() async {
    final nome = _ui.perguntarTexto('Nome do insumo (ex.: Orkestra SC)');
    if (nome == null) {
      return;
    }
    final tipo = _ui.perguntarTexto('Tipo (ex.: Fungicida, Fertilizante)');
    if (tipo == null) {
      return;
    }
    final marca = _ui.perguntarTexto('Marca [Enter = sem marca]');
    final mesmoTipo = await _repositorios.insumos.listarPorTipo(tipo);
    for (final existente in mesmoTipo) {
      if (_mesmoTexto(existente.nome, nome)) {
        _ui.linha(
          'Já existe o insumo "${existente.nome}" (id ${existente.id}).',
        );
        return;
      }
    }
    final insumo = await _repositorios.insumos.salvar(
      Insumo(nome: nome, tipo: tipo, marca: marca),
    );
    _ui.linha('Insumo cadastrado: [${insumo.id}] ${_descreverInsumo(insumo)}');
  }

  Future<void> _novoAplicador() async {
    const tipos = ['trator', 'drone', 'bomba costal'];
    _ui.linha('Tipo de aplicador:');
    final indice = _ui.escolherOpcao('Tipo', [
      'Trator',
      'Drone',
      'Bomba costal',
    ]);
    if (indice == null) {
      return;
    }
    final modelo = _ui.perguntarTexto('Modelo [Enter = sem modelo]');
    final litros = _ui.perguntarNumero(
      'Capacidade máxima em litros [Enter = não informar]',
      minimo: 0,
      exclusivo: true,
    );
    final quilos = _ui.perguntarNumero(
      'Capacidade máxima em kg [Enter = não informar]',
      minimo: 0,
      exclusivo: true,
    );
    // criarAplicador devolve a subclasse certa (Trator, Drone ou BombaCostal).
    final aplicador = criarAplicador(
      tipos[indice],
      modelo: modelo,
      capacidadeMaximaL: litros,
      capacidadeMaximaKg: quilos,
    );
    final salvo = await _repositorios.aplicadores.salvar(aplicador);
    _ui.linha(
      'Aplicador cadastrado: [${salvo.id}] ${salvo.descreverCapacidade()}',
    );
  }

  Future<void> _novaOperacao() async {
    final descricao = _ui.perguntarTexto(
      'Descrição da operação (ex.: Pulverização)',
    );
    if (descricao == null) {
      return;
    }
    final existente = await _repositorios.operacoes.buscarPorDescricao(
      descricao,
    );
    if (existente != null) {
      _ui.linha(
        'Já existe a operação "${existente.descricao}" (id ${existente.id}).',
      );
      return;
    }
    final operacao = await _repositorios.operacoes.salvar(
      Operacao(descricao: descricao),
    );
    _ui.linha('Operação cadastrada: [${operacao.id}] ${operacao.descricao}');
  }

  // ---------------------------------------------------------------------
  // Registrar aplicação (fluxo principal)
  // ---------------------------------------------------------------------

  Future<void> _registrarAplicacao() async {
    final operacoes = await _repositorios.operacoes.listarTodos();
    final aplicadores = await _repositorios.aplicadores.listarTodos();
    final talhoes = await _repositorios.talhoes.listarTodos();
    final insumos = await _repositorios.insumos.listarTodos();

    final faltam = [
      if (operacoes.isEmpty) 'operação',
      if (aplicadores.isEmpty) 'aplicador',
      if (talhoes.isEmpty) 'talhão',
      if (insumos.isEmpty) 'insumo',
    ];
    if (faltam.isNotEmpty) {
      _ui.linha('Antes de registrar, cadastre: ${faltam.join(', ')}.');
      _ui.linha('Use "Cadastros" ou "Carregar dados de exemplo".');
      return;
    }

    _ui.secao('REGISTRAR APLICAÇÃO');
    _ui.linha('Enter em branco cancela e volta ao menu.');

    _ui.linha('\nOperação:');
    final operacao = _ui.escolherPorId(
      'Id da operação',
      operacoes,
      (o) => o.descricao,
    );
    if (operacao == null) {
      return;
    }

    _ui.linha('\nAplicador:');
    final aplicador = _ui.escolherPorId(
      'Id do aplicador',
      aplicadores,
      (a) => a.descreverCapacidade(),
    );
    if (aplicador == null) {
      return;
    }

    _ui.linha('\nTalhões (um ou mais ids, separados por vírgula):');
    final escolhidos = _ui.escolherVariosPorId(
      'Ids dos talhões',
      talhoes,
      _descreverTalhao,
    );
    if (escolhidos == null) {
      return;
    }
    var areaTotal = 0.0;
    for (final talhao in escolhidos) {
      areaTotal += talhao.hectares;
    }
    _ui.linha('  Área total: ${formatarNumero(areaTotal)} ha');

    _ui.linha();
    final data = _ui.perguntarData('Data da aplicação', _agora());
    final taxaDigitada = _ui.perguntarNumero(
      'Taxa de aplicação da calda (L/ha)',
      minimo: 0,
      exclusivo: true,
    );
    if (taxaDigitada == null) {
      return;
    }
    // Pode ser trocada mais adiante, se a calda não couber no aplicador.
    var taxa = taxaDigitada;

    final itens = <_ItemDigitado>[];
    while (true) {
      final livres = insumos
          .where((i) => !itens.any((item) => item.insumo.mesmoRegistro(i)))
          .toList();
      if (livres.isEmpty) {
        _ui.linha('\nTodos os insumos cadastrados já foram adicionados.');
        break;
      }
      _ui.linha('\nInsumo ${itens.length + 1}:');
      final insumo = _ui.escolherPorId(
        'Id do insumo',
        livres,
        _descreverInsumo,
      );
      if (insumo == null) {
        return;
      }
      final item = _perguntarDose(insumo);
      if (item == null) {
        return;
      }
      itens.add(item);
      if (!_ui.confirmar('Adicionar outro insumo?')) {
        break;
      }
    }

    _ui.linha();
    final horas = _ui.perguntarNumero(
      'Horas entre o fim da aplicação e a chuva [Enter = sem informação]',
      minimo: 0,
    );
    final observacao = _ui.perguntarTexto('Observação [Enter = nenhuma]');

    _conferir(
      data: data,
      operacao: operacao,
      aplicador: aplicador.descreverCapacidade(),
      talhoes: escolhidos,
      areaTotal: areaTotal,
      taxa: taxa,
      itens: itens,
      horas: horas,
      observacao: observacao,
    );
    if (!_ui.confirmar('Gravar esta aplicação?', padrao: true)) {
      _ui.linha('Cancelado. Nada foi gravado.');
      return;
    }

    ResultadoAplicacao resultado;
    while (true) {
      try {
        resultado = await _aplicacaoService.registrar(
          data: data,
          operacaoId: operacao.id!,
          aplicadorId: aplicador.id!,
          talhaoIds: [for (final talhao in escolhidos) talhao.id!],
          doses: [for (final item in itens) item.dose],
          taxaLitrosPorHa: taxa,
          horasAteChuva: horas,
          observacao: observacao,
        );
        break;
      } on CapacidadeExcedidaException catch (erro) {
        _ui.linha('\nNão foi possível registrar: $erro');
        _ui.linha('Nada foi gravado.');
        if (!_ui.confirmar('Tentar de novo com outra taxa de aplicação?')) {
          return;
        }
        final nova = _ui.perguntarNumero(
          'Nova taxa de aplicação (L/ha)',
          minimo: 0,
          exclusivo: true,
        );
        if (nova == null) {
          return;
        }
        taxa = nova;
      }
    }
    _mostrarResultado(resultado);
  }

  _ItemDigitado? _perguntarDose(Insumo insumo) {
    _ui.linha('  Unidade em que a dose está anotada na ficha:');
    final indice = _ui.escolherOpcao('Unidade', _unidadesDeDose);
    if (indice == null) {
      return null;
    }
    final unidade = _unidadesDeDose[indice];
    final prevista = _ui.perguntarNumero(
      'Dose prevista de ${insumo.nome} ($unidade)',
      minimo: 0,
      exclusivo: true,
    );
    if (prevista == null) {
      return null;
    }
    final realizada = _ui.perguntarNumero(
      'Dose realizada ($unidade) [Enter = ainda não aplicada]',
      minimo: 0,
    );
    final dose = DoseInformada(
      insumoId: insumo.id!,
      dosePrevista: prevista,
      doseRealizada: realizada,
      unidade: unidade,
    );
    return _ItemDigitado(insumo, dose);
  }

  void _conferir({
    required DateTime data,
    required Operacao operacao,
    required String aplicador,
    required List<Talhao> talhoes,
    required double areaTotal,
    required double taxa,
    required List<_ItemDigitado> itens,
    required double? horas,
    required String? observacao,
  }) {
    _ui.secao('CONFERIR ANTES DE GRAVAR');
    _ui.linha('  Data: ${formatarData(data)}');
    _ui.linha('  Operação: ${operacao.descricao}');
    _ui.linha('  Aplicador: $aplicador');
    final nomes = talhoes.map((t) => t.nome).join(', ');
    _ui.linha('  Talhões: $nomes (${formatarNumero(areaTotal)} ha)');
    _ui.linha('  Taxa de aplicação: ${formatarCompacto(taxa)} L/ha');
    _ui.linha('  Insumos:');
    for (final item in itens) {
      final dose = item.dose;
      final realizada = dose.doseRealizada;
      final previstaTexto = formatarCompacto(dose.dosePrevista);
      final realizadaTexto = realizada == null
          ? 'ainda não aplicada'
          : 'realizada ${formatarCompacto(realizada)} ${dose.unidade}';
      _ui.linha(
        '   - ${item.insumo.nome}: prevista $previstaTexto ${dose.unidade}, '
        '$realizadaTexto',
      );
    }
    if (horas != null) {
      _ui.linha('  Chuva: ${formatarCompacto(horas)} h depois da aplicação');
    }
    if (observacao != null) {
      _ui.linha('  Observação: $observacao');
    }
  }

  /// Mostra o que o serviço calculou, com os alertas em destaque no fim.
  void _mostrarResultado(ResultadoAplicacao resultado) {
    final aplicacao = resultado.aplicacao;
    final aplicador = aplicacao.aplicador;
    _ui.secao('APLICAÇÃO ${aplicacao.id} REGISTRADA');
    _ui.linha('  Data: ${formatarData(aplicacao.data)}');
    _ui.linha('  Aplicador: ${aplicador.descreverCapacidade()}');
    _ui.linha('  Registrado em: ${aplicador.origemDoRegistro()}');
    _ui.linha('  Área total: ${formatarNumero(aplicacao.areaTotalHa)} ha');
    final volume = resultado.volumeCaldaL;
    if (volume != null) {
      _ui.linha('  Volume de calda: ${formatarNumero(volume)} L');
    }
    final massa = resultado.massaProdutosKg;
    if (massa != null) {
      _ui.linha('  Massa de produtos sólidos: ${formatarNumero(massa)} kg');
    }
    _ui.linha('  Chuva: ${descreverChuva(resultado.chuva)}');

    final alertas = <String>[];
    if (resultado.chuva == DecisaoChuva.reaplicar) {
      final limite = formatarCompacto(_parametros.limiteChuvaHoras);
      alertas.add('Choveu em menos de $limite h: REAPLICAR a aplicação.');
    }
    for (final avaliacao in resultado.insumos) {
      final item = avaliacao.item;
      final unidade = item.unidade.texto;
      final medida = unidade.split('/').first;
      _ui.linha('  - ${item.insumo.nome}');
      _ui.linha(
        '      dose prevista: ${formatarNumero(item.dosePrevista, 3)} $unidade',
      );
      final realizada = item.doseRealizada;
      if (realizada != null) {
        _ui.linha(
          '      dose realizada: ${formatarNumero(realizada, 3)} $unidade',
        );
      }
      final prevista = formatarNumero(avaliacao.quantidadePrevista, 3);
      _ui.linha('      quantidade prevista: $prevista $medida');
      final fator = formatarCompacto(_parametros.fatorCompra, 2);
      final comprar = formatarNumero(avaliacao.quantidadeAComprar, 3);
      _ui.linha('      quantidade a comprar (fator $fator): $comprar $medida');
      final percentual = avaliacao.percentualDesperdicio;
      if (percentual != null) {
        _ui.linha('      desperdício: ${formatarNumero(percentual, 1)}%');
      }
      _ui.linha(
        '      sobredose: ${descreverSobredose(avaliacao.statusSobredose)}',
      );
      final tolerancia = formatarCompacto(
        _parametros.toleranciaSobredosePercentual,
      );
      switch (avaliacao.statusSobredose) {
        case StatusSobredose.atencao:
          alertas.add(
            '${item.insumo.nome}: aplicou mais que o previsto, '
            'dentro da tolerância de $tolerancia%.',
          );
        case StatusSobredose.critico:
          alertas.add(
            '${item.insumo.nome}: SOBREDOSE, acima da tolerância de '
            '$tolerancia%.',
          );
        case StatusSobredose.ok:
        case StatusSobredose.entradaInvalida:
        case null:
          break;
      }
    }

    if (alertas.isEmpty) {
      _ui.linha('  Alertas: nenhum.');
    } else {
      _ui.linha('  ALERTAS:');
      for (final alerta in alertas) {
        _ui.linha('   ! $alerta');
      }
    }
  }

  // ---------------------------------------------------------------------
  // Consultas
  // ---------------------------------------------------------------------

  Future<void> _menuConsultas() {
    return _ui.menu('CONSULTAS', [
      OpcaoMenu('Áreas e talhões', _listarAreasETalhoes),
      OpcaoMenu('Insumos', _listarInsumos),
      OpcaoMenu('Aplicadores', _listarAplicadores),
      OpcaoMenu('Operações', _listarOperacoes),
      OpcaoMenu('Aplicações registradas', _listarAplicacoes),
    ]);
  }

  Future<void> _listarAreasETalhoes() async {
    final areas = await _repositorios.areas.listarTodos();
    if (areas.isEmpty) {
      _ui.linha('Nenhuma área cadastrada.');
      return;
    }
    for (final area in areas) {
      final talhoes = await _repositorios.talhoes.listarPorArea(area.id!);
      var total = 0.0;
      for (final talhao in talhoes) {
        total += talhao.hectares;
      }
      final quantidade = talhoes.length;
      final palavra = _plural(quantidade, 'talhão', 'talhões');
      _ui.linha(
        '[${area.id}] ${area.nome} - $quantidade $palavra, '
        '${formatarNumero(total)} ha',
      );
      for (final talhao in talhoes) {
        _ui.linha(
          '     [${talhao.id}] ${talhao.nome} - '
          '${formatarNumero(talhao.hectares)} ha',
        );
      }
    }
  }

  Future<void> _listarInsumos() async {
    final insumos = await _repositorios.insumos.listarTodos();
    if (insumos.isEmpty) {
      _ui.linha('Nenhum insumo cadastrado.');
      return;
    }
    for (final insumo in insumos) {
      _ui.linha('[${insumo.id}] ${_descreverInsumo(insumo)}');
    }
  }

  Future<void> _listarAplicadores() async {
    final aplicadores = await _repositorios.aplicadores.listarTodos();
    if (aplicadores.isEmpty) {
      _ui.linha('Nenhum aplicador cadastrado.');
      return;
    }
    for (final aplicador in aplicadores) {
      // Cada subclasse responde do seu jeito (polimorfismo).
      _ui.linha('[${aplicador.id}] ${aplicador.descreverCapacidade()}');
      _ui.linha('     registro: ${aplicador.origemDoRegistro()}');
    }
  }

  Future<void> _listarOperacoes() async {
    final operacoes = await _repositorios.operacoes.listarTodos();
    if (operacoes.isEmpty) {
      _ui.linha('Nenhuma operação cadastrada.');
      return;
    }
    for (final operacao in operacoes) {
      _ui.linha('[${operacao.id}] ${operacao.descricao}');
    }
  }

  Future<void> _listarAplicacoes() async {
    final aplicacoes = await _repositorios.aplicacoes.listarTodos();
    if (aplicacoes.isEmpty) {
      _ui.linha('Nenhuma aplicação registrada.');
      return;
    }
    final escolhida = _ui.escolherPorId(
      'Id da aplicação para ver os detalhes [Enter = voltar]',
      aplicacoes,
      _descreverAplicacao,
    );
    if (escolhida != null) {
      _detalharAplicacao(escolhida);
    }
  }

  void _detalharAplicacao(Aplicacao aplicacao) {
    final aplicador = aplicacao.aplicador;
    _ui.secao('APLICAÇÃO ${aplicacao.id}');
    _ui.linha('  Data: ${formatarData(aplicacao.data)}');
    _ui.linha('  Operação: ${aplicacao.operacao.descricao}');
    _ui.linha('  Aplicador: ${aplicador.descreverCapacidade()}');
    _ui.linha('  Registrado em: ${aplicador.origemDoRegistro()}');
    final talhoes = aplicacao.talhoes
        .map((t) => '${t.nome} (${formatarNumero(t.hectares)} ha)')
        .join(', ');
    _ui.linha('  Talhões: $talhoes');
    _ui.linha('  Área total: ${formatarNumero(aplicacao.areaTotalHa)} ha');
    final observacao = aplicacao.observacao;
    if (observacao != null) {
      _ui.linha('  Observação: $observacao');
    }
    _ui.linha('  Insumos:');
    for (final item in aplicacao.insumos) {
      final unidade = item.unidade.texto;
      final prevista = formatarCompacto(item.dosePrevista);
      _ui.linha('   - ${item.insumo.nome}');
      _ui.linha('       dose prevista: $prevista $unidade');
      final realizada = item.doseRealizada;
      if (realizada == null) {
        _ui.linha('       dose realizada: ainda não informada');
        continue;
      }
      _ui.linha(
        '       dose realizada: ${formatarCompacto(realizada)} $unidade',
      );
      final percentual = percentualDesperdicio(item.dosePrevista, realizada);
      final status = avaliarSobredose(
        item.dosePrevista,
        realizada,
        toleranciaPercentual: _parametros.toleranciaSobredosePercentual,
      );
      _ui.linha('       desperdício: ${formatarNumero(percentual, 1)}%');
      _ui.linha('       sobredose: ${descreverSobredose(status)}');
    }
  }

  // ---------------------------------------------------------------------
  // Resumo, calculadora, parâmetros e dados de exemplo
  // ---------------------------------------------------------------------

  Future<void> _resumoDesperdicio() async {
    final resumo = await _aplicacaoService.resumoDesperdicio();
    if (resumo.isEmpty) {
      _ui.linha('Ainda não há dose realizada registrada.');
      _ui.linha('Registre uma aplicação informando a dose realizada.');
      return;
    }
    _ui.secao('RESUMO DE DESPERDÍCIO (todas as aplicações)');
    for (final totais in resumo.values) {
      final medida = totais.unidade.split('/').first;
      _ui.linha('  ${totais.unidade}');
      _ui.linha(
        '    previsto: ${formatarNumero(totais.totalPrevisto, 3)} $medida',
      );
      _ui.linha(
        '    realizado: ${formatarNumero(totais.totalRealizado, 3)} $medida',
      );
      _ui.linha(
        '    desperdício: ${formatarNumero(totais.volumeDesperdicado, 3)} $medida',
      );
      _ui.linha('    percentual: ${formatarNumero(totais.percentual, 1)}%');
    }
  }

  Future<void> _abrirCalculadora() {
    return MenuCalculadora(_ui, () => _parametros).executar();
  }

  Future<void> _parametrosOperacionais() async {
    _mostrarParametros();
    if (!_ui.confirmar('Alterar os parâmetros?')) {
      return;
    }
    _ui.linha('Enter mantém o valor atual.');
    final atual = _parametros;
    final tolerancia =
        _ui.perguntarNumero(
          'Tolerância de sobredose, em % '
          '[${formatarCompacto(atual.toleranciaSobredosePercentual)}]',
          minimo: 0,
        ) ??
        atual.toleranciaSobredosePercentual;
    final limite =
        _ui.perguntarNumero(
          'Limite da chuva, em horas [${formatarCompacto(atual.limiteChuvaHoras)}]',
          minimo: 0,
          exclusivo: true,
        ) ??
        atual.limiteChuvaHoras;
    final fator =
        _ui.perguntarNumero(
          'Fator de compra [${formatarCompacto(atual.fatorCompra, 2)}]',
          minimo: 0,
          exclusivo: true,
        ) ??
        atual.fatorCompra;
    _parametros = ParametrosOperacionais(
      toleranciaSobredosePercentual: tolerancia,
      limiteChuvaHoras: limite,
      fatorCompra: fator,
    );
    _ui.linha('Parâmetros atualizados.');
    _mostrarParametros();
  }

  Future<void> _carregarExemplo() async {
    final dados = await garantirDadosExemplo(_repositorios);
    _ui.linha('\nDados de exemplo prontos (o que já existia foi mantido):');
    _ui.linha('  Área: ${dados.sede.nome}');
    _ui.linha('  ${dados.chico1.obterDados()}');
    _ui.linha('  ${dados.chico2.obterDados()}');
    _ui.linha('  ${dados.drone.descreverCapacidade()}');
    _ui.linha('  Operação: ${dados.operacao.descricao}');
    _ui.linha('  Insumos: ${dados.orkestra.nome} e ${dados.boro.nome}');
    _ui.linha('Agora já dá para usar "Registrar aplicação".');
  }

  // ---------------------------------------------------------------------
  // Textos de apoio
  // ---------------------------------------------------------------------

  String _descreverInsumo(Insumo insumo) {
    final marca = insumo.marca;
    if (marca == null) {
      return '${insumo.nome} (${insumo.tipo})';
    }
    return '${insumo.nome} (${insumo.tipo}, $marca)';
  }

  String _descreverTalhao(Talhao talhao) {
    return '${talhao.area.nome} / ${talhao.nome} - '
        '${formatarNumero(talhao.hectares)} ha';
  }

  String _descreverAplicacao(Aplicacao aplicacao) {
    final talhoes = aplicacao.talhoes.map((t) => t.nome).join(', ');
    final area = formatarNumero(aplicacao.areaTotalHa);
    final quantidade = aplicacao.insumos.length;
    final palavra = _plural(quantidade, 'insumo', 'insumos');
    return '${formatarData(aplicacao.data)} | ${aplicacao.operacao.descricao} | '
        '${aplicacao.aplicador.tipo} | $talhoes ($area ha) | '
        '$quantidade $palavra';
  }

  String _plural(int quantidade, String singular, String plural) {
    return quantidade == 1 ? singular : plural;
  }

  bool _mesmoTexto(String a, String b) {
    return a.trim().toLowerCase() == b.trim().toLowerCase();
  }
}

/// Um insumo com a dose digitada para ele, guardados juntos até a gravação.
class _ItemDigitado {
  final Insumo insumo;
  final DoseInformada dose;

  const _ItemDigitado(this.insumo, this.dose);
}
