import 'package:caderno_fazenda/cli/formato.dart';
import 'package:caderno_fazenda/cli/interacao.dart';
import 'package:caderno_fazenda/logica/alertas_operacionais.dart';
import 'package:caderno_fazenda/logica/normalizacao_dose.dart';
import 'package:caderno_fazenda/models/aplicacao.dart';
import 'package:caderno_fazenda/models/aplicacao_insumo.dart';
import 'package:caderno_fazenda/models/entidade.dart';
import 'package:caderno_fazenda/models/motivo_reaplicacao.dart';
import 'package:caderno_fazenda/models/unidade_dose.dart';
import 'package:caderno_fazenda/repositories/repositorios.dart';
import 'package:caderno_fazenda/services/manutencao_service.dart';
import 'package:caderno_fazenda/services/talhao_service.dart';

/// Uma coisa que vai mudar numa correção, para mostrar antes de salvar.
class _Mudanca {
  final String campo;
  final String antes;
  final String depois;

  const _Mudanca(this.campo, this.antes, this.depois);
}

/// Uma dose realizada nova, já na base do banco, e como o usuário a digitou.
class _DoseNova {
  final double valor;
  final String comoDigitada;

  const _DoseNova(this.valor, this.comoDigitada);
}

/// Corrigir e excluir o que já está cadastrado (opções 8 e 9 do menu).
///
/// Não decide nenhuma regra: pergunta, mostra o que vai acontecer e pede a
/// confirmação. Quem confere os valores e recusa o que não pode é o
/// [ManutencaoService] (e o `TalhaoService`, para o talhão). Quando o sistema
/// recusa, a mensagem aparece e o menu continua.
///
/// Na correção, Enter em um campo mantém o valor atual e nada é gravado antes
/// de o usuário confirmar. Na exclusão, o sistema recusa o que está em uso
/// ANTES de pedir a confirmação, e a confirmação começa em "não".
class MenuManutencao {
  final Interacao _ui;
  final Repositorios _repositorios;
  final void Function(Aplicacao aplicacao) _mostrarAplicacao;
  final double Function() _limiteChuvaHoras;
  final ManutencaoService _servico;
  final TalhaoService _talhaoService;

  /// Cria o menu sobre [repositorios], conversando pela [ui].
  ///
  /// [mostrarAplicacao] mostra os detalhes de uma aplicação na tela (é o
  /// mesmo texto da consulta "Aplicações registradas"). [limiteChuvaHoras]
  /// devolve o limite de chuva em vigor, que pode mudar nos parâmetros.
  MenuManutencao(
    this._ui,
    Repositorios repositorios, {
    required this._mostrarAplicacao,
    required this._limiteChuvaHoras,
  }) : _repositorios = repositorios,
       _servico = ManutencaoService(
         repositorios.areas,
         repositorios.talhoes,
         repositorios.insumos,
         repositorios.aplicadores,
         repositorios.operacoes,
         repositorios.aplicacoes,
       ),
       _talhaoService = TalhaoService(repositorios.areas, repositorios.talhoes);

  // ---------------------------------------------------------------------
  // Corrigir
  // ---------------------------------------------------------------------

  /// Abre o menu de correção e só volta quando o usuário escolher voltar.
  Future<void> corrigir() {
    return _ui.menu(
      'CORRIGIR UM REGISTRO',
      [
        OpcaoMenu('Área (nome)', _corrigirArea),
        OpcaoMenu('Talhão (nome e hectares)', _corrigirTalhao),
        OpcaoMenu('Insumo (nome, tipo e marca)', _corrigirInsumo),
        OpcaoMenu('Aplicador (modelo e capacidades)', _corrigirAplicador),
        OpcaoMenu('Operação (descrição)', _corrigirOperacao),
        OpcaoMenu(
          'Aplicação (data, observação e dose realizada)',
          _corrigirAplicacao,
        ),
      ],
      dica:
          'Em cada campo, Enter mantém o valor atual. '
          'Nada é gravado sem a sua confirmação.',
    );
  }

