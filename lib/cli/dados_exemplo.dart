import 'package:caderno_fazenda/models/aplicador.dart';
import 'package:caderno_fazenda/models/area.dart';
import 'package:caderno_fazenda/models/drone.dart';
import 'package:caderno_fazenda/models/insumo.dart';
import 'package:caderno_fazenda/models/operacao.dart';
import 'package:caderno_fazenda/models/talhao.dart';
import 'package:caderno_fazenda/repositories/interfaces/aplicador_repository.dart';
import 'package:caderno_fazenda/repositories/interfaces/insumo_repository.dart';
import 'package:caderno_fazenda/repositories/repositorios.dart';
import 'package:caderno_fazenda/services/talhao_service.dart';

/// Os cadastros de exemplo da fazenda, já gravados no repositório.
///
/// São os mesmos usados na demonstração (`bin/main.dart`) e na opção "Carregar
/// dados de exemplo" do menu: a área Sede, os talhões Chico1 e Chico2, um
/// drone, a operação Pulverização e dois insumos.
class DadosExemplo {
  final Area sede;
  final Talhao chico1;
  final Talhao chico2;
  final Aplicador drone;
  final Operacao operacao;
  final Insumo orkestra;
  final Insumo boro;

  const DadosExemplo({
    required this.sede,
    required this.chico1,
    required this.chico2,
    required this.drone,
    required this.operacao,
    required this.orkestra,
    required this.boro,
  });
}

/// Garante que os cadastros de exemplo existem em [repositorios].
///
/// Só cria o que ainda não existe, então pode ser chamada várias vezes (e em
/// cima de um banco que já tem dados) sem duplicar nada. Devolve os cadastros,
/// novos ou antigos.
Future<DadosExemplo> garantirDadosExemplo(Repositorios repositorios) async {
  final areas = repositorios.areas;
  final talhoes = repositorios.talhoes;
  final insumos = repositorios.insumos;
  final aplicadores = repositorios.aplicadores;
  final operacoes = repositorios.operacoes;

  final sede =
      await areas.buscarPorNome('Sede') ??
      await areas.salvar(Area(nome: 'Sede'));
  final idSede = sede.id!;
  final talhaoService = TalhaoService(areas, talhoes);

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

  return DadosExemplo(
    sede: sede,
    chico1: chico1,
    chico2: chico2,
    drone: drone,
    operacao: operacao,
    orkestra: orkestra,
    boro: boro,
  );
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
