import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';
import 'package:caderno_fazenda/models/aplicador.dart';
import 'package:caderno_fazenda/models/bomba_costal.dart';
import 'package:caderno_fazenda/models/drone.dart';
import 'package:caderno_fazenda/models/trator.dart';

/// Cria a subclasse certa de [Aplicador] a partir do texto do banco.
///
/// O banco guarda o tipo como texto (`trator`, `drone` ou `bomba costal`).
/// Quem lê uma linha da tabela `aplicador` chama esta função e recebe um
/// [Trator], um [Drone] ou uma [BombaCostal]: é aqui que o polimorfismo
/// encontra a persistência. As letras maiúsculas e os espaços nas pontas do
/// [tipo] são ignorados.
///
/// Lança [DadoInvalidoException] quando o [tipo] não é um dos três.
Aplicador criarAplicador(
  String tipo, {
  int? id,
  String? modelo,
  double? capacidadeMaximaL,
  double? capacidadeMaximaKg,
}) {
  switch (tipo.trim().toLowerCase()) {
    case 'trator':
      return Trator(
        id: id,
        modelo: modelo,
        capacidadeMaximaL: capacidadeMaximaL,
        capacidadeMaximaKg: capacidadeMaximaKg,
      );
    case 'drone':
      return Drone(
        id: id,
        modelo: modelo,
        capacidadeMaximaL: capacidadeMaximaL,
        capacidadeMaximaKg: capacidadeMaximaKg,
      );
    case 'bomba costal':
      return BombaCostal(
        id: id,
        modelo: modelo,
        capacidadeMaximaL: capacidadeMaximaL,
        capacidadeMaximaKg: capacidadeMaximaKg,
      );
    default:
      throw DadoInvalidoException(
        'tipo do aplicador',
        'use trator, drone ou bomba costal (recebido: $tipo)',
      );
  }
}