  Future<void> _corrigirArea() async {
    final areas = await _repositorios.areas.listarTodos();
    final area = _escolher(
      titulo: 'Áreas:',
      vazio: 'Nenhuma área cadastrada.',
      rotulo: 'Id da área a corrigir [Enter = voltar]',
      registros: areas,
      descrever: (a) => a.nome,
    );
    if (area == null) {
      return;
    }
    final nome = _ui.editarTexto('Nome da área', area.nome);
    if (!_aprovar([_Mudanca('nome', area.nome, nome)])) {
      return;
    }
    final corrigida = await _servico.corrigirArea(area.id!, nome: nome);
    _ui.sucesso('Área corrigida: [${corrigida.id}] ${corrigida.nome}');
  }

  Future<void> _corrigirTalhao() async {
    final talhoes = await _repositorios.talhoes.listarTodos();
    final talhao = _escolher(
      titulo: 'Talhões:',
      vazio: 'Nenhum talhão cadastrado.',
      rotulo: 'Id do talhão a corrigir [Enter = voltar]',
      registros: talhoes,
      descrever: descreverTalhao,
    );
    if (talhao == null) {
      return;
    }
    _ui.linha('\nA área do talhão (${talhao.area.nome}) não muda aqui.');
    final nome = _ui.editarTexto('Nome do talhão', talhao.nome);
    final hectares = _ui.editarNumero(
      'Tamanho em hectares',
      talhao.hectares,
      minimo: 0,
      exclusivo: true,
    );
    final mudancas = [
      _Mudanca('nome', talhao.nome, nome),
      _Mudanca(
        'hectares',
        formatarCompacto(talhao.hectares),
        formatarCompacto(hectares),
      ),
    ];
    final avisos = <String>[];
    if (hectares != talhao.hectares) {
      final usos = await _repositorios.aplicacoes.listarPorTalhao(talhao.id!);
      if (usos.isNotEmpty) {
        final quantas = usos.length;
        final registradas = plural(
          quantas,
          'aplicação já registrada usa este talhão',
          'aplicações já registradas usam este talhão',
        );
        avisos.add(
          '$quantas $registradas: a área e as quantidades '
          '${plural(quantas, 'dela passam', 'delas passam')} a ser '
          'calculadas com o novo tamanho.',
        );
      }
    }
    if (!_aprovar(mudancas, avisos: avisos)) {
      return;
    }
    final corrigido = await _talhaoService.corrigir(
      talhao.id!,
      nome: nome,
      hectares: hectares,
    );
    _ui.sucesso(
      'Talhão corrigido: [${corrigido.id}] ${descreverTalhao(corrigido)}',
    );
  }

  Future<void> _corrigirInsumo() async {
    final insumos = await _repositorios.insumos.listarTodos();
    final insumo = _escolher(
      titulo: 'Insumos:',
      vazio: 'Nenhum insumo cadastrado.',
      rotulo: 'Id do insumo a corrigir [Enter = voltar]',
      registros: insumos,
      descrever: descreverInsumo,
    );
    if (insumo == null) {
      return;
    }
    final nome = _ui.editarTexto('Nome do insumo', insumo.nome);
    final tipo = _ui.editarTexto('Tipo', insumo.tipo);
    final marca = _ui.editarTextoOpcional('Marca', insumo.marca);
    final mudancas = [
      _Mudanca('nome', insumo.nome, nome),
      _Mudanca('tipo', insumo.tipo, tipo),
      _Mudanca('marca', _texto(insumo.marca), _texto(marca)),
    ];
    if (!_aprovar(mudancas)) {
      return;
    }
    final corrigido = await _servico.corrigirInsumo(
      insumo.id!,
      nome: nome,
      tipo: tipo,
      marca: marca,
    );
    _ui.sucesso(
      'Insumo corrigido: [${corrigido.id}] ${descreverInsumo(corrigido)}',
    );
  }

