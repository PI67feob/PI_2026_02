# Relatório da branch 13: POO, Lógica e ambiente para o SQL

| Campo | Conteúdo |
| --- | --- |
| **Data** | 06/11/2026 |
| **Branches** | 4 branches em sequência (PI-015, PI-016, PI-020 e PI-022), todas continuação da `feat/PI-013-polimorfismo-aplicadores` (lista na seção Processo) |
| **Autor** | João Hélio (escrito com apoio do Claude) |
| **Escopo** | Concluir POO e Lógica de Programação, deixar o ambiente pronto para o SQL e documentar |

## 1. Resumo

O projeto agora roda de ponta a ponta no terminal, **sem banco**: cadastra áreas, talhões,
insumos, aplicadores e operações, registra uma aplicação (convertendo doses, calculando
calda, aplicando as regras da fazenda e calculando desperdício) e totaliza o desperdício.
O acesso a dados passa por interfaces, com uma implementação provisória em memória. O MySQL
entra depois, no lugar dela, sem mudar nenhuma regra de negócio.

Nenhuma tabela definitiva foi criada. O SQL vem da frente de Modelagem de Dados.

## 2. Arquivos criados e alterados

### Alterados (já existiam)

| Arquivo | O que mudou |
| --- | --- |
| `lib/models/area.dart`, `talhao.dart`, `insumo.dart`, `operacao.dart`, `aplicador.dart` | Passaram a herdar de `Entidade` e a validar os dados (campos privados com `get` e `set`). Os campos obrigatórios viraram `required`. |
| `bin/main.dart` | Reescrito como demonstração do fluxo completo, com repositórios em memória. |
| `.env.example` | Variáveis de PostgreSQL trocadas por MySQL e **sem valores** (só os nomes). |
| `.gitignore` | Nova linha `*.local.sql`, para um `roles.local.sql` com senha real nunca ser versionado (PI-014). |
| `README.md` | Reescrito para explicar o código. Removidas as menções desatualizadas. |
| `CHANGELOG.md` | Nova seção "Não lançado". |
| `docs/fluxograma/fluxograma.md` | Aviso de que está desatualizado, com links para a versão atual. |
| `test/models/*_test.dart` (área, talhão, insumo, operação, aplicador) | Testes originais mantidos; foi acrescentado o grupo de validações. |

### Criados

| Pasta | Arquivos | Papel |
| --- | --- | --- |
| `lib/exceptions/` | `dado_invalido_exception.dart`, `registro_nao_encontrado_exception.dart` | Duas exceções novas na hierarquia de `AgroGestorException`. |
| `lib/models/` | `entidade.dart`, `validacoes.dart`, `unidade_dose.dart`, `aplicacao_insumo.dart`, `aplicacao.dart`, `aplicador_fabrica.dart` | Base com id, validações, enum de unidade, classe de associação, classe central e fábrica de aplicadores. |
| `lib/logica/` | `alertas_operacionais.dart`, `normalizacao_dose.dart`, `totais_desperdicio.dart` | Regras de chuva, capacidade e sobredose; decisão líquido ou sólido; totais por unidade. |
| `lib/repositories/interfaces/` | `repository.dart` e um contrato por entidade (área, talhão, insumo, aplicador, operação, aplicação) | Contratos de persistência, todos assíncronos. |
| `lib/repositories/memoria/` | `repositorios_memoria.dart` | Implementação provisória que imita o banco (ids, `UNIQUE` do talhão, banco fora do ar). |
| `lib/repositories/` | `configuracao_banco.dart`, `mysql/.gitkeep` | Leitura das variáveis de ambiente; pasta reservada para o MySQL (PI-023). |
| `lib/services/` | `aplicacao_service.dart`, `talhao_service.dart`, `parametros_operacionais.dart`, `dose_informada.dart`, `resultado_aplicacao.dart` | Casos de uso e seus dados de entrada e saída. |
| `test/` | 17 arquivos novos em `ajuda/`, `exceptions/`, `logica/`, `models/`, `repositories/` e `services/` | Testes de tudo o que foi criado. |
| `banco/` | `RESERVADO_PARA_SQL.md` | Onde o SQL entra e o mapa entre tabelas e classes. |
| `docs/fluxograma/` | `fluxo_dados.md` | Fluxograma do percurso do dado (PI-022), em Mermaid. |
| `docs/sprints/` | este relatório | |

