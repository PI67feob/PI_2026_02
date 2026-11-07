@Tags(['mysql'])
library;

import 'dart:io';

import 'package:caderno_fazenda/exceptions/registro_nao_encontrado_exception.dart';
import 'package:caderno_fazenda/models/area.dart';
import 'package:caderno_fazenda/repositories/configuracao_banco.dart';
import 'package:caderno_fazenda/repositories/mysql/area_repository_mysql.dart';
import 'package:caderno_fazenda/repositories/mysql/conexao_mysql.dart';
import 'package:test/test.dart';

/// Testes de integração: falam com o MySQL de verdade (o RDS da equipe).
///
/// Só rodam com as variáveis do `.env` exportadas e com `-t mysql`:
///
/// ```
/// set -a; source .env; set +a
/// dart test -t mysql test/repositories/area_repository_mysql_test.dart
/// ```
///
/// Sem `DB_HOST` no ambiente, o grupo inteiro é pulado, então o `dart test`
/// comum continua funcionando offline. Cada teste cria uma área com nome
/// exclusivo e apaga no fim, para não sujar o banco compartilhado.
void main() {
  final temBanco = (Platform.environment['DB_HOST'] ?? '').isNotEmpty;

  group(
    'AreaRepositoryMysql',
    skip: temBanco ? null : 'defina DB_HOST (e as outras DB_*) para rodar',
    () {
      late ConexaoMysql banco;
      late AreaRepositoryMysql repositorio;
      final criadas = <int>[];

      // Nome exclusivo por execução: duas pessoas testando juntas não colidem.
      final prefixo = 'teste-${DateTime.now().microsecondsSinceEpoch}';

      setUpAll(() async {
        banco = await ConexaoMysql.abrir(ConfiguracaoBanco.doAmbiente());
        repositorio = AreaRepositoryMysql(banco);
      });

      tearDown(() async {
        for (final id in criadas) {
          await repositorio.remover(id);
        }
        criadas.clear();
      });

      tearDownAll(() async {
        await banco.fechar();
      });

      Future<Area> criar(String sufixo) async {
        final area = await repositorio.salvar(Area(nome: '$prefixo-$sufixo'));
        criadas.add(area.id!);
        return area;
      }

      test('salvar sem id insere e devolve a área com o id gerado', () async {
        final area = await criar('a');

        expect(area.id, isNotNull);
        expect(area.id, greaterThan(0));
      });

      test('buscarPorId devolve a área gravada', () async {
        final area = await criar('b');

        final lida = await repositorio.buscarPorId(area.id!);

        expect(lida, isNotNull);
        expect(lida!.id, area.id);
        expect(lida.nome, '$prefixo-b');
      });

      test('buscarPorId devolve null quando não existe', () async {
        expect(await repositorio.buscarPorId(2147483647), isNull);
      });

      test('buscarPorNome ignora maiúsculas e minúsculas', () async {
        final area = await criar('c');

        final maiusculas = '$prefixo-c'.toUpperCase();
        final lida = await repositorio.buscarPorNome(maiusculas);

        expect(lida?.id, area.id);
      });

      test('salvar com id atualiza o nome', () async {
        final area = await criar('d');

        area.nome = '$prefixo-d-novo';
        await repositorio.salvar(area);

        final lida = await repositorio.buscarPorId(area.id!);
        expect(lida!.nome, '$prefixo-d-novo');
      });

      test('salvar com o mesmo nome não é erro', () async {
        final area = await criar('e');

        await repositorio.salvar(area);

        expect((await repositorio.buscarPorId(area.id!))?.nome, area.nome);
      });

      test('salvar com id inexistente lança RegistroNaoEncontrado', () async {
        final fantasma = Area(nome: '$prefixo-f', id: 2147483647);

        expect(
          () => repositorio.salvar(fantasma),
          throwsA(isA<RegistroNaoEncontradoException>()),
        );
      });

      test('listarTodos traz as áreas em ordem crescente de id', () async {
        final primeira = await criar('g1');
        final segunda = await criar('g2');

        final todas = await repositorio.listarTodos();
        final ids = todas.map((a) => a.id!).toList();

        expect(ids, containsAllInOrder([primeira.id, segunda.id]));
        expect(ids, orderedEquals([...ids]..sort()));
      });

      test('remover apaga e informa se existia', () async {
        final area = await criar('h');

        expect(await repositorio.remover(area.id!), isTrue);
        expect(await repositorio.remover(area.id!), isFalse);
        expect(await repositorio.buscarPorId(area.id!), isNull);
      });
    },
  );
}