  Future<void> _corrigirAplicador() async {
    final aplicadores = await _repositorios.aplicadores.listarTodos();
    final aplicador = _escolher(
      titulo: 'Aplicadores:',
      vazio: 'Nenhum aplicador cadastrado.',
      rotulo: 'Id do aplicador a corrigir [Enter = voltar]',
      registros: aplicadores,
      descrever: (a) => a.descreverCapacidade(),
    );
    if (aplicador == null) {
      return;
    }
    _ui.linha(
      '\nO tipo (${aplicador.tipo}) não muda. '
      'Para trocar de tipo, exclua e cadastre outro.',
    );
    final modelo = _ui.editarTextoOpcional('Modelo', aplicador.modelo);
    final litros = _ui.editarNumeroOpcional(
      'Capacidade máxima por viagem, em litros',
      aplicador.capacidadeMaximaL,
      minimo: 0,
      exclusivo: true,
    );
    final quilos = _ui.editarNumeroOpcional(
      'Capacidade máxima por viagem, em kg',
      aplicador.capacidadeMaximaKg,
      minimo: 0,
      exclusivo: true,
    );
    final mudancas = [
      _Mudanca('modelo', _texto(aplicador.modelo), _texto(modelo)),
      _Mudanca(
        'capacidade (L)',
        _numero(aplicador.capacidadeMaximaL),
        _numero(litros),
      ),
      _Mudanca(
        'capacidade (kg)',
        _numero(aplicador.capacidadeMaximaKg),
        _numero(quilos),
      ),
    ];
    if (!_aprovar(mudancas)) {
      return;
    }
    final corrigido = await _servico.corrigirAplicador(
      aplicador.id!,
      modelo: modelo,
      capacidadeMaximaL: litros,
      capacidadeMaximaKg: quilos,
    );
    _ui.sucesso(
      'Aplicador corrigido: [${corrigido.id}] ${corrigido.descreverCapacidade()}',
    );
  }

  Future<void> _corrigirOperacao() async {
    final operacoes = await _repositorios.operacoes.listarTodos();
    final operacao = _escolher(
      titulo: 'Operações:',
      vazio: 'Nenhuma operação cadastrada.',
      rotulo: 'Id da operação a corrigir [Enter = voltar]',
      registros: operacoes,
      descrever: (o) => o.descricao,
    );
    if (operacao == null) {
      return;
    }
    final descricao = _ui.editarTexto('Descrição', operacao.descricao);
    if (!_aprovar([_Mudanca('descrição', operacao.descricao, descricao)])) {
      return;
    }
    final corrigida = await _servico.corrigirOperacao(
      operacao.id!,
      descricao: descricao,
    );
    _ui.sucesso('Operação corrigida: [${corrigida.id}] ${corrigida.descricao}');
  }

