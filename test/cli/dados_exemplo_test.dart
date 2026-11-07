import 'package:caderno_fazenda/cli/dados_exemplo.dart';
import 'package:caderno_fazenda/models/area.dart';
import 'package:caderno_fazenda/repositories/repositorios.dart';
import 'package:test/test.dart';

/// Testes dos cadastros de exemplo, usados pela demonstração e pelo menu.
void main() {
  test('cria a área, os talhões, o drone, a operação e os insumos', () async {
    final repos = Repositorios.memoria();
    final dados = await garantirDadosExemplo(repos);

    expect(dados.sede.nome, 'Sede');
    expect(dados.chico1.nome, 'Chico1');
    expect(dados.chico1.hectares, 2.8);
    expect(dados.chico2.hectares, 3.8);
    expect(dados.chico1.area.id, dados.sede.id);
    expect(dados.drone.tipo, 'drone');
    expect(dados.drone.capacidadeMaximaL, 70.0);
    expect(dados.drone.capacidadeMaximaKg, 70.0);
    expect(dados.operacao.descricao, 'Pulverização');
    expect(dados.orkestra.nome, 'Orkestra SC');
    expect(dados.orkestra.tipo, 'Fungicida');
    expect(dados.boro.nome, 'Boro Super');
    expect(dados.boro.tipo, 'Fertilizante');
  });

  test(
    'chamar de novo não duplica nada e devolve os mesmos registros',
    () async {
      final repos = Repositorios.memoria();
      final primeira = await garantirDadosExemplo(repos);
      final segunda = await garantirDadosExemplo(repos);

      expect(segunda.sede.id, primeira.sede.id);
      expect(segunda.chico1.id, primeira.chico1.id);
      expect(segunda.chico2.id, primeira.chico2.id);
      expect(segunda.drone.id, primeira.drone.id);
      expect(segunda.operacao.id, primeira.operacao.id);
      expect(segunda.orkestra.id, primeira.orkestra.id);
      expect(segunda.boro.id, primeira.boro.id);

      expect((await repos.areas.listarTodos()).length, 1);
      expect((await repos.talhoes.listarTodos()).length, 2);
      expect((await repos.aplicadores.listarTodos()).length, 1);
      expect((await repos.operacoes.listarTodos()).length, 1);
      expect((await repos.insumos.listarTodos()).length, 2);
    },
  );

  test('aproveita a área Sede que já existia', () async {
    final repos = Repositorios.memoria();
    final existente = await repos.areas.salvar(Area(nome: 'Sede'));
    final dados = await garantirDadosExemplo(repos);

    expect(dados.sede.id, existente.id);
    expect((await repos.areas.listarTodos()).length, 1);
  });
}