## 3. Decisões tomadas e por quê

### Estrutura e POO

| Decisão | Por quê |
| --- | --- |
| Manter a stack e a estrutura (Dart 3, `lints`, `test`, pastas `lib/*`) e **não adicionar dependência** | O pedido era não mudar nada sem necessidade. O `pubspec.yaml` ficou intacto. |
| Classe base `Entidade` com `id` | O id é gerado pelo banco e não pode mudar depois de definido. Em um lugar só, evita repetir a regra em cada classe. |
| Encapsulamento com validação nos setters | O objeto nunca fica inválido, nem depois de criado. A mesma regra vale no construtor e no setter. |
| `Aplicacao` por **composição**, com `AplicacaoInsumo` como classe de associação | A aplicação é N:N com talhão e com insumo, e cada insumo carrega a própria dose. |
| `criarAplicador` (fábrica) | O banco guarda o tipo como texto; a fábrica devolve a subclasse certa. É onde o polimorfismo encontra a persistência. |
| Repositórios por **interface**, todos com `Future` | Os drivers de MySQL para Dart são assíncronos. Assim a troca do mock pelo MySQL não muda o serviço. |
| Mock com `bancoIndisponivel` e regra `UNIQUE` do talhão | Permite testar o tratamento de erro de banco e a unicidade sem MySQL. |
| Erro técnico do banco vira `PersistenciaException` | Erro de driver não pode vazar para o usuário nem para o serviço. |
| Não criar classes para compra, item de compra, histórico, funcionário e estoque | Compra e histórico são de outras frentes (o histórico é feito por trigger); funcionário e estoque são decisões em aberto (D5 e D3). |

### Lógica

| Decisão | Por quê |
| --- | --- |
| Funções de `lib/logica` são **puras** e devolvem enum; quem lança exceção é o serviço | É o que a PI-016 pede. Decidir e reagir são responsabilidades separadas. |
| Chuva em **exatamente 3 h**: não reaplicar (**PENDENTE** com a fazenda) | Leitura literal de "menos de 3 horas" e evita reaplicar sem necessidade, que é o desperdício que o projeto combate. O parâmetro `reaplicarNoLimite: true` inverte sem mexer no código. |
| Sobredose: `ok` até o previsto, `atencao` até a tolerância, `critico` acima | A PI-016 pede ok, atenção e crítico, e a tolerância como parâmetro. |
| Tolerância de sobredose **obrigatória** e sem valor padrão | Quem define o valor aceitável é o agrônomo. A demonstração usa 10% só como exemplo. |
| Duas bases de dose: **L/ha** (líquido) e **kg/ha** (sólido), sem converter uma na outra | Converter exige a densidade do produto, que a fazenda não tem. O banco só aceita essas duas unidades. |
| `g/1000L` e `kg/1000L` continuam **PENDENTES** | Ainda não foram conferidas com o agrônomo (já registrado em `base_normalizacao.md`). |
| Uma aplicação é **uma carga** para a regra da capacidade | Foi a leitura mais simples. Fica **PENDENTE** de confirmação como lançar uma aplicação que precise de várias cargas. |
| Capacidade nula (trator) não é conferida | A capacidade do trator ainda não foi levantada. |
| Volume de calda **calculado**, nunca gravado | Decisão D1 em aberto, e a PI-012 manda não criar coluna de volume. |
| Nome de talhão comparado sem diferenciar maiúsculas | Acompanha o comportamento do MySQL com a collation padrão. |
| Fator de compra (0,95) e limite da chuva (3 h) como parâmetros com valor padrão | A regra não fica escondida dentro da conta. |

