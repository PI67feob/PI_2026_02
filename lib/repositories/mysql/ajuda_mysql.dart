/// Funções de apoio dos repositórios MySQL: conversão dos valores que o driver
/// devolve e a gravação genérica de uma linha (INSERT ou UPDATE).
///
/// Os nomes de tabela e de coluna que entram nestas funções vêm sempre de
/// constantes dentro dos repositórios, nunca do usuário. Todo valor digitado
/// passa por parâmetro nomeado (`:coluna`), que o driver escapa.
library;

import 'package:caderno_fazenda/exceptions/registro_nao_encontrado_exception.dart';
import 'package:caderno_fazenda/models/entidade.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';

/// Lê um inteiro devolvido pelo driver (que entrega tudo como texto).
int inteiro(Object? valor) => int.parse(valor.toString());

/// Lê um número com casas decimais (colunas DECIMAL chegam como texto).
double decimal(Object? valor) => double.parse(valor.toString());

/// Como [decimal], mas devolve null quando a coluna está vazia (NULL).
double? decimalOuNulo(Object? valor) => valor == null ? null : decimal(valor);

/// Lê um texto, ou null quando a coluna está vazia (NULL).
String? textoOuNulo(Object? valor) => valor?.toString();

/// Arredonda [valor] para [casas] casas decimais, no formato da coluna
/// DECIMAL. Evita enviar `0.30000000000000004` para uma coluna `DECIMAL(10,3)`.
double arredondar(double valor, int casas) {
  return double.parse(valor.toStringAsFixed(casas));
}

/// Data no formato `AAAA-MM-DD`, o que o MySQL espera em uma coluna DATE.
String dataSql(DateTime data) {
  final mes = data.month.toString().padLeft(2, '0');
  final dia = data.day.toString().padLeft(2, '0');
  return '${data.year.toString().padLeft(4, '0')}-$mes-$dia';
}

/// Insere uma linha em [tabela] e devolve o id gerado (AUTO_INCREMENT).
///
/// Cada chave de [valores] é uma coluna; o valor vai como parâmetro nomeado.
Future<int> inserirLinha(
  MySQLConnection conexao,
  String tabela,
  Map<String, Object?> valores,
) async {
  final colunas = valores.keys.join(', ');
  final parametros = valores.keys.map((coluna) => ':$coluna').join(', ');
  final resultado = await conexao.execute(
    'INSERT INTO $tabela ($colunas) VALUES ($parametros)',
    valores,
  );
  return resultado.lastInsertID.toInt();
}

/// Atualiza a linha de [tabela] cujo [colunaId] vale [id].
///
/// Lança [RegistroNaoEncontradoException] (com o nome da [entidade]) se a
/// linha não existir. O MySQL conta 0 linhas alteradas quando os valores novos
/// são iguais aos antigos; por isso, nesse caso, confere se a linha existe
/// antes de acusar erro.
Future<void> atualizarLinha(
  MySQLConnection conexao,
  String tabela,
  String colunaId,
  int id,
  Map<String, Object?> valores, {
  required String entidade,
}) async {
  final atribuicoes = valores.keys.map((coluna) => '$coluna = :$coluna');
  final resultado = await conexao.execute(
    'UPDATE $tabela SET ${atribuicoes.join(', ')} WHERE $colunaId = :chave_id',
    {...valores, 'chave_id': id},
  );
  if (resultado.affectedRows.toInt() > 0) {
    return;
  }
  final existe = await conexao.execute(
    'SELECT 1 FROM $tabela WHERE $colunaId = :chave_id',
    {'chave_id': id},
  );
  if (existe.rows.isEmpty) {
    throw RegistroNaoEncontradoException(entidade, id);
  }
}

/// Grava a [entidade]: INSERT se ela ainda não tem id (e guarda o id gerado
/// nela), UPDATE se já tem. É o contrato de `Repository.salvar`.
Future<void> gravarLinha(
  MySQLConnection conexao,
  Entidade entidade, {
  required String tabela,
  required String colunaId,
  required String nomeEntidade,
  required Map<String, Object?> valores,
}) async {
  final id = entidade.id;
  if (id == null) {
    entidade.definirId(await inserirLinha(conexao, tabela, valores));
  } else {
    await atualizarLinha(
      conexao,
      tabela,
      colunaId,
      id,
      valores,
      entidade: nomeEntidade,
    );
  }
}
