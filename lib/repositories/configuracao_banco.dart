import 'dart:io';

import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';

/// Dados de conexão com o MySQL, lidos só de variáveis de ambiente.
///
/// As variáveis estão listadas no `.env.example` e explicadas em
/// `banco/RESERVADO_PARA_SQL.md`: `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER` e
/// `DB_PASSWORD`. Nenhum valor fica escrito no código, e a senha nunca aparece
/// em mensagem de erro nem em [toString].
///
/// Esta classe só lê e confere os dados. Quem abre a conexão é o repositório
/// MySQL (PI-023), que recebe uma [ConfiguracaoBanco] pronta.
class ConfiguracaoBanco {
  /// Endereço do servidor MySQL (variável `DB_HOST`).
  final String host;

  /// Porta do servidor (variável `DB_PORT`).
  final int porta;

  /// Nome do schema (variável `DB_NAME`).
  final String nomeBanco;

  /// Usuário da aplicação, nunca o root (variável `DB_USER`).
  final String usuario;

  /// Senha do usuário (variável `DB_PASSWORD`). Nunca é impressa.
  final String senha;

  /// Cria a configuração com os dados já conferidos.
  const ConfiguracaoBanco({
    required this.host,
    required this.porta,
    required this.nomeBanco,
    required this.usuario,
    required this.senha,
  });

  /// Lê a configuração das variáveis de ambiente.
  ///
  /// Sem argumento, usa as variáveis do sistema. Nos testes, passe um mapa em
  /// [ambiente].
  ///
  /// Lança [DadoInvalidoException] se alguma variável não estiver definida (ou
  /// estiver vazia) ou se a porta não for um número de 1 a 65535.
  factory ConfiguracaoBanco.doAmbiente([Map<String, String>? ambiente]) {
    final variaveis = ambiente ?? Platform.environment;
    final porta = int.tryParse(_ler(variaveis, 'DB_PORT').trim());
    if (porta == null || porta < 1 || porta > 65535) {
      throw DadoInvalidoException('DB_PORT', 'use um número de 1 a 65535');
    }
    return ConfiguracaoBanco(
      host: _ler(variaveis, 'DB_HOST').trim(),
      porta: porta,
      nomeBanco: _ler(variaveis, 'DB_NAME').trim(),
      usuario: _ler(variaveis, 'DB_USER').trim(),
      senha: _ler(variaveis, 'DB_PASSWORD'),
    );
  }

  static String _ler(Map<String, String> variaveis, String nome) {
    final valor = variaveis[nome] ?? '';
    if (valor.trim().isEmpty) {
      throw DadoInvalidoException(nome, 'variável de ambiente não definida');
    }
    return valor;
  }

  @override
  String toString() {
    return 'ConfiguracaoBanco($usuario@$host:$porta/$nomeBanco, senha: ***)';
  }
}
