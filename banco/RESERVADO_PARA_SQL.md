# Banco de dados: pasta reservada para o SQL

> **Status:** reservada. A frente de POO e Lógica **não criou nenhuma tabela
> definitiva**. O SQL vem de outra frente (Modelagem de Dados / DBA) e este
> arquivo diz onde ele entra e o que o código já espera dele.

## 1. O que existe hoje

O programa funciona **sem banco**. Toda a persistência passa por interfaces
(`lib/repositories/interfaces/`) e a implementação provisória guarda os dados em
memória (`lib/repositories/memoria/`). Quando o MySQL ficar pronto, só a
implementação troca. Nenhuma regra de negócio muda.

| Peça | Onde está | Estado |
| --- | --- | --- |
| Interfaces de repositório | `lib/repositories/interfaces/` | pronto |
| Implementação provisória (mock em memória) | `lib/repositories/memoria/` | pronto |
| Leitura das variáveis de conexão | `lib/repositories/configuracao_banco.dart` | pronto |
| Nomes das variáveis | `.env.example` | pronto (só nomes) |
| Implementação MySQL | `lib/repositories/mysql/` | **reservada** (PI-023) |
| `schema.sql` | `banco/schema.sql` | **reservado** (PI-012) |
| `roles.sql` e `banco/README.md` | `banco/` | **reservados** (PI-014) |
| Seeds (dados iniciais) | `banco/seeds/` | **reservada** (PI-017) |
| Triggers de auditoria | `banco/triggers.sql` | **reservado** (PI-018) |

## 2. O que NÃO foi feito de propósito

- Não há `CREATE TABLE`, nem `schema.sql` de rascunho. Um arquivo provisório
  poderia ser confundido com o definitivo e brigar com o da PI-012.
- Não foi escolhido o pacote Dart que fala com o MySQL. Essa escolha (e o motivo)
  é registrada no PR da PI-023.
- Não há senha em nenhum arquivo versionado. O `.env` e qualquer `*.local.sql`
  (por exemplo `roles.local.sql`, a cópia do `roles.sql` com a senha real) estão no
  `.gitignore`.

## 3. Como as classes se ligam às tabelas

Os nomes de tabela abaixo seguem a PI-012. **Confirme com o `schema.sql` quando
ele existir**: se algum nome ou coluna mudar, só o repositório MySQL muda.

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

## 4. Como trocar o mock pelo MySQL

Hoje o `bin/main.dart` monta os repositórios em memória. Na PI-023:

1. Criar as classes de `lib/repositories/mysql/` implementando as mesmas
   interfaces (por exemplo `TalhaoRepositoryMysql implements TalhaoRepository`).
2. Ler a conexão com `ConfiguracaoBanco.doAmbiente()`.
3. Em `bin/main.dart`, trocar `TalhaoRepositoryMemoria()` pela versão MySQL. Os
   serviços (`TalhaoService`, `AplicacaoService`) continuam iguais, porque só
   conhecem as interfaces.
4. Testes que precisarem de MySQL de verdade usam `@Tags(['mysql'])`, declarada
   em `dart_test.yaml`, e o CI roda `dart test -x mysql`. Mexer no
   `.github/workflows/ci.yml` afeta o time inteiro: avisar o grupo (decisão da
   PI-023).

## 5. Variáveis de ambiente

Os nomes estão no `.env.example`. O código lê com
`ConfiguracaoBanco.doAmbiente()`, que recusa variável ausente ou vazia e porta
fora de 1 a 65535, e nunca imprime a senha.

| Variável | Para que serve | Exemplo (sem senha) |
| --- | --- | --- |
| `DB_HOST` | servidor do MySQL | `127.0.0.1` |
| `DB_PORT` | porta | `3306` |
| `DB_NAME` | schema | `agrogestor` |
| `DB_USER` | usuário da aplicação (nunca `root`) | `agrogestor_app` |
| `DB_PASSWORD` | senha | definida só no `.env` local |

> O `.env` **não** é lido automaticamente: exporte as variáveis no terminal, ou
> combine com a frente da PI-023 se quiserem um carregador de `.env`.

## 6. Pontos de atenção para o DBA

- **Conflito de nomes.** A PI-012 manda `schema agrogestor` e chave primária
  `id`. Os scripts de seed recebidos (pasta `SQL FINALIZANDO`, ainda fora do
  repositório) usam o banco `caderno_fazenda` e chaves `id_<tabela>`
  (`id_area`, `id_talhao`...). Um dos dois padrões precisa ser escolhido pelo
  grupo. O código Dart **não depende** dessa escolha (os nomes só aparecem no
  repositório MySQL).
- **Tipos.** Doses e hectares em `DECIMAL`, nunca `FLOAT`/`DOUBLE`.
- **Unidades da dose.** O banco aceita só `'L/ha'` e `'kg/ha'`. O Dart converte
  todas as outras unidades (mL/ha, g/ha, L/1000 L...) antes de gravar.
- **Volume de calda** não tem coluna (decisão D1 em aberto): é calculado.
- **Auditoria.** Triggers rodam depois do schema e dos seeds, para a carga
  inicial não encher o histórico.
