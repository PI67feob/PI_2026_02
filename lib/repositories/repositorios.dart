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

/// Os seis repositórios do sistema, montados e prontos para usar.
///
/// É aqui que o programa escolhe de onde vêm os dados: da memória (somem
/// quando o programa termina) ou do MySQL. A demonstração (`bin/main.dart`) e
/// o menu (`bin/caderno.dart`) pedem o conjunto a esta classe, e o resto do
/// código só conhece as interfaces de `repositories/interfaces/`.
class Repositorios {
  /// Texto curto que diz de onde vêm os dados, para mostrar ao usuário.
  final String origem;

  /// `true` se o que for cadastrado continua existindo depois que o programa
  /// termina (MySQL); `false` se some (memória).
  final bool persistente;

  final AreaRepository areas;
  final TalhaoRepository talhoes;
  final InsumoRepository insumos;
  final AplicadorRepository aplicadores;
  final OperacaoRepository operacoes;
  final AplicacaoRepository aplicacoes;

  Repositorios({
    required this.origem,
    required this.persistente,
    required this.areas,
    required this.talhoes,
    required this.insumos,
    required this.aplicadores,
    required this.operacoes,
    required this.aplicacoes,
  });

  /// Repositórios provisórios em memória: não precisam de banco.
  factory Repositorios.memoria() {
    return Repositorios(
      origem: 'dados em memória',
      persistente: false,
      areas: AreaRepositoryMemoria(),
      talhoes: TalhaoRepositoryMemoria(),
      insumos: InsumoRepositoryMemoria(),
      aplicadores: AplicadorRepositoryMemoria(),
      operacoes: OperacaoRepositoryMemoria(),
      aplicacoes: AplicacaoRepositoryMemoria(),
    );
  }

  /// Repositórios que gravam no MySQL, pela [banco] já aberta.
  ///
  /// Quem abre e fecha a conexão é quem chama (veja [ConexaoMysql.abrir]).
  factory Repositorios.mysql(ConexaoMysql banco) {
    final talhoes = TalhaoRepositoryMysql(banco);
    final insumos = InsumoRepositoryMysql(banco);
    final aplicadores = AplicadorRepositoryMysql(banco);
    final operacoes = OperacaoRepositoryMysql(banco);
    return Repositorios(
      origem: 'MySQL na AWS',
      persistente: true,
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
