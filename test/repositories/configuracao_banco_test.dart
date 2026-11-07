import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';
import 'package:caderno_fazenda/repositories/configuracao_banco.dart';
import 'package:test/test.dart';

import '../ajuda/erros.dart';

void main() {
  var recusa = throwsA(isA<DadoInvalidoException>());

  // Valores falsos, so para os testes. Nada aqui e credencial de verdade.
  Map<String, String> ambiente() {
    return {
      'DB_HOST': 'servidor-teste',
      'DB_PORT': '3306',
      'DB_NAME': 'banco_teste',
      'DB_USER': 'usuario_teste',
      'DB_PASSWORD': 'dummy-valor-fake',
    };
  }

  group('ConfiguracaoBanco.doAmbiente', () {
    test('le as cinco variaveis', () {
      var config = ConfiguracaoBanco.doAmbiente(ambiente());

      expect(config.host, 'servidor-teste');
      expect(config.porta, 3306);
      expect(config.nomeBanco, 'banco_teste');
      expect(config.usuario, 'usuario_teste');
      expect(config.senha, 'dummy-valor-fake');
    });

    test('tira os espacos das pontas, menos da senha', () {
      var variaveis = ambiente();
      variaveis['DB_HOST'] = ' servidor-teste ';
      variaveis['DB_PORT'] = ' 3307 ';
      variaveis['DB_PASSWORD'] = ' dummy fake ';

      var config = ConfiguracaoBanco.doAmbiente(variaveis);

      expect(config.host, 'servidor-teste');
      expect(config.porta, 3307);
      expect(config.senha, ' dummy fake ');
    });

    test('variavel ausente lanca DadoInvalidoException', () {
      for (var nome in ambiente().keys) {
        var variaveis = ambiente();
        variaveis.remove(nome);

        expect(() => ConfiguracaoBanco.doAmbiente(variaveis), recusa);
      }
    });

    test('variavel vazia ou so com espacos lanca DadoInvalidoException', () {
      for (var nome in ambiente().keys) {
        var variaveis = ambiente();
        variaveis[nome] = '   ';

        expect(() => ConfiguracaoBanco.doAmbiente(variaveis), recusa);
      }
    });

    test('a mensagem cita o nome da variavel', () {
      var variaveis = ambiente();
      variaveis.remove('DB_HOST');

      var mensagem = mensagemDoErro(() {
        ConfiguracaoBanco.doAmbiente(variaveis);
      });

      expect(
        mensagem,
        'Dado inválido: DB_HOST (variável de ambiente não definida)',
      );
    });

    test('porta fora de 1 a 65535 ou nao numerica e recusada', () {
      for (var porta in ['abc', '0', '-1', '65536', '33.06']) {
        var variaveis = ambiente();
        variaveis['DB_PORT'] = porta;

        expect(() => ConfiguracaoBanco.doAmbiente(variaveis), recusa);
      }
    });

    test('aceita os extremos da porta', () {
      for (var porta in ['1', '65535']) {
        var variaveis = ambiente();
        variaveis['DB_PORT'] = porta;

        var config = ConfiguracaoBanco.doAmbiente(variaveis);

        expect(config.porta, int.parse(porta));
      }
    });
  });

  group('ConfiguracaoBanco.toString', () {
    test('mostra os dados de conexao e esconde a senha', () {
      var config = ConfiguracaoBanco.doAmbiente(ambiente());
      var texto = config.toString();

      expect(texto, contains('usuario_teste@servidor-teste:3306/banco_teste'));
      expect(texto, contains('***'));
      expect(texto, isNot(contains('dummy-valor-fake')));
    });
  });
}