### Ambiente para o SQL

| Decisão | Por quê |
| --- | --- |
| Uma pasta reservada com `banco/RESERVADO_PARA_SQL.md`, **sem** `schema.sql` provisório | Um rascunho poderia ser confundido com o definitivo e brigar com o da PI-012. |
| `.env.example` só com **nomes**; exemplos ficam em comentário | A PI-023 pede "nomes e nenhum valor". O nome do schema ainda tem conflito (ver pontos de atenção). |
| `ConfiguracaoBanco` lê só do ambiente e esconde a senha no `toString` | Credenciais nunca ficam no código nem em mensagem de erro. |
| Nada de `dart_test.yaml` com a tag `mysql` e nada no CI | Mexer no `ci.yml` afeta o time inteiro e é tarefa da PI-023. |

### Processo

| Decisão | Por quê |
| --- | --- |
| Os 20 commits foram criados e publicados, **sem merge** | O autor é João Hélio e cada commit traz o Claude como coautor no rodapé. Nada foi mergeado na `main`: o caminho do time é um Pull Request por branch, revisado por outra frente. |
| Os commits vão em **4 branches em sequência**, todas continuação da `feat/PI-013-polimorfismo-aplicadores`, e não numa branch só | A regra do time é uma branch `feat/PI-xxx` por tarefa, e branch pequena é mais fácil de revisar. Cada uma sai da ponta da anterior (e a primeira, da 13, não da `main`) porque uma parte usa o código da outra. |
| Os números das branches são **015, 016, 020 e 022** | Eles pulam as tarefas de banco (012, 014, 017 e 018) e de BI (019, 021, 024 e 025), que são de outras frentes. A 016 (alertas operacionais) e a 022 (fluxograma) são tarefas que este trabalho entrega. As tarefas 015 e 020 não constavam nos documentos de tarefas usados; se os números não corresponderem, basta renomear as branches. |
| Dart SDK **não** foi instalado por contorno da política de rede | O ambiente bloqueia o download; não burlei a política. |

Ordem das branches (cada uma sai da ponta da anterior; a primeira sai da `feat/PI-013-polimorfismo-aplicadores`):

1. `feat/PI-015-poo-modelos-validados`: POO, commits C01 a C07.
2. `feat/PI-016-logica-regras-operacionais`: Lógica, commits C08 a C10.
3. `feat/PI-020-servicos-e-demonstracao`: interfaces e repositórios em memória, configuração do banco, serviços, demonstração e ambiente para o SQL, commits C11 a C18.
4. `feat/PI-022-docs-fluxograma-readme`: documentação, commits C19 e C20.

## 4. Validação

**Não foi possível executar `dart format`, `dart analyze`, `dart test` nem `dart run`**, porque o SDK do Dart não está disponível neste ambiente (o download é bloqueado pela política de rede).
O que foi feito no lugar:

| Verificação | Resultado |
| --- | --- |
| Sintaxe de todos os `.dart` (analisador tree-sitter) | ver seção 7 |
| Imports não usados ou faltando (script próprio) | ver seção 7 |
| Formatação (script próprio, heurística do formatador do Dart) | ver seção 7 |
| Números esperados nos testes e na demonstração | Conferidos com um port em Python das mesmas fórmulas |
| Compatibilidade dos construtores já existentes (`dados_teste.dart` etc.) | Conferida chamada por chamada |
| Mermaid do fluxograma e da arquitetura | Renderizados com o Mermaid CLI, sem erro |
| Senhas em arquivos versionados | Nenhuma (busca feita; ver seção 7) |

**Isso não substitui o CI.** O primeiro passo ao receber o projeto é rodar `dart pub get`,
`dart format .`, `dart analyze --fatal-infos`, `dart test` e `dart run bin/main.dart`, e
comparar a saída com a do README (que foi calculada, não executada).

