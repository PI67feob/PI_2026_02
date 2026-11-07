## Não lançado

### Adicionado

- POO: `Entidade` (base com id), `Aplicacao`, `AplicacaoInsumo`, `UnidadeDose` e a
  função `criarAplicador`.
- Exceções `DadoInvalidoException` e `RegistroNaoEncontradoException`.
- Lógica: `alertas_operacionais.dart` (chuva, capacidade e sobredose),
  `normalizacao_dose.dart` (líquido ou sólido) e `totais_desperdicio.dart`.
- Camada de dados: interfaces de repositório, implementação provisória em memória e
  `ConfiguracaoBanco` (lê as variáveis de ambiente).
- Serviços: `AplicacaoService` (registrar aplicação e resumo de desperdício),
  `TalhaoService` e `ParametrosOperacionais`.
- Demonstração no terminal em `bin/main.dart` (dados em memória).
- `banco/RESERVADO_PARA_SQL.md`: onde o SQL entra e o mapa entre tabelas e classes.
- `docs/fluxograma/fluxo_dados.md`: fluxograma do percurso do dado (PI-022).
- PI-023: repositórios MySQL em `lib/repositories/mysql/` (um por interface), com
  `ConexaoMysql` (conexão com TLS) e funções de apoio. Usam o pacote `mysql_client_plus`.
  `AplicacaoRepositoryMysql` grava a aplicação, os talhões e os insumos numa transação.
- `bin/main.dart --mysql` roda a demonstração no MySQL (sem o argumento, continua em
  memória). `bin/testar_conexao.dart` confere a conexão.
- `dart_test.yaml` com a tag `mysql` e teste de integração do `AreaRepositoryMysql`, que só
  roda com as variáveis `DB_*` exportadas (sem elas é pulado, e o CI segue sem banco).
- Testes das funções de conversão do repositório MySQL (`ajuda_mysql_test.dart`).
- Menu interativo em `bin/caderno.dart` (código em `lib/cli/`): cadastros, registro de
  aplicação, consultas, resumo de desperdício, calculadora com uma opção para cada função de
  `lib/logica`, parâmetros operacionais e dados de exemplo. Roda em memória e, com `--mysql`,
  no banco.
- `Repositorios` (`lib/repositories/repositorios.dart`): monta os seis repositórios, em
  memória ou no MySQL. `garantirDadosExemplo` (`lib/cli/dados_exemplo.dart`): cria os
  cadastros de exemplo sem duplicar.
- Testes do menu em `test/cli/`, com o `TerminalSimulado` (terminal com respostas prontas).
- Testes para tudo o que foi adicionado.

### Alterado

- `Area`, `Talhao`, `Insumo`, `Operacao` e `Aplicador` passaram a validar os dados no
  construtor e nos setters. Campos obrigatórios agora são `required` e não aceitam
  valor vazio ou inválido.
- `.env.example`: variáveis trocadas de PostgreSQL para MySQL e **sem valores**
  (só os nomes).
- `.gitignore`: passa a ignorar `*.local.sql` (scripts SQL com senha real) e
  `global-bundle.pem` (certificado público da AWS, que cada pessoa baixa).
- `README.md`: reescrito para explicar o código (camadas, papel de cada classe, fluxo
  principal, como rodar e onde o SQL entra). Removidas as menções a `Funcionario`,
  `Maquinario`, estoque mínimo e `bi/dashboard.pbix`, que não existem mais.
- `docs/fluxograma/fluxograma.md`: aviso de que está desatualizado, com links para a
  versão atual.
- `README.md` e `banco/RESERVADO_PARA_SQL.md`: passam a descrever o repositório MySQL,
  como rodar com `--mysql` e o mapa entre as tabelas do banco e as classes.
- `bin/main.dart` passou a usar `Repositorios`, `garantirDadosExemplo` e as funções de
  `lib/cli/formato.dart`, em vez de ter cópias próprias. A saída da demonstração não mudou.
- `README.md`: seção "Usando o menu" e o menu na estrutura, na arquitetura e no roteiro da
  apresentação.

## 1.0.0

- Initial version.