  Future<void> _corrigirAplicacao() async {
    final aplicacoes = await _repositorios.aplicacoes.listarTodos();
    final aplicacao = _escolher(
      titulo: 'Aplicações:',
      vazio: 'Nenhuma aplicação registrada.',
      rotulo: 'Id da aplicação a corrigir [Enter = voltar]',
      registros: aplicacoes,
      descrever: descreverAplicacao,
    );
    if (aplicacao == null) {
      return;
    }
    _mostrarAplicacao(aplicacao);
    _ui.linha();
    _ui.linha(
      'Aqui dá para mudar a data, a observação, a chuva, o motivo de '
      'reaplicação e a dose realizada. Talhões, insumos, aplicador, operação '
      'e dose prevista não mudam: para isso, exclua a aplicação e registre '
      'outra.',
    );
    final data = _ui.editarData('Data da aplicação', aplicacao.data);
    final observacao = _ui.editarTextoOpcional(
      'Observação',
      aplicacao.observacao,
    );
    final horas = _ui.editarNumeroOpcional(
      'Horas entre o fim da aplicação e a chuva',
      aplicacao.horasAteChuva,
      minimo: 0,
    );
    final motivoAtual = aplicacao.motivoReaplicacao;
    final posicaoMotivo = _ui.editarOpcaoOpcional(
      'Imprevisto que obriga a reaplicar',
      textosDosMotivos,
      motivoAtual?.index,
    );
    var motivo = posicaoMotivo == null
        ? null
        : MotivoReaplicacao.values[posicaoMotivo];
    // Mesma regra do registro: chuva abaixo do limite sempre deixa o motivo
    // gravado como chuva, para o BI não perder a reaplicação.
    final chuvaPedeReaplicar =
        horas != null &&
        avaliarChuva(horas, limiteHoras: _limiteChuvaHoras()) ==
            DecisaoChuva.reaplicar;
    if (chuvaPedeReaplicar && motivo == null) {
      motivo = MotivoReaplicacao.chuva;
      _ui.linha(
        'A chuva veio antes do limite de ${formatarCompacto(_limiteChuvaHoras())} '
        'h: o motivo fica como chuva.',
      );
    }
    final mudancas = [
      _Mudanca('data', formatarData(aplicacao.data), formatarData(data)),
      _Mudanca('observação', _texto(aplicacao.observacao), _texto(observacao)),
      _Mudanca(
        'chuva (horas)',
        _numero(aplicacao.horasAteChuva),
        _numero(horas),
      ),
      _Mudanca(
        'motivo de reaplicação',
        motivoAtual?.texto ?? '(nenhum)',
        motivo?.texto ?? '(nenhum)',
      ),
    ];
    final doses = <int, double>{};
    final avisos = <String>[];
    var suspeita = false;
    for (final item in aplicacao.insumos) {
      final nova = _perguntarDoseRealizada(item);
      if (nova == null) {
        continue;
      }
      final base = item.unidade.texto;
      final atual = item.doseRealizada;
      doses[item.insumo.id!] = nova.valor;
      final depois = '${formatarCompacto(nova.valor)} $base';
      mudancas.add(
        _Mudanca(
          'dose realizada de ${item.insumo.nome}',
          atual == null
              ? 'ainda não informada'
              : '${formatarCompacto(atual)} $base',
          depois == nova.comoDigitada
              ? depois
              : '$depois (anotada como ${nova.comoDigitada})',
        ),
      );
      if (nova.valor > item.dosePrevista * 10) {
        suspeita = true;
        avisos.add(
          'a dose realizada de ${item.insumo.nome} ($depois) é mais de 10 '
          'vezes a prevista (${formatarCompacto(item.dosePrevista)} $base). '
          'Confira a unidade.',
        );
      }
    }
    if (!_aprovar(mudancas, avisos: avisos, padrao: !suspeita)) {
      return;
    }
    final corrigida = await _servico.corrigirAplicacao(
      aplicacao.id!,
      data: data,
      observacao: observacao,
      horasAteChuva: horas,
      motivoReaplicacao: motivo,
      dosesRealizadas: doses,
    );
    _ui.sucesso('Aplicação corrigida:');
    _mostrarAplicacao(corrigida);
  }

  // ---------------------------------------------------------------------
  // Excluir
  // ---------------------------------------------------------------------

  /// Abre o menu de exclusão e só volta quando o usuário escolher voltar.
  Future<void> excluir() {
    return _ui.menu(
      'EXCLUIR UM REGISTRO',
      [
        OpcaoMenu('Área', _excluirArea),
        OpcaoMenu('Talhão', _excluirTalhao),
        OpcaoMenu('Insumo', _excluirInsumo),
        OpcaoMenu('Aplicador', _excluirAplicador),
        OpcaoMenu('Operação', _excluirOperacao),
        OpcaoMenu('Aplicação', _excluirAplicacao),
      ],
      dica:
          'Só dá para excluir o que não está em uso, e excluir não pode ser '
          'desfeito.',
    );
  }