## 5. Pendências

**Com a fazenda ou o agrônomo**

- Chuva em exatamente 3 horas: reaplicar ou não.
- Valor da tolerância de sobredose.
- Doses de produto sólido por 1000 L de calda (`g/1000L`, `kg/1000L`).
- Capacidade do trator.
- Como lançar uma aplicação que precisa de mais de uma carga.

**Com outras frentes**

- Escolher o padrão de nomes do banco: `agrogestor` e chave `id` (PI-012) ou `caderno_fazenda` e `id_<tabela>` (scripts de seed recebidos).
- `schema.sql`, `roles.sql`, seeds e triggers (PI-012, PI-014, PI-017, PI-018).
- Repositório MySQL, `dart_test.yaml` com a tag `mysql` e `dart test -x mysql` no CI (PI-023).
- Revisar `docs/fluxograma/fluxo_dados.md` quando `banco/README.md` e `bi/documentacao/modelo_dimensional.md` entrarem na `main`.

**No código**

- `AplicacaoService.registrar` exige `taxaLitrosPorHa` mesmo quando a aplicação tem só produto sólido (o volume fica nulo). Pode ser relaxado depois.
- Não há classe Dart para compra, item de compra e histórico de alterações.
- Sobraram os arquivos de modelo do `dart create`: `bin/pi.dart`, `lib/pi.dart` e `test/pi_test.dart`.

## 6. Pontos de atenção

1. **Mudança de API nos models.** `Area`, `Talhao`, `Insumo`, `Operacao` e `Aplicador` deixaram de ter campos nulos e públicos: agora os campos obrigatórios são `required` e validados. Código de outras branches que crie esses objetos sem os campos (ou atribua `null`) vai quebrar no merge. Dentro desta branch, todas as chamadas foram conferidas.
2. **O merge fica fora desta entrega.** As branches estão publicadas, mas nada foi mergeado na `main`. O caminho do time é um Pull Request por branch, na ordem PI-015, PI-016, PI-020 e PI-022, revisado por outra frente. Se o repositório mergear com squash, a próxima branch da sequência precisa ser atualizada sobre a `main` depois de cada merge.
3. **Resultado da demonstração.** A saída mostrada no README foi calculada, não executada. Confira na primeira execução.
4. **Segredos.** `.env` está no `.gitignore`. O `.env.example` não tem valor algum. Nenhuma senha foi escrita em arquivo.
5. **Transação no banco.** No repositório MySQL, `AplicacaoRepository.salvar` precisa gravar as três tabelas da aplicação em **uma transação**.
6. **README do repositório.** Foram removidas as menções a `Funcionario`, `Maquinario`, estoque mínimo e `dashboard.pbix`, que não condizem com o modelo atual (o arquivo do BI, pela PI-019, é `bi/agrogestor.pbix`). Também foi corrigido o trecho que dizia guardar nome, função e matrícula de funcionários.

## 7. Resultado das verificações automáticas

Executadas em 06/11/2026 sobre `lib/`, `bin/` e `test/` (todos os arquivos `.dart`):

| Verificação | Resultado |
| --- | --- |
| Sintaxe (tree-sitter) | **0** arquivos com erro de parse |
| Imports | **0** problemas (nenhum sobrando, faltando ou inexistente) |
| Formatação (heurística) | 24 avisos, **todos esperados**: 8 linhas de `import` acima de 80 colunas (o formatador não quebra imports), 14 linhas antigas de arquivos que já passavam no CI (textos longos que o formatador não quebra) e 2 falsos positivos de parâmetros nomeados (`, {`) |
| Segredos | Nenhuma senha em arquivo versionado. Só aparecem o nome `DB_PASSWORD` e o valor falso `dummy-valor-fake` nos testes. O `.env` está no `.gitignore` e não existe no projeto |

Os avisos de formatação são de uma heurística e **não** de `dart format`: só o CI confirma.
