# Banco de dados: pasta reservada para o SQL

> **Status:** o SQL vem da frente de Modelagem de Dados / DBA; a frente de POO e
> Lógica **não escreve tabelas**. O repositório MySQL (PI-023) está pronto e
> funciona no banco da AWS. Este arquivo diz onde o SQL entra, o que o código
> espera dele e como as classes se ligam às tabelas. Os arquivos `.sql` do DBA
> ainda precisam ser versionados em `banco/`.

## 1. O que existe hoje

O programa funciona **com ou sem banco**. Toda a persistência passa por
interfaces (`lib/repositories/interfaces/`) e há duas implementações: a
provisória, em memória (`lib/repositories/memoria/`), e a do MySQL
(`lib/repositories/mysql/`). Trocar uma pela outra não muda nenhuma regra de
negócio.

| Peça | Onde está | Estado |
| --- | --- | --- |
| Interfaces de repositório | `lib/repositories/interfaces/` | pronto |
| Implementação provisória (mock em memória) | `lib/repositories/memoria/` | pronto |
| Leitura das variáveis de conexão | `lib/repositories/configuracao_banco.dart` | pronto |
| Nomes das variáveis | `.env.example` | pronto (só nomes) |
| Implementação MySQL | `lib/repositories/mysql/` | pronto (PI-023) |
| `schema.sql` | `banco/schema.sql` | **reservado** (PI-012) |
| `roles.sql` e `banco/README.md` | `banco/` | **reservados** (PI-014) |
| Seeds (dados iniciais) | `banco/seeds/` | **reservada** (PI-017) |
| Triggers de auditoria | `banco/triggers.sql` | **reservado** (PI-018) |

O banco da AWS (`caderno_fazenda`) já tem as tabelas e os 14 triggers de
auditoria. Falta só versionar os scripts nas pastas acima.

## 2. O que NÃO foi feito de propósito

- Não há `CREATE TABLE`, nem `schema.sql` de rascunho. Um arquivo provisório
  poderia ser confundido com o definitivo e brigar com o da PI-012.
- Não há senha em nenhum arquivo versionado. O `.env` e qualquer `*.local.sql`
  (por exemplo `roles.local.sql`, a cópia do `roles.sql` com a senha real) estão no
  `.gitignore`.

## 3. Como as classes se ligam às tabelas

Os nomes de tabela abaixo seguem a PI-012. O banco real (`caderno_fazenda`) usa
chaves `id_<tabela>` (por exemplo `talhao.id_area` no lugar de `area_id`); a
subseção *Mapeamento no banco real*, mais abaixo, lista as diferenças. Se algum
nome ou coluna mudar, só o repositório MySQL muda.

| Tabela | Classe Dart | Interface de repositório | Observações |
| --- | --- | --- | --- |
| `area` | `Area` | `AreaRepository` | nome da área |
| `talhao` | `Talhao` | `TalhaoRepository` | `area_id`; `UNIQUE (area_id, nome)`; `hectares > 0` |
| `insumo` | `Insumo` | `InsumoRepository` | nome, marca (opcional) e tipo; **sem** unidade de medida |
| `aplicador` | `Aplicador` (`Trator`, `Drone`, `BombaCostal`) | `AplicadorRepository` | coluna `tipo` vira a subclasse via `criarAplicador`; as duas capacidades podem ser nulas |
| `operacao` | `Operacao` | `OperacaoRepository` | descrição |
| `aplicacao` | `Aplicacao` | `AplicacaoRepository` | `data` é DATE; **não** há coluna de volume de calda (ele é calculado) |
| `aplicacao_talhao` | lista `Aplicacao.talhoes` | `AplicacaoRepository.salvar` | N:N; chave primária composta pelas duas chaves estrangeiras |
| `aplicacao_insumo` | `AplicacaoInsumo` | `AplicacaoRepository.salvar` | N:N com dose; unidade só `L/ha` ou `kg/ha` |

Fora do escopo desta entrega (não têm classe Dart): `compra`, `item_compra` e
`historico_alteracoes`. A auditoria é feita pelos triggers do banco (PI-018), não
pelo Dart.

### Regras que o repositório MySQL precisa respeitar

1. **Transação em `AplicacaoRepository.salvar`.** Uma `Aplicacao` ocupa três
   tabelas (`aplicacao`, `aplicacao_talhao`, `aplicacao_insumo`). Ou grava as
   três ou não grava nenhuma (`START TRANSACTION` / `COMMIT` / `ROLLBACK`).
2. **Erro técnico não vaza.** Qualquer falha do driver vira
   `PersistenciaException`, inclusive a violação do `UNIQUE (area_id, nome)`
   (o mock já faz isso). O `TalhaoService` confere o nome antes de gravar e
   recusa com `TalhaoInvalidoException`, que é a mensagem que o usuário vê.
3. **Consultas com parâmetros.** Nunca montar SQL concatenando texto.
4. **Tipos numéricos.** `DECIMAL` do banco precisa virar `double` (alguns drivers
   entregam texto). Hectares, doses e capacidades nunca são `FLOAT` no banco.
5. **Aplicador.** Ler o texto de `tipo` (`'trator'`, `'drone'`, `'bomba costal'`)
   e chamar `criarAplicador`. Capacidade nula no banco vira `null` no objeto.
6. **Nome de talhão** é comparado sem diferenciar maiúsculas de minúsculas
   (collation do MySQL), como no mock.
7. **Usuário `agrogestor_app`**, nunca o `root`.

### Mapeamento no banco real (`caderno_fazenda`)

O que o repositório MySQL faz para encaixar as classes nas tabelas do DBA:

- **Chaves.** Todas se chamam `id_<tabela>` (`id_area`, `id_talhao`,
  `id_aplicacao`...), e as chaves estrangeiras seguem o mesmo padrão
  (`talhao.id_area`).