  Future<void> _excluirArea() async {
    await _excluirRegistro(
      registros: await _repositorios.areas.listarTodos(),
      titulo: 'Áreas:',
      vazio: 'Nenhuma área cadastrada.',
      rotulo: 'Id da área a excluir [Enter = voltar]',
      descrever: (a) => 'área ${a.nome}',
      excluir: _servico.excluirArea,
    );
  }

  Future<void> _excluirTalhao() async {
    await _excluirRegistro(
      registros: await _repositorios.talhoes.listarTodos(),
      titulo: 'Talhões:',
      vazio: 'Nenhum talhão cadastrado.',
      rotulo: 'Id do talhão a excluir [Enter = voltar]',
      descrever: (t) => 'talhão ${descreverTalhao(t)}',
      excluir: _servico.excluirTalhao,
    );
  }

  Future<void> _excluirInsumo() async {
    await _excluirRegistro(
      registros: await _repositorios.insumos.listarTodos(),
      titulo: 'Insumos:',
      vazio: 'Nenhum insumo cadastrado.',
      rotulo: 'Id do insumo a excluir [Enter = voltar]',
      descrever: (i) => 'insumo ${descreverInsumo(i)}',
      excluir: _servico.excluirInsumo,
    );
  }

  Future<void> _excluirAplicador() async {
    await _excluirRegistro(
      registros: await _repositorios.aplicadores.listarTodos(),
      titulo: 'Aplicadores:',
      vazio: 'Nenhum aplicador cadastrado.',
      rotulo: 'Id do aplicador a excluir [Enter = voltar]',
      descrever: (a) => 'aplicador ${a.descreverCapacidade()}',
      excluir: _servico.excluirAplicador,
    );
  }

  Future<void> _excluirOperacao() async {
    await _excluirRegistro(
      registros: await _repositorios.operacoes.listarTodos(),
      titulo: 'Operações:',
      vazio: 'Nenhuma operação cadastrada.',
      rotulo: 'Id da operação a excluir [Enter = voltar]',
      descrever: (o) => 'operação ${o.descricao}',
      excluir: _servico.excluirOperacao,
    );
  }

  Future<void> _excluirAplicacao() async {
    await _excluirRegistro(
      registros: await _repositorios.aplicacoes.listarTodos(),
      titulo: 'Aplicações:',
      vazio: 'Nenhuma aplicação registrada.',
      rotulo: 'Id da aplicação a excluir [Enter = voltar]',
      descrever: (a) => 'aplicação ${descreverAplicacao(a)}',
      efeito:
          'A aplicação e as doses dela serão apagadas. Talhões, insumos, '
          'aplicador e operação continuam cadastrados.',
      excluir: _servico.excluirAplicacao,
    );
  }

  /// O caminho de toda exclusão: escolher, deixar o sistema recusar o que está
  /// em uso, mostrar o que vai acontecer e só então pedir a confirmação.
  Future<void> _excluirRegistro<T extends Entidade>({
    required List<T> registros,
    required String titulo,
    required String vazio,
    required String rotulo,
    required String Function(T registro) descrever,
    required Future<T> Function(int id, {bool apenasConferir}) excluir,
    String? efeito,
  }) async {
    final escolhido = _escolher(
      titulo: titulo,
      vazio: vazio,
      rotulo: rotulo,
      registros: registros,
      descrever: (registro) => descrever(registro),
    );
    if (escolhido == null) {
      return;
    }
    final id = escolhido.id!;
    // Se estiver em uso, a recusa sai aqui, antes de qualquer pergunta.
    await excluir(id, apenasConferir: true);

    _ui.linha();
    _ui.linha('Vai excluir: ${descrever(escolhido)}');
    if (efeito != null) {
      _ui.linha(efeito);
    }
    if (_repositorios.persistente) {
      _ui.linha('Atenção: isto apaga do banco de dados, que a equipe usa.');
    }
    _ui.linha('Excluir não pode ser desfeito.');
    if (!_ui.confirmar('Excluir mesmo?')) {
      _ui.aviso('Cancelado. Nada foi excluído.');
      return;
    }
    final excluido = await excluir(id);
    _ui.sucesso('Excluído: ${descrever(excluido)}');
  }

