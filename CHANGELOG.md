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
- `test/cli/sessoes_aleatorias_test.dart`: 250 sessões sorteadas no menu (semente fixa) que
  falham se aparecer "Erro inesperado" ou se sobrar um registro apontando para outro que
  foi excluído.
- `viagensNecessarias` (`lib/logica/calculos_calda.dart`): quantas viagens o aplicador faz
  para levar uma quantidade (divisão arredondada para cima).
- `AplicacaoService.calcularCarga`: calcula, sem gravar, o volume de calda, a massa de
  sólidos e as viagens. O menu usa na conferência antes de gravar.
- `ResultadoAplicacao.viagensCalda` e `viagensSolidos`.
- Menu: opções **8 (Corrigir um registro)** e **9 (Excluir um registro)** para área, talhão,
  insumo, aplicador, operação e aplicação (código em `lib/cli/menu_manutencao.dart`).
  Corrigir mostra o que vai mudar e só grava depois da confirmação; excluir recusa o que
  está em uso e pede a confirmação (padrão "não"). A dose realizada de uma aplicação é
  corrigida em mL/ha, L/ha, g/ha ou kg/ha, com aviso quando passa de 10 vezes a prevista.
- `ManutencaoService` (`lib/services/manutencao_service.dart`) e
  `ExclusaoNegadaException`: as regras de corrigir e excluir, iguais na memória e no MySQL.
- `Interacao.editarTexto`, `editarTextoOpcional`, `editarNumero`, `editarNumeroOpcional` e
  `editarData` (Enter mantém o valor atual), e `plural`, `descreverInsumo`,
  `descreverTalhao` e `descreverAplicacao` em `formato.dart`.

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
- A capacidade do aplicador passou a valer **por viagem**: uma aplicação maior que ela não é
  mais recusada, é gravada inteira e o resultado informa as viagens necessárias (o drone de
  70 kg aplicando 76 kg faz 2 viagens). O menu mostra a carga e as viagens na conferência e
  no resultado, e não pergunta mais por "outra taxa". A calculadora (opção Capacidade)
  também mostra as viagens. `avaliarCapacidade` e `ResultadoCapacidade` continuam, agora
  com o sentido "cabe numa viagem só?".
- `bin/main.dart`: o exemplo de erro de capacidade virou um exemplo de aplicação com mais de
  uma viagem (só calcula, não grava). A saída da demonstração mudou nessa parte.
- `TalhaoService.corrigir` corrige o nome e/ou os hectares (confere o nome repetido na área
  e não altera nada se algum valor for recusado). `corrigirHectares` continua e usa o novo
  método.
- Menu: a opção "Corrigir os hectares" saiu de Cadastros e passou para a opção 8
  (Talhão). Os números das opções 1 a 7 não mudaram.
- Menu: o talhão cadastrado ou corrigido aparece como `[1] Sede / Chico1 - 2,80 ha` (com
  vírgula e o tamanho em ha), e a lista dos dados de exemplo também. A demonstração
  (`bin/main.dart`) continua mostrando o `obterDados()` do model.

### Corrigido

- `avaliarSobredose`: uma dose exatamente na tolerância (por exemplo 0,33 contra 0,3 com
  tolerância de 10%, ou 330 contra 300 mL/ha) saía como "crítico" por causa do
  arredondamento do ponto flutuante (10,000000000000009%). Agora é "atenção", como a regra
  diz ("menor ou igual à tolerância"). Mexe em `lib/logica/alertas_operacionais.dart`.

### Removido

- `CapacidadeExcedidaException` e o teste dela, que deixaram de ser usados.

## 1.0.0

- Initial version.
