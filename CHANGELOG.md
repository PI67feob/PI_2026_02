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

## 1.0.0

- Initial version.