  // ---------------------------------------------------------------------
  // Apoio
  // ---------------------------------------------------------------------

  /// Lista os [registros] e pede o id de um. Devolve null se não há nenhum
  /// (e avisa) ou se o usuário só apertou Enter.
  T? _escolher<T extends Entidade>({
    required String titulo,
    required String vazio,
    required String rotulo,
    required List<T> registros,
    required String Function(T registro) descrever,
  }) {
    if (registros.isEmpty) {
      _ui.aviso(vazio);
      return null;
    }
    _ui.subtitulo(titulo.replaceAll(':', ''));
    return _ui.escolherPorId(rotulo, registros, descrever);
  }

  /// Mostra o que vai mudar e pede a confirmação. Devolve false, explicando,
  /// se nada mudou ou se o usuário desistiu.
  ///
  /// Os [avisos] aparecem logo abaixo das mudanças. Enter responde [padrao]
  /// (sim, a não ser que algo pareça errado).
  bool _aprovar(
    List<_Mudanca> mudancas, {
    List<String> avisos = const [],
    bool padrao = true,
  }) {
    final reais = [
      for (final mudanca in mudancas)
        if (mudanca.antes != mudanca.depois) mudanca,
    ];
    if (reais.isEmpty) {
      _ui.aviso('Nada foi alterado.');
      return false;
    }
    _ui.linha('\nVai mudar:');
    for (final mudanca in reais) {
      _ui.linha('  ${mudanca.campo}: ${mudanca.antes} -> ${mudanca.depois}');
    }
    for (final aviso in avisos) {
      _ui.linha('Atenção: $aviso');
    }
    _ui.linha();
    if (!_ui.confirmar('Salvar a correção?', padrao: padrao)) {
      _ui.aviso('Cancelado. Nada foi alterado.');
      return false;
    }
    return true;
  }

  /// Pergunta a nova dose realizada de um insumo, na unidade da ficha, e
  /// devolve a dose já convertida para a base do banco. Devolve null se o
  /// usuário não quiser mudá-la.
  _DoseNova? _perguntarDoseRealizada(AplicacaoInsumo item) {
    final base = item.unidade.texto;
    final atual = item.doseRealizada;
    final hoje = atual == null
        ? 'ainda não informada'
        : '${formatarCompacto(atual)} $base';
    final nome = item.insumo.nome;
    _ui.linha();
    if (!_ui.confirmar('Mudar a dose realizada de $nome (hoje: $hoje)?')) {
      return null;
    }
    // L/1000L fica de fora: depende da taxa de aplicação, que a aplicação já
    // gravada não guarda.
    final unidades = switch (item.unidade) {
      UnidadeDose.litrosPorHectare => ['mL/ha', 'L/ha'],
      UnidadeDose.quilosPorHectare => ['g/ha', 'kg/ha'],
    };
    final indice = _ui.escolherOpcao('Unidade em que vai digitar', unidades);
    if (indice == null) {
      return null;
    }
    final unidade = unidades[indice];
    final digitada = _ui.perguntarNumero(
      'Dose realizada de $nome ($unidade) [Enter = não mudar]',
      minimo: 0,
    );
    if (digitada == null) {
      return null;
    }
    // A taxa só conta na conversão de L/1000L, que não é oferecida aqui.
    final convertida = normalizarDoseInformada(digitada, unidade, 1);
    return _DoseNova(
      convertida.valor,
      '${formatarCompacto(digitada)} $unidade',
    );
  }

  String _texto(String? valor) => valor ?? '(vazio)';

  String _numero(double? valor) {
    return valor == null ? '(vazio)' : formatarCompacto(valor);
  }
}