- **Operação.** `Operacao.descricao` é gravada na coluna `operacao.nome`, que é
  `UNIQUE`.
- **Aplicador.** A coluna `modelo` é `NOT NULL`, mas o modelo é opcional na
  classe: sem modelo, grava-se texto vazio, e na leitura o texto vazio volta a
  ser `null`.
- **Datas** vão como `AAAA-MM-DD` para a coluna `data_aplicacao` (`DATE`).
- **Decimais** (hectares, doses, capacidades) são arredondados para as casas da
  coluna antes de enviar, para não mandar ruído de ponto flutuante como
  `0.30000000000000004`.
- **Comparação de texto** usa a collation `utf8mb4_0900_ai_ci`: não diferencia
  maiúsculas nem acentos. `Pulverizacao` e `Pulverização` são a mesma operação.
- **Aplicação.** `salvar` regrava as linhas de `aplicacao_talhao` e
  `aplicacao_insumo`, e `remover` apaga as filhas antes da aplicação, tudo na
  mesma transação. Por isso funciona com `ON DELETE CASCADE` ou com `RESTRICT`.
- **Auditoria.** Os triggers de `insumo`, `aplicacao`, `aplicacao_insumo` e
  `aplicacao_talhao` gravam em `historico_alteracoes`. `area`, `talhao`,
  `operacao` e `aplicador` não têm trigger.

## 4. Como trocar o mock pelo MySQL

Na PI-023, as classes de `lib/repositories/mysql/` passaram a implementar as
mesmas interfaces (por exemplo `TalhaoRepositoryMysql implements
TalhaoRepository`). Para usar o MySQL no lugar da memória:

1. Abrir a conexão (TLS, com o `global-bundle.pem` na raiz do projeto):
   `final banco = await ConexaoMysql.abrir(ConfiguracaoBanco.doAmbiente());`
2. Passar `banco` aos repositórios: `AreaRepositoryMysql(banco)`,
   `TalhaoRepositoryMysql(banco)`, `InsumoRepositoryMysql(banco)`,
   `AplicadorRepositoryMysql(banco)`, `OperacaoRepositoryMysql(banco)` e
   `AplicacaoRepositoryMysql(banco, operacoes: ..., aplicadores: ...,
   talhoes: ..., insumos: ...)`.
3. Os serviços (`TalhaoService`, `AplicacaoService`) continuam iguais, porque só
   conhecem as interfaces.
4. No fim, `await banco.fechar()`.

O `bin/main.dart` faz exatamente isso quando recebe `--mysql`.

**Pacote.** A PI-023 usa `mysql_client_plus`. Motivos: fala com o MySQL 8.4 do
RDS (senha `caching_sha2_password`), conecta com TLS, aceita parâmetros nomeados
(`:nome`) e permite transação (`START TRANSACTION` / `COMMIT` / `ROLLBACK`).

**Testes.** Os que precisam de MySQL de verdade usam `@Tags(['mysql'])`,
declarada em `dart_test.yaml`, e só rodam com as variáveis `DB_*` exportadas
(sem elas o grupo é pulado). `dart test -t mysql` roda só esses e `dart test -x
mysql` roda todos os outros. O CI não define as variáveis, então continua
rodando `dart test` sem banco, sem precisar mudar o `ci.yml`.

## 5. Variáveis de ambiente

Os nomes estão no `.env.example`. O código lê com
`ConfiguracaoBanco.doAmbiente()`, que recusa variável ausente ou vazia e porta
fora de 1 a 65535, e nunca imprime a senha.

| Variável | Para que serve | Exemplo (sem senha) |
| --- | --- | --- |
| `DB_HOST` | servidor do MySQL | `127.0.0.1` |
| `DB_PORT` | porta | `3306` |
| `DB_NAME` | schema | `caderno_fazenda` |
| `DB_USER` | usuário da aplicação (nunca `root`) | `agrogestor_app` |
| `DB_PASSWORD` | senha | definida só no `.env` local |

> O `.env` **não** é lido automaticamente: exporte as variáveis no terminal
> (`set -a; source .env; set +a`, no bash/zsh) antes de rodar.
>
> A conexão usa TLS: o `global-bundle.pem` (certificado público da AWS, ignorado
> pelo Git) precisa estar na pasta de onde o programa roda. O comando para
> baixá-lo está no `README.md`.

## 6. Pontos de atenção para o DBA

- **Conflito de nomes.** A PI-012 manda `schema agrogestor` e chave primária
  `id`. Os scripts de seed recebidos (pasta `SQL FINALIZANDO`, ainda fora do
  repositório) usam o banco `caderno_fazenda` e chaves `id_<tabela>`
  (`id_area`, `id_talhao`...). Um dos dois padrões precisa ser escolhido pelo
  grupo. O repositório MySQL hoje segue o padrão do banco real; se o grupo
  escolher o outro, só `lib/repositories/mysql/` muda (o resto do código Dart não
  conhece esses nomes).
- **Tipos.** Doses e hectares em `DECIMAL`, nunca `FLOAT`/`DOUBLE`.
- **Unidades da dose.** O banco aceita só `'L/ha'` e `'kg/ha'`. O Dart converte
  todas as outras unidades (mL/ha, g/ha, L/1000 L...) antes de gravar.
- **Volume de calda** não tem coluna (decisão D1 em aberto): é calculado.
- **Auditoria.** Triggers rodam depois do schema e dos seeds, para a carga
  inicial não encher o histórico.
- **Quem alterou.** Os triggers gravam `USER()`, que é `agrogestor_app@<IP>`:
  mostra de qual computador veio a alteração, não qual pessoa a fez (a decisão
  D5, sobre como identificar funcionários, segue em aberto).
