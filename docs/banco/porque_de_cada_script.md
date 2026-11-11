# Banco de dados do Caderno de Campo: o que cada script faz e por que existe

**Projeto Integrador UNIFEOB 2026/2 · frente Modelagem de Dados / DBA · documento de 10/11/2026**
Banco: `caderno_fazenda` (MySQL 8.x, AWS RDS) · Repositório: <https://github.com/PI67feob/PI_2026_02>

Este documento reúne **todos os scripts que a equipe usou no banco de dados** e explica, de cada um:
**o que faz**, **por que foi escrito**, **quando rodar**, **o que muda no banco**, **quais cuidados tem** e **o que foi
realmente testado**. Foi escrito para quem vai apresentar a frente de Modelagem de Dados e precisa responder
"e por que vocês fizeram assim?". Há uma lista de perguntas prováveis na seção 8.

## Sumário

1. [Resumo em um minuto e mapa das peças](#1-resumo-em-um-minuto-e-mapa-das-peças)
2. [Linha do tempo](#2-linha-do-tempo)
3. [O modelo: tabela por tabela e por que ficou assim](#3-o-modelo-tabela-por-tabela-e-por-que-ficou-assim)
4. [Script por script](#4-script-por-script)
5. [Como o programa (Dart) usa o banco](#5-como-o-programa-dart-usa-o-banco)
6. [Técnicas que se repetem nos scripts, explicadas](#6-técnicas-que-se-repetem-nos-scripts-explicadas)
7. [O que foi testado e com que resultado](#7-o-que-foi-testado-e-com-que-resultado)
8. [Perguntas que a banca pode fazer](#8-perguntas-que-a-banca-pode-fazer)
9. [Pontos em aberto e riscos conhecidos](#9-pontos-em-aberto-e-riscos-conhecidos)
10. [Segurança: o que nunca vai para o Git](#10-segurança-o-que-nunca-vai-para-o-git)
11. [Glossário](#11-glossário)
12. [Apêndices A a D (dados de apoio)](#apêndices)

---

## Como ler (legenda e mapa de arquivos)

**Legenda de confiança.** Cada afirmação sobre comportamento do banco vem com uma destas marcas:

| Marca | Significa |
|---|---|
| ✔ `T4` | Reproduzido em 10/11/2026 pelo `banco/validacao/validar_cadeia.sh` (o código do teste, como `T4`, aparece na seção 7), num MySQL 8.0.46 descartável. |
| ✔ manual | Reproduzido em 10/11/2026 à mão, no mesmo MySQL 8.0.46, e que não faz parte do `validar_cadeia.sh`. |
| ◇ relatado | Vem de um print do grupo (Discord), de um `LEIA-ME` ou do cabeçalho do script; **não foi repetido hoje**. |
| ✘ não verificado | Nada foi executado para confirmar (por exemplo, o código Dart, que não foi compilado nem testado aqui). |

**Onde cada arquivo está.** O repositório e o pacote entregue ao grupo usam pastas diferentes para os mesmos arquivos:

| No repositório (`PI_2026_02/`) | No pacote (`2026-11-10_pacote_banco_de_dados/scripts/…`) |
|---|---|
| `banco/schema.sql` | `01_banco_do_zero/scripts_separados/criar_banco.sql` |
| `banco/triggers.sql` | `01_banco_do_zero/scripts_separados/triggers.sql` |
| `banco/seeds/01_base_RECONSTRUIDO.sql` | `01_banco_do_zero/scripts_separados/seeds/01_base_RECONSTRUIDO.sql` |
| `banco/seeds/02_areas_operacoes.sql` | `01_banco_do_zero/scripts_separados/seeds/02_areas_operacoes.sql` |
| `banco/seeds/03_compras.sql` | `01_banco_do_zero/scripts_separados/seeds/03_compras.sql` |
| `banco/seeds/opcionais/04_aplicacoes_drone_CONFERIR.sql` | `01_banco_do_zero/scripts_separados/seeds/04_aplicacoes_drone_CONFERIR.sql` |
| `banco/recriar_do_zero/tudo_em_um.sql` | `01_banco_do_zero/tudo_em_um.sql` |
| `banco/testes/conferencia.sql` | `01_banco_do_zero/testes/conferencia.sql` |
| `banco/testes/auditoria.sql` | `01_banco_do_zero/testes/auditoria.sql` |
| `banco/testes/usuario_app_LOCAL.sql` | `01_banco_do_zero/testes/usuario_app_LOCAL.sql` |
| `banco/alter_aplicacao_reaplicacao.sql` | `02_alter_reaplicacao/alter_aplicacao_reaplicacao.sql` |
| `tool/aplicar_sql.dart` | `03_triggers_no_rds/tool/aplicar_sql.dart` (e `triggers.local.sql`, cópia idêntica do `triggers.sql`) |
| `banco/povoamento/povoamento_caderno_de_campo.sql` (versão 7) | `04_povoamento_v7/povoamento_caderno_de_campo.sql` |
| `banco/povoamento/LEIA-ME.txt` | `04_povoamento_v7/LEIA-ME.txt` |
| `banco/povoamento/historico/povoamento_v6_executado_no_rds.sql` | `05_povoamento_v6_executado_no_rds/povoamento_caderno_de_campo.sql` |
| `banco/povoamento/corrigir_ids.sql` | `06_corrigir_ids/corrigir_ids.sql` |
| `banco/povoamento/desfazer_dados_ficticios.sql` | `07_desfazer/desfazer_dados_ficticios.sql` |
| `banco/povoamento/apagar_so_os_exemplos.sql` | `07_desfazer/apagar_so_os_exemplos.sql` |
| `banco/validacao/validar_cadeia.sh` | `../validacao/validar_cadeia.sh` |
| *(fora do repositório, de propósito)* `seed_auditoria.sql` | `08_legado_postgres_auditoria/seed_auditoria.sql` |
| *(fora do repositório, não é do banco)* `renomear-arquivos.py` | `09_fora_do_banco/renomear-arquivos.py` |

Nas seções seguintes os arquivos são citados pelo **nome do repositório**.

---

## 1. Resumo em um minuto e mapa das peças

**O que o banco guarda.** O caderno de campo de uma fazenda de café: **onde** se trabalhou (área e talhão), **com quê**
(aplicador: trator, drone ou bomba costal; insumo), **o que** foi feito (operação e aplicação), **quanto** foi previsto e
quanto foi realmente aplicado (a diferença é o desperdício), as **compras** de insumo e um **histórico de alterações** que
ninguém consegue apagar. São **11 tabelas** e **14 triggers**.

**Quem conversa com ele.** O programa em Dart (`dart run bin/caderno.dart --mysql`), pelo usuário `agrogestor_app`, que só
pode ler e gravar dados (`SELECT`, `INSERT`, `UPDATE`, `DELETE`), nunca mudar a estrutura. A estrutura só é mexida por
quem tem usuário administrador (o DBA).

**Mapa das peças (ordem de execução num banco novo):**

```
 schema.sql ──► seeds 01 · 02 · 03 ──► triggers.sql ──► alter_aplicacao_reaplicacao.sql
 (11 tabelas)   (a base do Diogo)       (14 triggers)     (2 colunas que o BI usa)
      └─ tudo_em_um.sql = estes três de uma vez ──┘
        (APAGA o banco; o ALTER de reaplicação roda depois, separado)
                                      │
                                      ▼
            povoamento_caderno_de_campo.sql (v7)
            dados REAIS dos mapas e da planilha da auditoria + dados FICTÍCIOS para a demonstração
                 │                          │
                 ▼                          ▼
          corrigir_ids.sql      desfazer_dados_ficticios.sql · apagar_so_os_exemplos.sql

 testes/ : conferencia.sql · auditoria.sql · usuario_app_LOCAL.sql
 tool/aplicar_sql.dart : aplica um .sql no RDS pelo terminal (usado para os triggers)
 validacao/validar_cadeia.sh : roda tudo isso num MySQL local descartável e confere 87 resultados
```

**Três situações de uso, e o que rodar em cada uma:**

| Situação | O que rodar | Cuidado |
|---|---|---|
| **A. Banco novo, no computador de alguém (MySQL 8.0.16+)** | `tudo_em_um.sql` → `testes/conferencia.sql` → `alter_aplicacao_reaplicacao.sql` → (opcional) `povoamento_caderno_de_campo.sql` | `tudo_em_um.sql` começa com `DROP DATABASE`: apaga o banco inteiro. A `conferencia.sql` vale **antes** do povoamento: depois dele as contagens mudam e as linhas dizem `DIFERENTE` (esperado). |
| **B. O banco que já está no ar (RDS da equipe)** | **Não** rodar `schema.sql` nem `tudo_em_um.sql`. Para atualizar: `povoamento_caderno_de_campo.sql` (cria o que faltar e não duplica), e, se os números das aplicações estiverem pulados, `corrigir_ids.sql` com o usuário do DBA. Triggers pelo `tool/aplicar_sql.dart`. | Qualquer arquivo com `DROP DATABASE` apagaria os dados da equipe. |
| **C. Ensaio e apresentação** | Ensaiar no terminal → `apagar_so_os_exemplos.sql` → `corrigir_ids.sql` (antes de apresentar, para a numeração não pular) → apresentar → depois `desfazer_dados_ficticios.sql` | O número (id) de uma linha apagada não volta sozinho. |

> **Regra de ouro:** só os arquivos de `banco/povoamento/` e `banco/alter_aplicacao_reaplicacao.sql` foram escritos para rodar
> **num banco que já tem dados**. Os de `schema.sql`, `recriar_do_zero/` e `seeds/` são para **banco vazio**.

---

## 2. Linha do tempo

As datas vêm do cabeçalho dos arquivos, do histórico do Git e da data das entradas dos zips recebidos.

| Data | O que aconteceu | De onde vem a informação |
|---|---|---|
| 07/09/2026 | O Samuel consolida a planilha `auditoria-dados.xlsx` (97 arquivos da fazenda), que é a fonte dos dados reais. | `README_dados.md` |
| 17/10/2026 | O Diogo Bordin escreve o modelo físico: o `schema.sql` (no pacote, `criar_banco.sql`). | cabeçalho do arquivo |
| 20/10/2026 | Commit "Reformulação das tabelas SQL" do Diogo cria `banco/fazendanovo.sql` na branch `feat/PI-08-atualizacao-modelo`. O conteúdo é **idêntico** ao `schema.sql` (só muda a última linha em branco). A branch **não foi mesclada na `main`**. | `git log` e `diff` |
| 06/11/2026 | Pacote "banco do zero": `tudo_em_um.sql`, seeds, triggers e testes. | `00_LEIA-ME.txt` ("Gerado em 06/11/2026") |
| 07/11/2026 | `tool/aplicar_sql.dart` e `triggers.local.sql`, para aplicar os triggers no RDS pelo terminal (17:32). Atualização de reaplicação: código Dart e o `ALTER TABLE` (21:29). | zips `aplicar_triggers` e `atualizacao_reaplicacao` |
| 08/11/2026 | Atualização da interface do menu (00:03) e pacote "código do banco" para a apresentação (00:18). | zips `atualizacao_interface` e `codigo_banco` |
| 10/11/2026 (de madrugada) | O povoamento versão 6 roda no RDS e os números das aplicações saem pulados; o Diogo roda o `corrigir_ids.sql` no RDS: **71 aplicações, ids 7..135 passam a 1..71, próximo id 72**. | prints do grupo (◇ relatado) |
| 10/11/2026 | Povoamento versão 7 (ids em sequência, cria a base do Diogo se faltar), `corrigir_ids.sql`, `desfazer_dados_ficticios.sql`, `apagar_so_os_exemplos.sql`. Validação da cadeia inteira: 87 de 87 conferências OK (MySQL 8.0.46). | `banco/validacao/` |

**Quem fez o quê** (as frentes do README): o **Diogo** (Modelagem de Dados / DBA) é o autor do schema e dono dos
triggers e dos seeds; o **Bruno** (BI) é quem devia fornecer o `01_base.sql` oficial e o `roles.sql` (ainda não chegaram);
o **Samuel** (BI) consolidou os dados da auditoria; o **João** e o **Cristiano** (POO / Backend) fazem o código Dart que
fala com o banco; o **Joaquim** (Lógica) faz as funções de cálculo.

---

## 3. O modelo: tabela por tabela e por que ficou assim

Autor: Diogo Bordin (17/10/2026), derivado do DER lógico citado no cabeçalho (`docs/modelagem/der_completo.md`, que
**ainda não está no repositório**; `docs/modelagem/` só tem um `.gitkeep`). Todas as chaves se chamam `id_<tabela>`;
todas as restrições têm nome com prefixo (`pk_`, `fk_`, `uk_`, `ck_`), o que torna as mensagens de erro legíveis e permite
mexer na restrição pelo nome depois.

### 3.1 As 11 tabelas

| Tabela | Colunas (tipo) | Restrições | Por que existe |
|---|---|---|---|
| `area` | `id_area` INT AI · `nome` VARCHAR(100) NOT NULL · `descricao` VARCHAR(255) NULL | PK | Agrupa talhões: Sede, Bela Vista, Corujas, Serra II. **Sem UNIQUE no nome:** nada no banco impede duas áreas com o mesmo nome (o povoamento detecta nomes repetidos e para). |
| `talhao` | `id_talhao` · `id_area` FK · `nome` VARCHAR(100) · `hectares` DECIMAL(10,2) NOT NULL · `localizacao` VARCHAR(255) NULL | `UNIQUE (id_area, nome)` · FK para `area` · `CHECK hectares > 0` | Parcela de uma área. O nome só precisa ser único **dentro da área** (o mesmo nome pode existir em áreas diferentes). |
| `operacao` | `id_operacao` · `nome` VARCHAR(100) · `descricao` VARCHAR(255) NULL | `nome` UNIQUE | Tipo de trabalho: Adubação, Pulverização. Vocabulário fechado, sem duplicata. |
| `aplicador` | `id_aplicador` · `modelo` VARCHAR(100) NOT NULL · `tipo` ENUM('trator','drone','bomba costal') NOT NULL · `capacidade_max_litros` DECIMAL(10,2) NULL · `capacidade_max_kg` DECIMAL(10,2) NULL | `CHECK` de cada capacidade: nula ou > 0 | O equipamento. A capacidade é o **máximo por viagem** (o programa usa para calcular quantas viagens). Pode ser nula quando ainda não foi levantada (é o caso do trator). |
| `insumo` | `id_insumo` · `nome` VARCHAR(150) NOT NULL · `marca` VARCHAR(100) NULL · `tipo` VARCHAR(80) NOT NULL | PK | O produto aplicado. **Sem unidade de medida:** a unidade pertence à compra (`item_compra`) e à dose (`aplicacao_insumo`). |
| `aplicacao` | `id_aplicacao` · `id_operacao` FK · `id_aplicador` FK · `data_aplicacao` DATE NOT NULL · `observacao` VARCHAR(255) NULL | FKs para `operacao` e `aplicador` | O fato central: uma operação feita num dia, com um aplicador. O próprio schema registra uma **pendência**: "um aplicador por aplicação (pendência dos dois equipamentos em aberto)". |
| `aplicacao_talhao` | `id_aplicacao` · `id_talhao` | PK composta (`id_aplicacao`, `id_talhao`) · FK `aplicacao` **ON DELETE CASCADE** · FK `talhao` | N:N: uma aplicação cobre vários talhões, e um talhão recebe várias aplicações. A regra "toda aplicação tem ao menos um talhão" **não** é do banco (ele só garante as chaves): é do programa. |
| `aplicacao_insumo` | `id_aplicacao` · `id_insumo` · `dose_prevista` DECIMAL(10,3) NOT NULL · `dose_realizada` DECIMAL(10,3) NULL · `unidade_dose` ENUM('L/ha','kg/ha') NOT NULL | PK composta · FK `aplicacao` **ON DELETE CASCADE** · FK `insumo` · `CHECK` doses ≥ 0 | N:N com atributos: a dose pertence ao **par** aplicação × insumo. `dose_realizada` fica vazia até a aplicação acontecer; **previsto × realizado é o desperdício**. |
| `compra` | `id_compra` · `data_compra` DATE NOT NULL · `numero_nota` VARCHAR(50) NULL | PK | Cabeçalho da compra (a nota fiscal). |
| `item_compra` | `id_item_compra` · `id_compra` FK · `id_insumo` FK · `quantidade` DECIMAL(12,3) NOT NULL · `unidade_medida` ENUM('litro','galão','kg','grama','tonelada','unidade') NOT NULL · `preco_unitario` DECIMAL(12,2) NULL | FK `compra` **ON DELETE CASCADE** · FK `insumo` · `CHECK quantidade > 0`, `preco_unitario` nulo ou ≥ 0 | Linhas da nota. **Sem UNIQUE (compra, insumo)** de propósito: a mesma nota pode trazer o mesmo produto em duas linhas. |
| `historico_alteracoes` | `id_historico` BIGINT AI · `tabela_afetada` VARCHAR(64) · `chave_registro` VARCHAR(100) · `acao` ENUM('INSERT','UPDATE','DELETE') · `dados_anteriores` JSON NULL · `dados_novos` JSON NULL · `usuario` VARCHAR(100) · `data_hora` DATETIME DEFAULT CURRENT_TIMESTAMP | PK. **Sem chave estrangeira.** | Tabela técnica de auditoria, preenchida pelos triggers e protegida contra alteração e exclusão. |

Depois do `ALTER TABLE` de reaplicação, `aplicacao` ganha `horas_ate_chuva` DECIMAL(6,2) NULL e `motivo_reaplicacao`
VARCHAR(20) NULL (seção 4.9). Depois do povoamento, o banco passa a ter **12 tabelas**: o povoamento cria a tabela de
controle `registro_dados_ficticios` (seção 4.12), que **não** faz parte do `schema.sql`.

### 3.2 Por que cada escolha (as justificativas que você pode dar)

| Decisão | Justificativa | Custo ou limite |
|---|---|---|
| `DECIMAL` e nunca `FLOAT`/`DOUBLE` para hectares, doses, preços, quantidades | Precisão exata: `0.1 + 0.2` dá `0.3` em `DECIMAL` e `0.30000000000000004` em ponto flutuante. Para dinheiro e dose isso importa. | O driver às vezes devolve `DECIMAL` como texto: o Dart converte para `double` e arredonda para as casas da coluna antes de gravar. |
| `ENUM` para `aplicador.tipo`, `aplicacao_insumo.unidade_dose` e `item_compra.unidade_medida` | Domínio **fechado** e conhecido; o próprio banco recusa valor fora da lista (um `CHECK` embutido), e ocupa 1 byte. | Mudar a lista exige `ALTER TABLE`. O programa converte as outras unidades (mL/ha, g/ha, L/1000 L…) para `L/ha` ou `kg/ha` **antes** de gravar. |
| `CHECK` (`hectares > 0`, doses ≥ 0, `quantidade > 0`…) | Impede dado impossível mesmo que alguém grave direto por SQL, sem passar pelo programa. | **Só valem a partir do MySQL 8.0.16.** Em versão anterior o `CHECK` é aceito e ignorado, e no MariaDB o comportamento é outro. Por isso o `conferencia.sql` começa conferindo `VERSION()`. ✔ `T1`, `T2` (o `CHECK` de motivo recusa `'granizo'`, erro 3819). |
| Collation `utf8mb4_0900_ai_ci` | Acentos e caixa não diferenciam: `Pulverizacao` e `Pulverização` são a mesma operação; o `UNIQUE` de `operacao.nome` também ignora isso. `utf8mb4` guarda acentos e emojis sem perda. | Comparações com texto exigem a mesma collation na conexão: por isso os scripts de povoamento começam com `SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci`. |
| Tabelas de ligação com **chave primária composta** | A própria chave impede repetir o par (a mesma aplicação com o mesmo talhão duas vezes). | Não há `id` próprio; o histórico usa o `id_aplicacao` como `chave_registro`. |
| `ON DELETE CASCADE` em `aplicacao_talhao`, `aplicacao_insumo` e `item_compra` | Apagar o cabeçalho leva as linhas filhas junto, sem sobrar linha órfã. | **O cascata não dispara os triggers das filhas** (✔ `X1`): a auditoria registra a exclusão da aplicação, mas não a das filhas. A PI-012 e a PI-018 pedem `RESTRICT`; a decisão está em aberto (seção 9). |
| FKs restantes sem `ON DELETE` (o padrão `NO ACTION`, que no InnoDB **recusa** apagar o pai, como o `RESTRICT`) | Não dá para apagar um talhão, insumo, aplicador ou operação que está em uso. | O `desfazer` precisa apagar na ordem certa (filhas → pai). Em `information_schema` a regra aparece como `NO ACTION`, e não `RESTRICT`. |
| `historico_alteracoes` sem FK e com `chave_registro` em texto | É uma tabela **genérica**, que serve a 4 tabelas diferentes, e precisa **sobreviver** à exclusão do registro auditado. | Não há integridade referencial com o registro auditado (de propósito). |
| `dados_anteriores`/`dados_novos` em `JSON` | Um único formato para tabelas com colunas diferentes; o MySQL valida o JSON e permite consultar com `JSON_EXTRACT`. | Quem escreve o trigger lista as colunas à mão (e esquece colunas novas, ver seção 9). |
| Volume de calda **não tem coluna** | Decisão D1 (o README a lista como **em aberto**; na prática, hoje é um valor **calculado** pelo programa: hectares × taxa de aplicação em L/ha, função `volumeCalda` em `lib/logica/calculos_calda.dart`); guardar duplicaria a informação e poderia ficar inconsistente com os hectares do talhão. | O BI precisa recalcular, ou o programa expõe o cálculo. |
| `insumo.tipo` obrigatório (`NOT NULL`) | Permite agrupar no BI (Herbicida, Fungicida…). | O seed 01 usa o valor provisório `'Insumo'` (seção 4.2); o povoamento corrige 12 produtos pela planilha de defensivos. |

### 3.3 O que o banco **não** garante (e fica a cargo do programa)

1. **Toda aplicação ter pelo menos um talhão e um insumo.** O banco só garante as chaves. É por isso que o seed 04
   (6 voos de drone sem talhão nem insumo) **não** deve ser rodado no banco que o programa usa.
2. **Conversão de unidades.** O banco só aceita `L/ha` e `kg/ha`; o Dart converte o resto.
3. **Quem fez a alteração, como pessoa.** Os triggers gravam `USER()`, que é `agrogestor_app@<IP>`: mostra **de qual
   computador** veio a alteração, não **qual pessoa** a fez (decisão D5, em aberto).
4. **Mudança de colunas que os triggers não listam** (seção 9).

---

## 4. Script por script

Cada cartão responde: **o que é**, **por que existe**, **quando rodar**, **o que faz**, **o que muda no banco**, **cuidados** e
**o que foi verificado**. Os cartões seguem a ordem em que os scripts entram em cena.

---

### 4.1 `banco/schema.sql` (no pacote: `criar_banco.sql`)

**O que é.** O modelo físico: cria o banco `caderno_fazenda` e as 11 tabelas, com chaves, `UNIQUE`, `CHECK` e `ENUM`.
Autor: Diogo Bordin, 17/10/2026. Tarefa PI-012.

**Por que existe.** É a base de tudo: os seeds, os triggers, o programa Dart e o BI dependem dos nomes de tabela e
coluna que estão aqui.

**Quando rodar.** Uma única vez, num servidor **vazio**, MySQL 8.0.16 ou mais novo. **Nunca no RDS da equipe.**

**O que faz, passo a passo.**
1. `DROP DATABASE IF EXISTS caderno_fazenda;` (apaga o banco inteiro se já existir: serve para recriar do zero no
   desenvolvimento; o próprio cabeçalho manda tirar essa linha quando o banco tiver dados que importam).
2. `CREATE DATABASE caderno_fazenda CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;` e `USE caderno_fazenda;`.
3. Cria as tabelas **dos pais para os filhos** (a ordem importa porque uma chave estrangeira só pode apontar para uma
   tabela que já existe): `area`, `talhao`, `operacao`, `aplicador`, `insumo`, `aplicacao`, `aplicacao_talhao`,
   `aplicacao_insumo`, `compra`, `item_compra`, `historico_alteracoes`.

**O que muda no banco.** Cria o banco e as 11 tabelas (vazias).

**Cuidados.**
- O `DROP DATABASE` do início é a razão de os arquivos de `banco/recriar_do_zero/` e `banco/schema.sql` serem
  perigosos em banco com dados. O `tool/aplicar_sql.dart` os recusa se não receber `--permitir-drop-database`.
- `CHECK` só é imposto a partir do MySQL 8.0.16 (seção 3.2).
- O schema usa `id_<tabela>` e o banco `caderno_fazenda`; a PI-012 pedia `schema agrogestor` e chave `id`. O banco
  real seguiu o DBA e o código Dart se adapta (seção 9).

**Verificado.** ✔ `T1`: 11 tabelas, collation `utf8mb4_0900_ai_ci`, 14 triggers depois dos demais passos.

---

### 4.2 `banco/seeds/`: a carga inicial (a "base do Diogo")

Os seeds entram **depois** do schema e **antes** dos triggers. Os três primeiros formam a base; o quarto é opcional e,
na prática, **não deve ser rodado**.

#### `01_base_RECONSTRUIDO.sql` (PROVISÓRIO)

- **Por que se chama "reconstruído".** O `01_base.sql` oficial do Bruno **nunca chegou** ao Diogo. Para o banco poder ser
  recriado do zero, o arquivo foi montado a partir do que existia, e o cabeçalho pede: "quando o Bruno mandar o dele,
  compare e troque".
- **O que cria** (com ids explícitos, porque o `03_compras.sql` depende deles): 1 área (`Sede`, id 1); 5 talhões da Sede
  (2,80 + 3,80 + 2,05 + 4,90 + 6,40 = **19,95 ha**); 11 aplicadores (1 drone DJI de 70 L e 10 bombas costais Jacto de
  20 L); 43 insumos (ids 1 a 43). Veja os apêndices A e B.
- **De onde vem cada dado.** Nomes dos 43 insumos e dos 11 aplicadores: dados de teste do código Dart da equipe
  (histórico de 02/09). Capacidades (drone 70 L, bomba costal 20 L): da mesma fonte. Talhões e hectares: descrição do Bruno.
- **O que não tem fonte (e precisa ser conferido).** `insumo.tipo` (todos `'Insumo'`, valor provisório, porque a coluna é
  obrigatória); a capacidade em **kg** dos aplicadores (70 e 20: copiada igual à de litros); `insumo.marca` (vazia, nenhuma
  fonte tem).
- **Cuidado.** Rodar **uma vez**, em banco vazio. Rodar de novo dá erro 1062 (chave primária repetida), porque os ids são
  explícitos.

#### `02_areas_operacoes.sql`

- **O que faz.** Cria as outras 3 áreas (Bela Vista, Corujas e Serra II) com a área de produção da **estimativa 2026**
  na descrição (60,00; 31,98 e 30,60 ha) e a observação "talhões ainda não cadastrados"; atualiza a descrição da Sede
  ("19,95 ha; soma dos 5 talhões cadastrados"); cria as 2 operações (`Adubacao`, `Pulverizacao`).
- **Fonte.** Os CSVs da auditoria (`dados-produtividade.csv`, `dados-poda.csv`, `dados-aplicacoes-drone.csv`).
  O cabeçalho avisa: **sem** coordenadas, CNPJ, valores comerciais ou dados pessoais.

#### `03_compras.sql`

- **O que faz.** Cria **18 compras** (as notas fiscais de insumos agrícolas) e **43 itens**, com data da nota, número da
  nota, insumo, quantidade e unidade (40 em litro, 2 em kg, 1 em grama). **Dados reais** da fazenda (apêndice C).
- **O que não entra, de propósito:** preço, valor total, fornecedor e CNPJ.
- **O que ficou de fora, de propósito:** a nota 420.755 e a devolução 431.039 (se anulam); as notas 68.635 e 68.700
  (entregas da venda futura 68.606, que já está uma vez: carregar as três contaria o dobro); boletos, receitas,
  certificados, mudas, EPI e serviços (não são insumo de aplicação).
- **Fonte.** O índice de notas (`docs/check_inicial/samuel/indice-documentos.csv`).

#### `opcionais/04_aplicacoes_drone_CONFERIR.sql` (**não rodar**)

- **O que é.** 6 voos de drone lidos de **fotos da tela do controlador**, "leitura de foto, confiança média ou baixa".
  Cria só linhas em `aplicacao`; ficam **sem** `aplicacao_talhao` e **sem** `aplicacao_insumo`, porque o local da foto não
  bate com nenhum talhão cadastrado e os mapas não dizem o insumo nem a dose por hectare.
- **Por que não rodar no banco que o programa usa.** O programa **não abre** aplicação sem talhão e insumo (a regra é do
  programa, não do banco, seção 3.3). O próprio povoamento avisa: "NÃO rode o seed 04".
- **Se rodar depois dos triggers**, gera 6 linhas em `historico_alteracoes`.
- **Onde estão esses voos de verdade.** Na tabela opcional `aud_voo_drone` do `auditoria_dados_reais.sql` (seção 4.19).

**Verificado dos seeds.** ✔ `T1`: contagens `4 · 5 · 2 · 11 · 43 · 18 · 43` (área, talhão, operação, aplicador, insumo,
compra, item) e as 19 linhas `OK` do `conferencia.sql`.

---

### 4.3 `banco/triggers.sql`: auditoria e imutabilidade

**O que é.** 14 triggers, em um arquivo com `DELIMITER $$`. Tarefa PI-018.

**Por que existe.** Para que toda mudança nos dados que mais importam fique registrada, **no banco** (e não só no
programa): quem fez, quando, o que havia antes e o que passou a haver. E para que esse registro **não possa ser apagado nem
editado**.

**Quando rodar.** **Depois** do schema e dos seeds, para a carga inicial não encher o `historico_alteracoes`. Num banco
que já existe, pelo `tool/aplicar_sql.dart` (seção 4.8), porque o Workbench nem sempre roda blocos com `DELIMITER`.

**O que cria.**

| Grupo | Triggers | Quando disparam |
|---|---|---|
| Auditoria de `aplicacao` | `trg_aplicacao_ai`, `_au`, `_ad` | depois de INSERT, UPDATE, DELETE |
| Auditoria de `aplicacao_insumo` | `trg_aplicacao_insumo_ai`, `_au`, `_ad` | idem |
| Auditoria de `aplicacao_talhao` | `trg_aplicacao_talhao_ai`, `_au`, `_ad` | idem |
| Auditoria de `insumo` | `trg_insumo_ai`, `_au`, `_ad` | idem |
| Imutabilidade do histórico | `trg_historico_alteracoes_bu`, `trg_historico_alteracoes_bd` | **antes** de UPDATE e de DELETE |

**Como cada trigger de auditoria funciona.** Grava uma linha em `historico_alteracoes` com `tabela_afetada`,
`chave_registro`, `acao`, `dados_anteriores`, `dados_novos` (ambos montados com `JSON_OBJECT(...)`, listando as colunas
uma a uma), `usuario` (`USER()`) e `data_hora` (`NOW()`). No INSERT, `dados_anteriores` é `NULL`; no DELETE,
`dados_novos` é `NULL`. Nas tabelas de ligação, `chave_registro` é o **id da aplicação** (o id do insumo ou do talhão fica
no JSON).

**Como a imutabilidade funciona.** Os dois triggers `BEFORE` executam `SIGNAL SQLSTATE '45000'` com a mensagem
"historico_alteracoes é imutável: não é permitido alterar linhas" (ou "apagar linhas"). O MySQL devolve o erro **1644** e a
operação é desfeita. ✔ `T3`.

**Decisões de projeto (cada uma tem um porquê).**

| Decisão | Por quê |
|---|---|
| `USER()` e **não** `CURRENT_USER()` | Dentro de um trigger, `CURRENT_USER()` devolve quem **criou** o trigger (root ou admin), então toda linha diria "root". `USER()` devolve quem **realmente se conectou**. ✔ `T3` (administrador) e `U1` (a coluna mostra `agrogestor_app@localhost`, nunca `root@`). |
| **Sem `DEFINER`** | Sem a cláusula, o MySQL usa quem roda o script. Com `DEFINER=root@localhost`, o mesmo arquivo dá erro **1449** ("o usuário definido como definer não existe") no computador de quem usa outro administrador. |
| `DROP TRIGGER IF EXISTS` antes de cada `CREATE` | O arquivo pode rodar de novo: cada trigger é recriado. |
| `AFTER` na auditoria e `BEFORE` na imutabilidade | A auditoria só registra o que **foi aceito** (passou pelos `CHECK` e pelas chaves). O bloqueio precisa agir **antes** de a alteração acontecer. |
| Só 4 tabelas auditadas | `aplicacao`, `aplicacao_insumo`, `aplicacao_talhao` e `insumo` são o que muda no dia a dia e produz o desperdício. `area`, `talhao`, `operacao` e `aplicador` são cadastros estáveis e **não** têm trigger. |
| Triggers depois dos seeds | A carga inicial não deve encher o histórico. (O povoamento é a exceção: ele passa pelos triggers de propósito, ver 4.11.) |

**Limites que convém saber (e dizer, se perguntarem).**
- **O cascata não dispara trigger.** Se alguém apagar só a `aplicacao` e as filhas saírem por `ON DELETE CASCADE`, só o
  `DELETE` da aplicação é auditado. ✔ `X1`. O programa e os scripts de desfazer apagam as filhas **antes**, e aí tudo é
  auditado. ✔ `X2`.
- **Colunas novas não aparecem.** Os triggers de `aplicacao` não listam `horas_ate_chuva` nem `motivo_reaplicacao`: um
  `UPDATE` que mude **só** essas colunas gera uma linha de histórico com `dados_anteriores` **idêntico** a `dados_novos`
  (✔ manual: o JSON de antes e de depois saem iguais). Veja a seção 9.
- **Quem tem privilégio de administrador pode remover o trigger** (`DROP TRIGGER`) e `TRUNCATE`/`DROP TABLE` não disparam
  triggers. O usuário da aplicação não tem `DROP`, `TRIGGER` nem `ALTER` (✔ `U0`), e é isso que torna a imutabilidade
  efetiva para quem usa o programa. ✔ manual (MySQL 8.0.46, servidor de teste): com os dois triggers de imutabilidade ativos,
  o `DELETE` do administrador foi recusado (erro 1644), mas o `TRUNCATE TABLE historico_alteracoes` **esvaziou** a tabela sem
  erro; e um usuário só com `SELECT, INSERT, UPDATE, DELETE` recebeu **1644** em `UPDATE` e `DELETE` e **1142** ("command
  denied") em `TRUNCATE`, `DROP TRIGGER`, `DROP TABLE` e `ALTER TABLE`.
- `usuario` mostra o **computador** (`agrogestor_app@IP`), não a pessoa (decisão D5, em aberto).

**Verificado.** ✔ `T1` (14 triggers), `T3` (12 de auditoria e 2 de imutabilidade, UPDATE e DELETE no histórico recusados
com erro 1644), `U1` (com o usuário da aplicação), `X1`, `X2`.

---

### 4.4 `banco/recriar_do_zero/tudo_em_um.sql`

**O que é.** A concatenação, na ordem certa, de `schema.sql` → `01` → `02` → `03` → `triggers.sql`. O `04` fica de fora de
propósito, e o `ALTER` de reaplicação **também** (roda depois, ver 4.9).

**Por que existe.** Para o grupo recriar o banco inteiro com **um clique** no Workbench (raio, sem selecionar nenhuma linha)
e o resultado ser o mesmo para todos. Gerado em 06/11/2026.

**Cuidados.**
- **Apaga o banco** (herda o `DROP DATABASE` do schema).
- **Rodar inteiro, do começo.** Repetir só uma parte dá erro 1062.
- O `01` é o reconstruído (provisório).

**Verificado.** ✔ `T1`: terminou sem erro; 11 tabelas, 14 triggers, contagens esperadas, nenhuma linha em
`historico_alteracoes`.

---

### 4.5 `banco/testes/conferencia.sql`

**O que é.** Oito consultas de **só leitura** para mostrar na apresentação ("tire um print de cada resultado").

| # | O que confere | Esperado |
|---|---|---|
| 1 | `VERSION()` | 8.0.16 ou maior; "MariaDB" **não vale** |
| 2 | Linhas por tabela, com a coluna `situacao` (`OK` ou `DIFERENTE`) | 4 · 5 · 2 · 11 · 43 · 18 · 43 · 0 · 0 · 0 · 0 |
| 3 | Os 5 talhões e a soma de hectares | 19,95 |
| 4 | Total em litros de 7 notas (3257: 740; 6060: 183; 6671: 195; 6749: 206; 6855: 184; 6916: 61; 7292: 23) | todas `OK` |
| 5 | Itens de compra por unidade | litro 40, kg 2, grama 1 |
| 6 | Período das compras e insumos diferentes comprados | 25/04/2025 a 30/07/2026; 23 insumos |
| 7 | Triggers criados (e a lista deles) | 14 |
| 8 | Regra de DELETE de cada chave estrangeira (`information_schema.referential_constraints`) | serve à decisão CASCADE × RESTRICT |

Os itens 2 a 4 produzem **19 linhas `OK`** (11 tabelas + hectares + 7 notas). Usa `COUNT(1)` e não `COUNT(*)` de propósito:
o asterisco some quando se copia de um chat e causa o erro 1064.

**Quando rodar.** Logo **depois** do `tudo_em_um.sql`. **Depois do povoamento** a contagem esperada muda (70 aplicações,
29 talhões…), então as linhas passam a dizer `DIFERENTE`: isso é esperado, e quem confere o povoamento é a conferência
do próprio povoamento (4.11).

**Verificado.** ✔ `T1`: 19 linhas `OK`, 0 `DIFERENTE`.

---

### 4.6 `banco/testes/auditoria.sql`

**O que é.** A prova dos triggers da PI-018, em duas partes.

**Parte 1 (roda inteira).** Abre uma transação, cria os pais (`area`, `talhao`, `operacao`, `aplicador`) **dentro** dela,
faz `INSERT`, `UPDATE` e `DELETE` em `insumo`, `aplicacao`, `aplicacao_talhao` e `aplicacao_insumo`, mostra um resumo
(1 linha por tabela e ação, com a coluna `usuario`) e termina em **`ROLLBACK`**. Por isso não depende dos seeds e não deixa
linhas no banco.

**Parte 2 (comentada).** As tentativas que **devem falhar**: `UPDATE` e `DELETE` em `historico_alteracoes`. Cada comando
roda sozinho. Todo `UPDATE`/`DELETE` usa a chave primária no `WHERE` por causa do *safe update mode* do Workbench
(erro 1175).

**Como usar.** Duas vezes: como administrador e como `agrogestor_app`. Na segunda, a coluna `usuario` precisa mostrar
`agrogestor_app@…` e **não** `root`: é a prova do `USER()`.

**Cuidado conhecido.** O `ROLLBACK` desfaz as **linhas**, mas o contador `AUTO_INCREMENT` **não volta**. O teste usa os ids
9001 e 9002, então o próximo cadastro normal nessas tabelas sai com id perto de 9002 (talhão: 9003). Os dados não são
afetados. Se isso incomodar, rode o teste num banco de teste, não no oficial. ✔ `T3` confirma os contadores em 9002 (talhão
9003).

**Verificado.** ✔ `T3` (administrador): 12 linhas de resumo, todas com o usuário conectado, nenhum histórico depois do
`ROLLBACK`, `UPDATE` e `DELETE` no histórico recusados (1644). ✔ `U1` (como `agrogestor_app`): sem erro, `usuario` =
`agrogestor_app@localhost`.

---

### 4.7 `banco/testes/usuario_app_LOCAL.sql`

**O que é.** Um **modelo** para criar o usuário `agrogestor_app` no MySQL de **um computador local**:
`CREATE USER IF NOT EXISTS 'agrogestor_app'@'localhost' IDENTIFIED BY '<SENHA_QUE_VOCE_ESCOLHER>';` e
`GRANT SELECT, INSERT, UPDATE, DELETE ON caderno_fazenda.* TO 'agrogestor_app'@'localhost';`

**Por que existe.** Para testar a PI-018 (coluna `usuario`) com o usuário real da aplicação enquanto o `roles.sql` da
PI-014 não chega. Se o `roles.sql` do Bruno criar esse usuário, o dele vale e este arquivo é ignorado.

**Regras escritas no arquivo.**
- **A senha nunca é salva** no arquivo, no Git ou no chat: troque o marcador só na aba, rode e feche a aba **sem salvar**.
- **Não conceder `DROP` nem `TRIGGER`:** a PI-018 depende disso.
- Só serve para **teste local**.

**Por que só essas 4 permissões.** Princípio do menor privilégio: o programa só precisa ler e gravar dados. Sem `ALTER` e
sem `CREATE`, ele não consegue mudar a estrutura (✔ `U2`, `U3`), e sem `DROP`/`TRIGGER` não consegue remover a proteção do
histórico.

**Verificado.** ✔ `U0`: `SHOW GRANTS` mostra só `SELECT, INSERT, UPDATE, DELETE`. (Nos testes, a senha é gerada na hora,
ao acaso, e não é gravada.)

---

### 4.8 `tool/aplicar_sql.dart` (e `triggers.local.sql`)

**O que é.** Um programa Dart de linha de comando que **executa um arquivo `.sql` no MySQL da AWS, comando por comando**.
Criado em 07/11/2026.

**Por que existe.** O Workbench nem sempre roda arquivos com `DELIMITER` (os triggers) e o banco da AWS só aceitava conexão
pelo programa. O `aplicar_sql.dart` reaproveita a mesma conexão do programa (`ConexaoMysql`: TLS, variáveis `DB_*`).

**Como usar** (na raiz do projeto, com as variáveis do `.env` exportadas):

```
dart run tool/aplicar_sql.dart triggers.local.sql
```

**O que faz.**
1. Divide o arquivo em comandos. Entende `DELIMITER`, comentários (`--`, `#`, `/* */`) e textos entre aspas.
2. **Recusa `DROP DATABASE` e `DROP SCHEMA`** a menos que receba `--permitir-drop-database`.
3. Conecta como **administrador** (`DB_ADMIN_USER`, ou `admin` se não houver) e **pede a senha no terminal, sem mostrá-la**.
   A senha não é gravada em lugar nenhum. Host, porta e nome do banco vêm das mesmas variáveis `DB_*`.
4. Executa um por um, mostrando `[n/total]` e o início de cada comando. **Para no primeiro erro.**
5. No fim, conta os triggers do schema (`information_schema.triggers`).

**Por que conecta como administrador.** Criar triggers e tabelas exige mais permissão do que o usuário `agrogestor_app`
tem (e ele **não deve** ter).

**`triggers.local.sql`.** É uma cópia **idêntica** do `triggers.sql` (conferido com `cmp`). Existe porque `*.local.sql` está no
`.gitignore`: o padrão serve para scripts com senha real, e a equipe usava essa cópia para não commitar nada sem querer.
**No repositório não é preciso**: use `banco/triggers.sql` direto.

**Cuidados.**
- Roda até o primeiro erro e **não desfaz** o que já executou (DDL no MySQL não tem rollback).
- ✘ **Não foi compilado nem testado nesta validação** (não havia SDK Dart). Foi conferido por leitura contra a API do
  repositório (`ConexaoMysql.abrir`, `usar`, `fechar`, `ConfiguracaoBanco`, `PersistenciaException.causa`/`mensagem`), que
  casa. O CI do repositório roda `dart format --output=none --set-exit-if-changed .` e `dart analyze --fatal-infos`: rode os
  dois antes de abrir o PR.

---

### 4.9 `banco/alter_aplicacao_reaplicacao.sql`

**O que é.** Um `ALTER TABLE aplicacao` que adiciona duas colunas e dois `CHECK`.

| Coluna | Tipo | Significado |
|---|---|---|
| `horas_ate_chuva` | `DECIMAL(6,2) NULL` | horas entre o fim da aplicação e a chuva (`NULL` = não informada); `CHECK` nula ou ≥ 0 (`chk_aplicacao_horas_chuva`) |
| `motivo_reaplicacao` | `VARCHAR(20) NULL` | `'chuva'`, `'sol'`, `'vento'` ou `'outro'` (`NULL` = nada pede para refazer); `CHECK` (`chk_aplicacao_motivo_reaplicacao`) |

**Por que existe.** O Power BI agrupa por `motivo_reaplicacao` para contar as **reaplicações por imprevisto**, e
`horas_ate_chuva` guarda a distância até a chuva. O programa grava as duas colunas **em toda gravação** de aplicação.

**Quando rodar.** **Antes** de usar a versão nova do programa com `--mysql`. Sem as colunas, o `INSERT` do programa falha
(coluna desconhecida). Linhas antigas ficam com `NULL`. (O povoamento v7 cria as colunas sozinho se faltarem, no "passo 0".)

**Cuidados.**
- **Não é repetível.** Rodar de novo dá o erro **3822** (nome de `CHECK` já existe). ✔ `T2`. Para checar antes: `DESCRIBE aplicacao;`.
- **Os triggers de `aplicacao` não incluem as duas colunas** (seção 9). O próprio arquivo avisa: "se os triggers de auditoria
  listam as colunas uma a uma, vale incluir as duas novas neles".
- A escolha de `VARCHAR(20)` com `CHECK` (e não `ENUM`) está registrada no script, mas **o motivo não está escrito**.
  Uma justificativa plausível, que **não** consta no arquivo: com `CHECK` a lista pode mudar com um `ALTER` da restrição,
  sem reordenar o tipo.

**Verificado.** ✔ `T2`: colunas `horas_ate_chuva:decimal(6,2):YES` e `motivo_reaplicacao:varchar(20):YES`; o `CHECK` recusa
`'granizo'` (erro 3819); a segunda execução dá erro 3822.

---

### 4.10 O povoamento versão 6 (o que foi executado no RDS)

`banco/povoamento/historico/povoamento_v6_executado_no_rds.sql` (100.261 bytes) é o arquivo **exatamente como foi enviado
pelo grupo**, o que rodou no RDS. Fica guardado como registro. **Não** é para rodar de novo: use o v7.

**A diferença para a versão 7 é pequena e exata** (`diff`: 13 linhas): (1) um parágrafo novo no cabeçalho sobre os ids; (2) o
`INSERT INTO aplicacao` da etapa B4 passa a gravar os ids **explicitamente**
(`MAX(id_aplicacao) + ROW_NUMBER() OVER (ORDER BY t.n)`), em vez de deixar o MySQL escolher. Todo o resto é igual.

**Por que isso importava.** O `INSERT ... SELECT` de 70 linhas reservava ids em blocos (1, 2, 4, 8…) e **perdia** o que sobrava
do último: gastava **127** ids para 70 linhas, e a aplicação cadastrada depois pulava de 72 para **130**. ✔ `T4`.

**Verificado.** ✔ `T4` reproduz o cenário do RDS (ids 1 e 2 já "queimados" → o povoamento v6 começa no id 3): resultado
`4 · 29 · 2 · 16 · 45 · 28 · 69 · 70 · 329 · 111 · 535` (área, talhão, operação, aplicador, insumo, compra, item, aplicação,
aplicação_talhão, aplicação_insumo, histórico), ids de 3 a 72, próximo id **130**, e um cadastro manual recebe o **130**.

---

### 4.11 `banco/povoamento/povoamento_caderno_de_campo.sql` (versão 7)

**O que é.** O script que carrega **dados reais** (mapas impressos e planilha de defensivos da auditoria) e **dados
fictícios** para a demonstração. 101.104 bytes, 1.229 linhas.

> **Atenção sobre a origem deste arquivo.** O v7 deste pacote é uma **reconstrução**, feita a partir da conversa e conferida
> pelo tamanho (101.104 bytes), pelo `diff` mínimo contra o v6 (acima) e pelos resultados dos testes. O v6, que foi o
> executado, é o original enviado pelo grupo.

**Por que existe.** Para a apresentação ter um banco **cheio e coerente** (24 talhões reais, 70 aplicações, compras, doses
previstas e realizadas) sem ninguém digitar tudo, com a garantia de **nunca deixar o banco pela metade** e de **poder
desfazer só o que é fictício**.

**Quando rodar.** No Workbench, com **o usuário do DBA** (precisa de `CREATE` se a tabela de controle não existir e de `ALTER`
se faltarem as colunas de reaplicação): abrir o arquivo e clicar no raio (Execute All). **Pode rodar de novo**: não duplica.

**Mapa do arquivo (linhas aproximadas) e o porquê de cada parte.**

| Linhas | Etapa | O que faz | Por que existe |
|---|---|---|---|
| 1–77 | Cabeçalho | Como rodar, o que é real e o que é fictício, resultado esperado, aviso de auditoria, aviso de ids | Quem abre o arquivo entende o risco antes de rodar. |
| 78–82 | Preparação | `USE caderno_fazenda`; `SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci`; `SET SQL_SAFE_UPDATES = 0` | Acentos corretos e mesma collation das tabelas; o *safe update mode* do Workbench recusa `UPDATE`/`DELETE` sem chave. |
| 83–174 | **VERIFICAÇÃO PRÉVIA** (só leitura) | Confere 39 colunas que o script usa, as operações, as 4 áreas, os 5 talhões da Sede, os 8 aplicadores e os 15 insumos que ele usa, a compatibilidade dos 3 `ENUM` e nomes repetidos. Termina em **`PODE SEGUIR`** ou para. | O script liga dados novos a coisas que **já existem, pelo nome**. Quando um nome não existe o MySQL **não dá erro**: o `INSERT ... SELECT` grava 0 linhas. Foi assim que uma carga antiga deu "OK" e deixou 0 aplicações. Agora a verificação mostra isso **antes** de gravar. |
| 176–196 | **PASSO 0** | Cria as colunas de reaplicação se faltarem | Para o script funcionar mesmo antes do `ALTER` separado. |
| 197–210 | **PASSO 0b** | Cria a tabela de controle `registro_dados_ficticios` | Ver 4.12. |
| 212–233 | **Teste de permissões** | Comandos com `WHERE 1 = 0` (não gravam nada) que provam `INSERT`, `UPDATE`, `DELETE`… | Se faltar permissão, o script para com `command denied` **antes** de gravar. ✔ `U3`. |
| 235 | `START TRANSACTION` | Tudo o que segue é uma transação | Ou grava tudo ou nada. |
| 239–436 | **A0: base do Diogo** | Cria **só o que faltar**: 4 áreas, 5 talhões da Sede, 2 operações, 11 aplicadores, 43 insumos, 18 compras e 43 itens | O RDS da equipe tinha as tabelas e os triggers, mas **nenhuma linha-base**. Os ids ficam iguais aos do banco do Diogo quando a tabela está vazia. Ver "regras de criação" abaixo. |
| 438–469 | **A1** | 24 talhões dos mapas impressos: Bela Vista 10, Corujas 9, Serra II 5 (apêndice D) | Dados **reais**: nome e hectares "como no papel". |
| 471–474 | **A2** | Troca a descrição das 3 áreas (dizia "talhões ainda não cadastrados") e registra a soma dos mapas | Os hectares da estimativa 2026 ficam; a diferença fica escrita. |
| 476–480 | **A3** | Corrige o `tipo` de **12 produtos** conforme a planilha de defensivos autorizados (Spirit → Inseticida/Fungicida; Pledge, Poquer, Roundup Original, Alion SC500, Crop Best e Crop Exit S → Herbicida; Melyra, Valpura EC e Orkestra SC → Fungicida; Supreme Mineral N1 → Adjuvante; BioKiller → Inseticida microbiológico) | Troca o `'Insumo'` provisório do seed 01 por dado real. Só mexe em quem ainda está com `'Insumo'`. |
| 482–578 | **B0** | Converte um banco carregado pela **versão anterior** (que gravava `[SIMULADO #nnn]`, `SIM-0xx` e `marca = 'SIMULADO'` no texto) para o modelo novo: mesmos ids, preenche a tabela de controle, nada duplica | Quem já tinha rodado a versão antiga não precisa desfazer. |
| 582–598 | **B1** | 2 insumos fictícios (NPK 20-05-20, Calcário dolomítico) e **tipo deduzido pelo nome** para 7 produtos que não estão na auditoria (Curbix SC200 → Inseticida; Glufosinate Ammonium 200 G/L SL → Herbicida; YaraLiva Nitrabo, Boro Super, Maxi Zinc, Ferriflo NG e Blend Mg-Zn-B → Fertilizante) | Completar o cadastro para os exemplos. |
| 600–616 | **B2** | 5 aplicadores fictícios: 4 tratores (placas inventadas) e 1 drone DJI Agras T40 (série inventada), com capacidades inventadas | O banco real não tem tratores. |
| 618–684 | **B3** | 10 compras fictícias (notas de 5 algarismos) com 26 itens e **preço unitário inventado** (R$ por litro ou kg) | Permite o BI calcular custo do desperdício. |
| 686–1092 | **B4** | **70 aplicações** (14/10/2025 a 30/10/2026, mais 3 programadas), 329 linhas de talhão e 111 de insumo, com doses previstas e realizadas e reaplicações por chuva | O coração da demonstração. Ordem: aplicação → controle → talhões → insumos. |
| 1093–1195 | **PARTE C: conferência** | Confere o resultado ainda **dentro da transação** (15 verificações) | Se algo estiver errado, desfaz. |
| 1196–1203 | **Decisão** | `COMMIT` ("CARGA COMPLETA: tudo foi gravado.") ou `ROLLBACK` ("CARGA INCOMPLETA: NADA foi gravado.") | Nunca fica pela metade. |
| 1204–1229 | Fim | Hectares por área e "NÚMEROS PARA DIGITAR NO TERMINAL" (10 linhas `OK`) | Os ids reais dos 10 exemplos de apresentação, calculados no banco de quem rodou. |

**Regras de criação da base (A0).** Nunca apaga nem duplica o que existe.
- Áreas e operações que faltarem são criadas.
- O povoamento só **usa** um subconjunto da base: os **5 talhões da Sede, 8 aplicadores e 15 insumos**. É esse subconjunto que a
  verificação confere. Talhões da Sede, aplicadores e insumos só são criados **quando o subconjunto inteiro falta** (e, na
  Sede, quando ela não tem talhão nenhum). Quando falta só **parte** dele (por exemplo 14 dos 15 insumos usados), o script
  **para**: alguém renomeou ou apagou algo e ele não adivinha. ✔ `V4`, `V5`.
- Itens da base que o povoamento **não usa** podem faltar ou ser renomeados sem travar: o script os recria pelo nome. ✔ `U4`, `V2`.
- Compras reais: só entram se **nenhuma** das 18 notas existir no banco.
- Os ids da base saem **iguais** aos do banco do Diogo quando a tabela está vazia (variável `@vz`).

**A trava `PARE`** (como e por que o script se protege, veja a seção 6.3): se a verificação achar algo fora do esperado
(coluna faltando, nome repetido, grupo parcial), o script termina com o erro **1064** e a mensagem `PARE: faltam …`, **antes de
gravar qualquer coisa**. Não é bug: é o aviso. Clientes que **continuam depois de um erro** (a extensão MySQL Shell do VS
Code, `mysql --force`) também não gravam: a sessão fica em modo somente-leitura.

**Regras dos dados fictícios** (decisão D4, "dado sintético declarado"): semente fixa; datas de 14/10/2025 a 30/10/2026 (+3
programadas, as de 09, 10 e 12/11/2026, sem dose realizada); trator e drone erram menos que bomba costal; mais chuva de
dezembro a março; doses e preços plausíveis, **não** são recomendação agronômica.

**O que NÃO foi carregado da auditoria, de propósito:** voos de drone (viram linhas sem talhão e insumo, que o programa não
abre), notas fiscais com CNPJ e valores, geolocalização e dados de pessoas.

**Números esperados** (num banco que só tinha as tabelas): área +4, talhão +29 (5 da Sede + 24 dos mapas), operação +2,
aplicador +16 (11 da base + 5 fictícios), insumo +45 (43 + 2), compra +28 (18 + 10), item_compra +69 (43 + 26),
aplicação +70, aplicação_talhão +329, aplicação_insumo +111, tabela de controle +87.

**Efeito na auditoria.** Os triggers gravam cada inserção: o povoamento acrescenta **cerca de 531 linhas** ao
`historico_alteracoes` (574 se o banco estava sem a base do Diogo, porque os 43 insumos dela também passam pelos triggers;
cerca de 72 na conversão de um banco da versão anterior). Quem conferir o histórico por contagem vai ver essa diferença.

**Verificado.** ✔ `T5`, `T7`, `U3`, `U4`, `U5` e `V1` a `V5` (ver seção 7). Em resumo: num banco novo, `CARGA COMPLETA`, 70
aplicações com ids 1 a 70 e próximo id 71; rodar de novo não duplica nada; num banco sem a base, cria tudo
(574 linhas de histórico, 87 linhas de controle); sem `ALTER`/`CREATE` para antes de gravar; as travas funcionam.

---

### 4.12 A tabela `registro_dados_ficticios` (tabela de controle)

**O que é.** Uma tabela que o povoamento cria (e o programa **não usa**): `id`, `tabela` (`insumo`, `aplicador`, `compra` ou
`aplicacao`), `id_registro` e `ref` (para aplicação, o número de ordem 1 a 70 da carga), `UNIQUE (tabela, id_registro)`,
`KEY (tabela, ref)`. **Sem trigger.**

**Por que existe (em vez de etiqueta no texto).** A versão antiga gravava `[SIMULADO #nnn]` nos textos. Isso aparecia no
programa e no BI. Agora os registros fictícios **parecem** de um cadastro normal (nome, marca, observação e número da nota) e os
**ids** ficam nessa tabela. É ela que o `desfazer_dados_ficticios.sql` e as consultas do BI usam (coluna `origem_dado`).
A decisão D4 continua valendo: **declare na apresentação** que os dados são sintéticos.

**Conteúdo depois da carga (87 linhas):** `aplicacao` 70, `aplicador` 5, `compra` 10, `insumo` 2. ✔ `U5`.
A única etiqueta visível que sobra é `[DEMO #nn]` no começo da observação dos 10 exemplos que **a pessoa digita** na
apresentação.

**Cuidado.** Não faz parte do `schema.sql`: depois do povoamento o banco tem **12 tabelas**. O `desfazer` esvazia a tabela, mas
não a apaga.

---

### 4.13 `banco/povoamento/corrigir_ids.sql`

**O que é.** Renumera as aplicações para **1, 2, 3…** sem buracos e acerta o contador `AUTO_INCREMENT` de cada tabela.

**O sintoma.** As aplicações começavam no id 3 (e não no 1) e a cadastrada pelo terminal recebia um número muito maior (136,
por exemplo), pulando dezenas.

**A causa** (o programa não inventa o número: mostra o que o MySQL devolve, `inserirLinha`/`lastInsertID` em
`lib/repositories/mysql/ajuda_mysql.dart`): o contador `AUTO_INCREMENT` **só anda para a frente**. (1) Id de linha apagada ou de
`INSERT` desfeito **não volta** (foi isso que fez começar no 3). (2) Num `INSERT ... SELECT` com várias linhas, o MySQL reserva
ids **em blocos** (1, 2, 4, 8…) e perde o que sobra do último: 70 linhas gastaram 127 ids, e o contador foi de 3 para 130.

**O que faz** (pode rodar de novo; se já estiver certo, não muda nada). Começa com `ROLLBACK`, `USE`, `SET NAMES` e
restaura `transaction_read_only = 0` e `foreign_key_checks = 1`, para desfazer o que uma execução anterior, parada no meio,
possa ter deixado aberto. Depois:
1. **ANTES** (só leitura): para cada tabela, menor id, maior id, linhas e o "próximo id".
2. **Verificação**: para (`PARE`, erro 1064) se houver **outra tabela ligada a `aplicacao`** ou **linha solta** de
   talhão/insumo (sem aplicação). **2b, teste de permissão:** roda `ALTER TABLE aplicacao AUTO_INCREMENT = 1`, um comando
   **inofensivo** (nunca baixa o contador abaixo de `MAX(id) + 1`, só tira o excesso). Se o usuário não tiver `ALTER`, o MySQL
   responde "ALTER command denied" **aqui**, sem ter mudado nada.
3. **Renumera**, numa transação só:
   - **3a** guarda uma "foto" do conteúdo: quantidades e uma **soma de controle `CRC32`** de cada aplicação, de cada linha de
     talhão e de cada linha de insumo/dose. A soma usa a **posição** da aplicação na fila (e não o id), por isso compara o
     **conteúdo** de antes e de depois;
   - **3b** remove da tabela de controle as linhas que apontam para registro que não existe mais (se ficassem, o id
     reaproveitado depois seria tratado como fictício);
   - **3c** acha o primeiro id fora do lugar;
   - **3d** troca os números com `UPDATE … ROW_NUMBER() … ORDER BY id_aplicacao` (filhas primeiro, mãe por último, com
     `FOREIGN_KEY_CHECKS = 0`, porque as chaves não têm `ON UPDATE CASCADE`). Cada `UPDATE` vai em **ordem crescente**: o
     número novo é sempre menor que o antigo e o lugar dele já foi liberado, então nada colide;
   - **3e conferência, ainda dentro da transação** (**9 verificações**): quantidade de aplicações, menor id (1), maior id (= a
     quantidade, sem buraco), quantidade de linhas de talhão e de insumo, nenhuma linha solta, e as 3 somas `CRC32` iguais às
     de antes. Tudo certo: `COMMIT` ("NUMERACAO CORRIGIDA"). Qualquer diferença: `ROLLBACK` automático ("NUMERACAO NAO
     CORRIGIDA… nada mudou"). Depois religa `FOREIGN_KEY_CHECKS`.
4. `ALTER TABLE … AUTO_INCREMENT = 1` nas **8 tabelas** com id automático, o que deixa o contador em `MAX(id) + 1`.
5. **DEPOIS** (só leitura): o próximo id de cada tabela tem de ser `MAX(id) + 1` e as aplicações vão de 1 até o total.

**Quem roda.** O usuário do DBA (precisa de `ALTER`, `UPDATE`, `DELETE`). O usuário comum para logo no teste de permissão
("ALTER command denied") **sem ter mudado nada**. De preferência **sem ninguém usando o programa**.

**O que muda e o que não muda.** Mudam **só os ids das aplicações**; data, operação, aplicador, talhões, insumos e doses ficam
iguais (a conferência prova). Os ids de insumo, aplicador, talhão e operação **não** mudam. O `historico_alteracoes` registra
**um `UPDATE` por id trocado** (a aplicação e cada talhão e insumo dela): **531 linhas para 77 aplicações**. É esperado: o
histórico não deixa apagar.

**Quando rodar.** Depois do povoamento, se o banco veio da versão antiga; depois de apagar os exemplos ou os fictícios; e
**antes de apresentar**. Número apagado nunca volta sozinho (é assim que o MySQL funciona): este script é o jeito de fechar o
buraco.

**Resultado no RDS real.** ◇ relatado (print do grupo): 71 aplicações, ids 7..135 → 1..71, próximo id 72.

**Verificado.** ✔ `T4` (cenário do RDS: ids 3..72 + 1 cadastro manual no 130 → 1..71, próximo 72; a 2ª execução não troca nada
e o histórico não cresce), `T5` (num banco já certo: nada a trocar), `W1` (linha de talhão sem aplicação → `PARE`), `W2`
(outra tabela ligada → `PARE`), `W3` (sem aplicações: "NUMERACAO JA ESTAVA CERTA"), `U2` (sem `ALTER`: para e nada muda).
Requer MySQL 8.0 ou mais novo (`ROW_NUMBER()`).

---

### 4.14 `banco/povoamento/desfazer_dados_ficticios.sql`

**O que é.** Apaga **só os dados fictícios** do povoamento.

**O que apaga:** as aplicações fictícias e os 10 exemplos `[DEMO #nn]` (com talhões e insumos), as compras fictícias (com
itens), os 5 aplicadores e os 2 insumos fictícios; **devolve** o tipo `'Insumo'` aos 7 produtos de tipo deduzido; esvazia a
tabela de controle.

**O que NÃO apaga:** os dados reais (os 24 talhões dos mapas, a descrição das áreas e o tipo dos 12 produtos da auditoria) e
**a base do Diogo** (áreas, talhões da Sede, operações, aplicadores, insumos e compras reais) mesmo que o povoamento a tenha
criado: é cadastro, não dado fictício.

**Como identifica o que é fictício.** Pela tabela de controle; também reconhece as etiquetas da versão antiga
(`[SIMULADO #%`, `SIM-%`, `marca = 'SIMULADO'`).

**Ordem dos `DELETE`:** filhas (`aplicacao_insumo`, `aplicacao_talhao`) → `aplicacao` → `item_compra` → `compra` →
`aplicador` e `insumo` fictícios. É a ordem exigida pelas chaves estrangeiras **e** a que mantém a auditoria completa (✔ `X2`).
Se uma aplicação **real** usar um aplicador ou insumo fictício, o MySQL recusa (chave estrangeira) e nada é apagado.

**Cuidados.** Os ids das linhas apagadas **não voltam** (rode o `corrigir_ids.sql` depois). As exclusões também ficam no
histórico: **a tabela cresce**, de propósito (nesse teste o histórico chegou a 1.051 linhas).

**Verificado.** ✔ `T6`: depois do desfazer, `4 · 29 · 2 · 11 · 43 · 18 · 43`, **1** aplicação (o cadastro manual do teste, que
fica) e a tabela de controle vazia.

---

### 4.15 `banco/povoamento/apagar_so_os_exemplos.sql`

**O que é.** Apaga **só** as aplicações cuja observação começa com `[DEMO #` (os 10 exemplos da apresentação), com seus talhões
e insumos, e deixa o resto como está.

**Por que existe.** Para **ensaiar e repetir**: cadastra-se os 10 exemplos pelo terminal, apaga-se com este arquivo e
repete-se. **Não precisa da tabela de controle** (acha os exemplos pela etiqueta `[DEMO #nn]` que a pessoa digita).

**Cuidado.** O id apagado não volta: rode o `corrigir_ids.sql` **antes de apresentar**, senão a primeira aplicação cadastrada
ao vivo pula alguns números. A conferência final mostra `exemplos_que_sobraram` (tem de ser 0) e o total que continua.

**Verificado.** ✔ `T6`.

---

### 4.16 `banco/validacao/validar_cadeia.sh`

**O que é.** Um script de shell que **roda toda a cadeia de scripts num MySQL 8 local e descartável** e confere cada resultado
contra o valor esperado (`OK` ou `FALHA`). São **87 conferências**. Veja `banco/validacao/LEIAME_VALIDACAO.md` e o resultado
em `banco/validacao/resultado_2026-11-10.txt`.

**Por que existe.** Para a equipe **provar** (e não só dizer) que os scripts funcionam, e para repetir a prova quando algo
mudar. É a evidência de tudo o que está marcado com ✔ neste documento.

**Travas de segurança** (ele **apaga e recria** o banco `caderno_fazenda` várias vezes): só aceita servidor local (socket ou
127.0.0.1); recusa servidor com cara de RDS (`@@basedir` com `rdsdbbin` ou rotinas `mysql.rds_%`); exige a variável
`CONFIRMO_APAGAR_CADERNO_FAZENDA_LOCAL=sim`; exige MySQL ≥ 8.0.16 e recusa MariaDB; a senha do `agrogestor_app` de teste é
gerada ao acaso e nunca gravada.

---

### 4.17 `seed_auditoria.sql` (legado, PostgreSQL) — **fora do repositório**

**O que é.** O primeiro script de dados da equipe, escrito **para PostgreSQL** (o projeto começou no Supabase). Cria o schema de
*staging* `stg_auditoria`, **separado do schema do Diogo**, e carrega **11 tabelas** com dados **reais** da auditoria
Rainforest Alliance da Fazenda da Serra, consolidados em 07/09/2026 pelo Samuel (`origem = 'real_auditoria'`):
`lotes_premio` (34 linhas), `rastreabilidade_safra` (6), `produtividade_safra` (4), `geolocalizacao` (4), `defensivos_safra`
(12), `analise_solo` (7), `poda_ano` (4), `certificados` (3), `notas_fiscais` (4), `aplicacoes_drone` (7) e
`equipe_agregado` (2).

**Por que existe.** Foi a fonte de onde saíram os dados reais dos seeds 02 e 03 e do povoamento. Quando o banco virou MySQL
(`caderno_fazenda`), os dados foram **mapeados à mão** para as tabelas novas (o `README_dados.md` sugeria `INSERT ... SELECT`).

**Por que NÃO vai para o repositório.**
1. **Não roda no MySQL** (`GENERATED ALWAYS AS IDENTITY`, `CREATE SCHEMA`, `SET client_encoding`, `BEGIN` são de PostgreSQL).
2. Contém **dados que não devem ficar num repositório que parece público**: **coordenadas** das propriedades, valores
   comerciais (dólar, prêmio) e **nomes de pessoas físicas/MEIs e de um profissional** nas colunas `notas_fiscais.emitente`,
   `certificados.entidade` e `analise_solo.responsavel_tecnico` (os CNPJs foram removidos). O `README_dados.md` já pede que o
   grupo **decida** se essas colunas vão para o banco final e para o BI. O README do PI diz que só nome, função e matrícula de
   funcionários são armazenados.
3. Não é usado por nenhum outro script do banco.

**Onde fica.** No pacote entregue ao grupo (`scripts/08_legado_postgres_auditoria/`), com o `README_dados.md` (que traz o
dicionário de dados e os pontos de atenção).

---

### 4.18 `renomear-arquivos.py` (não é do banco)

**O que é.** Um script Python que **renomeia os arquivos da pasta `Auditoria`** conforme `dados-csv/mapa-renomeacao.csv`
(colunas `de` e `para`, separador `;`). **Roda em modo simulação** por padrão e só renomeia com `--aplicar`.
Uso: `python renomear-arquivos.py /caminho/para/Auditoria [--aplicar]`.

**Por que está aqui.** É o único script que veio dentro do zip `Auditoria-Processada`. **Não toca em banco nenhum**: organiza
os arquivos de origem dos dados. Fica no pacote por completude, fora do repositório.

---

### 4.19 O que os documentos citam e **não está** neste pacote

O `LEIA-ME.txt` do povoamento v7 cita 5 arquivos auxiliares. Eles fazem parte do pacote `povoamento_caderno_de_campo.zip`
(versão 7) que o grupo já recebeu e **não foram recuperados em texto** para este pacote:

| Arquivo | Tamanho | Para que serve |
|---|---:|---|
| `exemplos_apresentacao.sql` | 24.753 B | Plano B: os 10 exemplos em SQL, um bloco por vez, com verificação no topo |
| `diagnostico_banco.sql` | 6.147 B | Só leitura: mostra nomes, colunas e permissões do banco |
| `auditoria_dados_reais.sql` | 10.959 B | Opcional: cria 7 tabelas `aud_*` (inclui `aud_voo_drone`) |
| `criar_tabela_controle.sql` | 848 B | Para quando o usuário não tem `CREATE` e o DBA precisa criar a tabela de controle |
| `exemplos_para_o_terminal.txt` | 14.755 B | As respostas dos 10 exemplos, uma pergunta por linha, para digitar no programa |

Os tamanhos e a descrição vêm do `LEIA-ME` e da conversa. Se for preciso levá-los ao repositório, copie-os do zip original.
Os **dois** únicos que o resto do pacote **assume** existirem são o `criar_tabela_controle.sql` (só no caso de falta de
`CREATE`) e o `exemplos_para_o_terminal.txt` (a apresentação).

Também **não existe no repositório** o `roles.sql` do Bruno (PI-014), que cria o usuário `agrogestor_app` no RDS. O
`usuario_app_LOCAL.sql` é apenas um modelo local.

---

## 5. Como o programa (Dart) usa o banco

Esta seção descreve o código que fala com o banco: `lib/repositories/`, `bin/` e `tool/aplicar_sql.dart`. Serve para
explicar **o que o banco recebe do programa** (e por que algumas regras do schema existem).

> ✘ **Não verificado.** O código Dart **não foi compilado nem testado** na validação de 10/11/2026 (o ambiente de teste não
> tinha o SDK Dart). Tudo abaixo vem da **leitura** do código do repositório, conferida contra os scripts SQL. O que foi
> executado de verdade (✔) são os scripts SQL, com as mesmas instruções que o programa envia.

### 5.1 As camadas

```
 bin/caderno.dart            lib/cli/            lib/services/              lib/repositories/interfaces/
 (escolhe memória ou  ──►  (menus e telas) ──►  (regras: doses, calda,  ──►  (contratos: salvar, buscarPorId,
  MySQL, abre/fecha                              chuva, exclusões)            listarTodos, remover)
  a conexão)                                                                          │
                                                          ┌───────────────────────────┴───────────────┐
                                                 repositories/memoria/                       repositories/mysql/
                                                 (some ao fechar)                            (grava no MySQL da AWS)
```

Os serviços **só conhecem as interfaces** (`Repository<T>`). Quem decide de onde vêm os dados é a classe `Repositorios`:
`Repositorios.memoria()` (sem banco) ou `Repositorios.mysql(conexao)`. Por isso a versão em memória e a do MySQL
são intercambiáveis, e os testes do menu rodam sem banco.

| Comando | O que usa |
|---|---|
| `dart run bin/caderno.dart` | menu com dados **em memória** (tudo some ao sair) |
| `dart run bin/caderno.dart --mysql` | o mesmo menu, lendo e gravando no **MySQL** (`--sem-pausa` tira a pausa "Aperte Enter") |
| `dart run bin/main.dart [--mysql]` | demonstração roteirizada (cadastra, calcula e provoca erros de propósito) |
| `dart run bin/testar_conexao.dart` | só testa a conexão: mostra `VERSION()`, `CURRENT_USER()`, o banco e conta as tabelas |
| `dart run tool/aplicar_sql.dart arquivo.sql` | aplica um `.sql` no RDS como administrador (seção 4.8) |

Para qualquer comando com `--mysql`: exportar as variáveis do `.env` (`set -a; source .env; set +a`) e deixar o
`global-bundle.pem` na raiz do projeto. **O programa não lê o arquivo `.env` sozinho**: ele lê o ambiente do sistema.

### 5.2 A conexão (`ConfiguracaoBanco` e `ConexaoMysql`)

| Peça | O que faz | Por quê |
|---|---|---|
| `ConfiguracaoBanco.doAmbiente()` | Lê `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER` e `DB_PASSWORD`. Variável ausente ou vazia, ou porta fora de 1–65535, vira `DadoInvalidoException`. | **Nenhum valor fica escrito no código**, e a senha não aparece em mensagem de erro: o `toString()` imprime `senha: ***`. |
| `ConexaoMysql.abrir()` | Abre a conexão com **TLS**, confiando só nos certificados do arquivo `global-bundle.pem` (a lista pública de autoridades certificadoras da AWS). | A conexão é criptografada e o programa confere que está falando com o servidor da AWS, e não com um impostor. |
| `ConexaoMysql.usar(operação, ação)` | Roda a ação e converte **qualquer** erro do driver em `PersistenciaException("Erro de persistência: <operação>")`. O erro técnico fica em `causa`. As exceções do próprio projeto passam sem alteração. | O usuário do menu vê "Erro de persistência: salvar talhão", e **não** um texto do MySQL com nome de tabela, de coluna ou de servidor. |
| `.env.example` | Lista os nomes das variáveis (e `APP_ENV`), **sem valores**. O `.env` verdadeiro está no `.gitignore`. | Seção 10. |

O usuário configurado em `DB_USER` deve ser o `agrogestor_app` (nunca o `root` nem o administrador): ele só tem
`SELECT`, `INSERT`, `UPDATE` e `DELETE` (seção 4.7). O `tool/aplicar_sql.dart` é o único que usa administrador, e pede a senha
dele no terminal.

### 5.3 Tabela do banco × classe do programa

| Tabela | Classe e repositório | O que merece atenção |
|---|---|---|
| `area` | `Area` · `AreaRepositoryMysql` | Usa `id_area` e `nome`. A coluna `descricao` **não é usada** pelo programa. |
| `talhao` | `Talhao` · `TalhaoRepositoryMysql` | Cada talhão lido já vem com a sua `Area`, por um `JOIN`. `hectares` é arredondado para **2 casas** antes de gravar (a coluna é `DECIMAL(10,2)`). `localizacao` não é usada. |
| `operacao` | `Operacao` · `OperacaoRepositoryMysql` | **Pegadinha de nome:** na classe, o texto da operação é `descricao`; no banco, é a coluna **`nome`**. O repositório faz a ponte. A coluna `descricao` do banco não é usada. |
| `aplicador` | `Aplicador` (e subclasses trator, drone, bomba costal) · `AplicadorRepositoryMysql` | A coluna `tipo` decide qual subclasse criar na leitura (`criarAplicador`). `modelo` é `NOT NULL` no banco, mas opcional na classe: **sem modelo, grava texto vazio** (e lê vazio como nulo). Capacidades arredondadas a 2 casas. |
| `insumo` | `Insumo` · `InsumoRepositoryMysql` | `nome`, `marca`, `tipo`. Sem unidade (ela vem da dose). **Tabela auditada.** |
| `aplicacao`, `aplicacao_talhao`, `aplicacao_insumo` | `Aplicacao` · `AplicacaoRepositoryMysql` | **Uma** aplicação do programa ocupa **três** tabelas. Grava as 2 colunas de reaplicação (`horas_ate_chuva`, `motivo_reaplicacao`) em toda gravação. **Tabelas auditadas.** |
| `compra`, `item_compra` | *(nenhuma)* | **O programa não lê nem grava as compras** (nenhum arquivo de `lib/`, `bin/` ou `tool/` cita essas tabelas). Elas existem para o BI e para a carga inicial. |
| `historico_alteracoes` | *(nenhuma)* | Só os triggers escrevem. O programa não lê nem escreve. |
| `registro_dados_ficticios` | *(nenhuma)* | Só o povoamento, o `desfazer` e o BI usam. |

### 5.4 Como uma aplicação é gravada e apagada (e o que isso faz no banco)

`AplicacaoRepositoryMysql.salvar`:

1. **Antes de abrir a transação**, confere que operação, aplicador, talhões e insumos já têm id (já foram salvos). Se não,
   recusa com "salve antes de registrar a aplicação". Sem isso, o `INSERT` falharia no meio da gravação.
2. `START TRANSACTION`.
3. **Aplicação nova:** `INSERT INTO aplicacao (id_operacao, id_aplicador, data_aplicacao, observacao, horas_ate_chuva,
   motivo_reaplicacao)` e lê o id gerado (`lastInsertID`). **Aplicação existente:** `UPDATE aplicacao … WHERE id_aplicacao = :chave_id`
   e depois **apaga** as linhas filhas (`DELETE FROM aplicacao_insumo …` e `DELETE FROM aplicacao_talhao …`).
4. **Regrava as filhas:** um `INSERT` por talhão e um por insumo (doses arredondadas a **3 casas**, unidade `L/ha` ou `kg/ha`).
5. `COMMIT`. **Só depois** o objeto recebe o id. Se algo falhar, `ROLLBACK` (e, se até o `ROLLBACK` falhar porque a conexão
   caiu, esse erro é ignorado: o que importa é o erro original) e a aplicação continua "sem id", como se nunca tivesse sido salva.

`remover(id)`: `START TRANSACTION` → apaga as filhas → apaga a aplicação → `COMMIT` (ou `ROLLBACK` no erro).

**O que isso significa para o banco (pontos que a banca pode explorar):**

| Fato | Consequência | Marca |
|---|---|---|
| As filhas são apagadas **explicitamente**, e não pelo `ON DELETE CASCADE` | Os triggers das filhas disparam: a exclusão é **auditada por completo** (o cascata sozinho não faria isso). | ✔ `X1` (cascata não audita) e `X2` (explícito audita) |
| Toda **edição** de uma aplicação apaga e regrava **todas** as filhas, mesmo que só a observação tenha mudado | O histórico ganha um `DELETE` e um `INSERT` por talhão e por insumo a cada edição: **ruído** (a trilha fica correta, mas longa). | ✘ por leitura do código; o padrão `DELETE`+`INSERT` das filhas está em `X2` |
| `salvar` e `remover` rodam numa transação | Ou grava tudo ou nada: nunca fica uma aplicação sem talhões. | ✘ por leitura do código |
| O `UPDATE` que não muda nenhum valor devolve "0 linhas alteradas" no MySQL | `atualizarLinha` confere com um `SELECT 1` se a linha existe antes de acusar "registro não encontrado". | ✘ por leitura do código |
| O id vem do `AUTO_INCREMENT` (o programa **não inventa** número) | Se o contador pulou, a aplicação cadastrada recebe o número alto (como o 130 de `T4`). Por isso existe o `corrigir_ids.sql`. | ✔ `T4` |

### 5.5 Como o programa lê (e por que isso importa na AWS)

`_montar` transforma as linhas de `aplicacao` em objetos. Os talhões e os insumos de **todas** as aplicações vêm em **duas
consultas** (com `WHERE id_aplicacao IN (…)`), e cada operação, aplicador, talhão e insumo é buscado **uma vez**, mesmo que
várias aplicações o usem. O comentário do código explica: cada ida ao banco na AWS leva uma fração de segundo, e o menu
lista as aplicações com todos os detalhes.

A lista de ids colada no `IN (…)` é o **único** ponto onde o SQL é montado por concatenação, e só contém **números que
acabaram de sair do próprio banco** (o código documenta isso).

### 5.6 Segurança do lado do programa

- **Parâmetros nomeados** (`:nome`) em todo valor digitado. O driver escapa. Nomes de tabela e de coluna que entram em
  `inserirLinha`/`atualizarLinha` vêm de **constantes dentro dos repositórios**, nunca do usuário (está dito no cabeçalho de
  `ajuda_mysql.dart`). Isso é a defesa contra **injeção de SQL**.
- **Senha só no ambiente**, nunca no código, no log nem no `toString()`.
- **TLS** com conferência do certificado.
- **Privilégio mínimo:** o usuário do programa não altera estrutura nem remove triggers (✔ `U0`, `U2`, `U3`).
- **Erro técnico escondido** do usuário final (`PersistenciaException`), mas guardado em `causa` (e mostrado por
  `testar_conexao.dart` e pelos executáveis em `FALHOU: … Causa técnica: …`, para quem for depurar).

### 5.7 Duas camadas contra exclusão indevida

Quando o usuário tenta excluir um talhão, insumo, aplicador, operação ou área que está em uso, **o serviço
(`ManutencaoService`) confere primeiro** e recusa com `ExclusaoNegadaException`, por exemplo "Exclusão negada: talhão
Chico1 (usado na aplicação 3; exclua-a antes)". **Mesmo que o serviço falhasse**, o banco recusaria: as chaves estrangeiras
sem `ON DELETE` (o padrão `NO ACTION`, que no InnoDB **recusa** apagar um pai que ainda tem filho, como o `RESTRICT`; ✔
conferido em `information_schema.referential_constraints`) impedem a exclusão. É a razão de a maioria das FKs **não** ter
`CASCADE` (seção 3.2).

A exclusão de uma **aplicação** é diferente de propósito: o serviço apaga a aplicação **com** os talhões e os insumos dela
(`excluirAplicacao`), e nenhum cadastro é afetado.

### 5.8 Testes do programa que tocam o banco

O repositório tem testes de integração com a tag `mysql` (`dart test -t mysql`, com as variáveis `DB_*` exportadas); sem
`DB_HOST` no ambiente eles são pulados, e o `dart test` comum roda offline. **Hoje só a `AreaRepositoryMysql` tem teste de
integração** (`test/repositories/area_repository_mysql_test.dart`, que cria áreas com nome exclusivo e apaga no fim). Os
outros cinco repositórios MySQL, incluindo o de aplicação, **não têm teste de integração no repositório**; os
scripts SQL é que foram validados (seção 7). Isso está na lista de pontos em aberto (seção 9).

---

## 6. Técnicas que se repetem nos scripts, explicadas

Os scripts de povoamento, de correção de ids e de desfazer repetem os mesmos truques. Entendê-los uma vez vale para todos.

### 6.1 Idempotência: rodar de novo não duplica

**Ideia.** Um script é **idempotente** quando rodar duas vezes deixa o banco igual a rodar uma. O povoamento usa:

```sql
INSERT INTO insumo (nome, marca, tipo)
SELECT 'NPK 20-05-20', 'Marca', 'Fertilizante'
WHERE NOT EXISTS (SELECT 1 FROM insumo WHERE nome = 'NPK 20-05-20');
```

Na segunda vez, o `WHERE NOT EXISTS` não acha nada para inserir (0 linhas, sem erro). Os registros fictícios são conferidos
pela tabela de controle (seção 4.12). ✔ `T5`: rodar o v7 de novo não dá erro e **nada duplica** (só o histórico do
cadastro manual do teste). **Não confundir** com "reversível": idempotente quer dizer "repetível", e não "desfaz".
O `alter_aplicacao_reaplicacao.sql`, por exemplo, **não** é repetível (erro 3822, ✔ `T2`), e por isso o povoamento tem a sua
própria versão condicional dele (6.2).

### 6.2 DDL condicional com `PREPARE`

**Problema.** O MySQL não tem `ADD COLUMN IF NOT EXISTS`, e um script não pode ter `IF` solto (só dentro de programa
armazenado).

**Solução** (passos 0 e 0b do povoamento):

```sql
SET @sql := IF((SELECT COUNT(*) FROM information_schema.columns
                WHERE table_schema = DATABASE() AND table_name = 'aplicacao'
                  AND column_name = 'horas_ate_chuva') = 0,
  'ALTER TABLE aplicacao ADD COLUMN horas_ate_chuva DECIMAL(6,2) NULL, ADD CONSTRAINT ... CHECK (...)',
  'DO 0');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
```

A função `IF()` escolhe **o texto** do comando: o `ALTER` (se a coluna não existe) ou `DO 0` (um comando que não faz nada).
`PREPARE … EXECUTE` roda o texto escolhido. O mesmo vale para criar a tabela de controle.

### 6.3 A trava `PARE`: parar com mensagem, antes de gravar

**Problema.** Um script `.sql` comum não tem como "levantar um erro com mensagem" (isso é `SIGNAL`, que só vale dentro de
trigger ou procedure). E o povoamento liga dados novos a coisas que já existem **pelo nome**; quando o nome não existe, o
`INSERT … SELECT` não dá erro: **grava 0 linhas**. Foi assim que uma carga antiga mostrou "OK" e deixou 0 aplicações.

**Solução.** A verificação prévia (só leitura) conta os problemas em `@falta`. Se `@falta` não for zero:

1. liga `SET SESSION transaction_read_only = 1` (por `PREPARE`): a sessão passa a **só ler**;
2. executa um texto que começa com `PARE: faltam …`, que **não é SQL válido**: o MySQL responde com o erro **1064**
   ("You have an error in your SQL syntax … near 'PARE: faltam …'"), e o script termina ali. A mensagem do erro carrega o resumo
   do que falta; a tabela da verificação mostra os detalhes.

O passo 1 existe para os clientes que **continuam depois de um erro** (a extensão MySQL do VS Code, `mysql --force`): sem ele,
os comandos seguintes gravariam. Com ele, eles falham com o erro **1792** ("cannot execute statement in a READ ONLY
transaction"). ✔ `V1` a `V5` (cada trava para sem gravar), `V3` (cliente que continua: nada gravado, erros 1792),
`W1`, `W2` (travas do `corrigir_ids`: erro 1064 `PARE`). Por isso o início de cada script faz `SET SESSION transaction_read_only = 0`:
desfaz uma parada anterior.

> **Não é bug quando aparece "PARE".** É o script avisando que achou algo fora do esperado e que **nada foi gravado**.

### 6.4 Transação com conferência dentro, e `COMMIT` ou `ROLLBACK` decidido pelo script

O povoamento abre `START TRANSACTION`, grava tudo, **confere o resultado ainda dentro da transação** (15 verificações) e só
então decide. Como um script não tem `IF` para escolher entre `COMMIT` e `ROLLBACK`, usa o mesmo truque do 6.2:

```sql
SET @sql := IF(@ok = 1, 'COMMIT', 'ROLLBACK');
PREPARE stmt FROM @sql;  EXECUTE stmt;  DEALLOCATE PREPARE stmt;
```

O resultado é binário: "CARGA COMPLETA: tudo foi gravado." ou "CARGA INCOMPLETA: NADA foi gravado (ROLLBACK automático)".
**Nunca fica pela metade.** O `corrigir_ids.sql` faz o mesmo ("NUMERACAO CORRIGIDA" ou "NUMERACAO NAO CORRIGIDA… nada mudou").

**Limite importante:** `ROLLBACK` só desfaz **dados** (DML). `ALTER TABLE` e `CREATE TABLE` (DDL) **confirmam sozinhos** no
MySQL e não voltam atrás. Por isso o `ALTER` do passo 0 e a criação da tabela de controle ficam **antes** do `START TRANSACTION`, e
por isso o `tool/aplicar_sql.dart` "não desfaz o que já executou" (seção 4.8). E o `ROLLBACK` também **não devolve o
`AUTO_INCREMENT`** (6.7).

### 6.5 Teste de permissão que não grava nada

Antes de começar a gravar, o povoamento executa comandos como `INSERT INTO area (id_area) SELECT id_area FROM area WHERE 1 = 0;`.
O `WHERE 1 = 0` nunca é verdadeiro: o comando **não grava nada**, mas o MySQL confere a **permissão** antes de olhar as linhas. Se
o usuário não pode gravar naquela tabela, o script para com "command denied" **antes** de qualquer gravação. ✔ `U3` (usuário
da aplicação, sem `CREATE`: para na criação da tabela de controle, nada gravado) e `U2` (o `corrigir_ids` testa `ALTER` com um
comando inofensivo: para com "ALTER command denied", erro 1142, nada muda).

### 6.6 Tabela de controle em vez de etiqueta no texto

A versão antiga marcava o dado fictício **escrevendo no texto** (`[SIMULADO #nnn]`, `marca = 'SIMULADO'`), o que aparecia no
programa e no BI. A versão nova guarda **só os ids** numa tabela à parte (`registro_dados_ficticios`, seção 4.12): o dado
fictício **parece** um cadastro normal, e o `desfazer` e o BI (coluna `origem_dado`) sabem distinguir. A decisão D4 (dado
sintético **declarado**) continua valendo: a apresentação deve dizer que os dados são sintéticos.

### 6.7 `AUTO_INCREMENT`: por que o número pula e como acertar

1. **O contador só anda para a frente.** Linha apagada, `INSERT` desfeito por `ROLLBACK` ou erro: o número usado **não volta**.
   (✔ `T3`: depois de `auditoria.sql`, que termina em `ROLLBACK`, os contadores ficam em 9002.)
2. **`INSERT … SELECT` com várias linhas reserva ids em blocos que dobram** (1, 2, 4, 8, 16, 32, 64…) e **perde o que sobra do
   último bloco**. É o comportamento do `InnoDB` no modo de bloqueio `innodb_autoinc_lock_mode = 2` (o padrão do MySQL 8.0, ✔
   conferido no servidor de teste). Para 70 linhas, a soma 1+2+4+8+16+32+64 = **127** ids gastos: o contador foi de 3 para
   130, e a aplicação seguinte, cadastrada pelo menu, saiu com o **130** (✔ `T4`).
3. **O programa não escolhe o número:** mostra o que o MySQL devolve (`lastInsertID`).

**Como o v7 evita o pulo:** grava os ids **explicitamente**, `MAX(id_aplicacao) + ROW_NUMBER() OVER (ORDER BY t.n)`. Com ids
explícitos o contador acompanha o maior id (e não reserva blocos). ✔ `T5`: ids 1 a 70, próximo **71**, cadastro manual recebe o **71**.

**Como o `corrigir_ids.sql` acerta o que já pulou:**

- Troca os ids com `UPDATE … ROW_NUMBER() OVER (ORDER BY id_aplicacao)`. Cada `UPDATE` anda em **ordem crescente**, e o número novo é
  sempre **menor** que o antigo e o lugar dele já foi liberado, então nenhuma troca colide.
- As chaves estrangeiras **não têm `ON UPDATE CASCADE`**, então o script desliga `FOREIGN_KEY_CHECKS` **só durante** a troca
  (filhas primeiro, mãe por último) e religa depois.
- `ALTER TABLE … AUTO_INCREMENT = 1`: o InnoDB **nunca** põe o contador abaixo de `MAX(id) + 1`, então esse comando só tira o
  excesso e é inofensivo. ✔ `T4`: antes `próximo id` 131, depois **72** (= 71 aplicações + 1).

### 6.8 Soma de controle (`CRC32`): provar que a renumeração não mudou o conteúdo

Trocar ids é arriscado: se uma linha filha ficasse apontando para a aplicação errada, ninguém notaria. O `corrigir_ids.sql` tira uma
**"foto"** antes e depois: para cada aplicação, cada linha de talhão e cada linha de insumo/dose calcula
`CRC32(CONCAT_WS(…))` e soma. A soma usa a **posição** da aplicação na fila (`ROW_NUMBER`), e **não** o id, então compara o
**conteúdo** de antes com o de depois, e não os números. Se as três somas e as contagens baterem, `COMMIT`; se qualquer coisa
diferir, `ROLLBACK`. ✔ `T4`: somas `145026698188`, `708163051866` e `235204197890`, iguais antes e depois.

(Uma soma de `CRC32` **não é prova absoluta**: duas diferenças podem, em teoria, se anular. Por isso a conferência também
compara contagens, menor e maior id, e a ausência de linhas soltas.)

### 6.9 Convenções de escrita dos scripts (pequenos hábitos que evitam erro)

| Hábito | Por quê |
|---|---|
| `COUNT(1)` e não `COUNT(*)` | O asterisco some quando se copia texto de um chat e causa o erro 1064. |
| `SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci` no início | Acentos corretos e a mesma collation das tabelas (evita o erro 1267, mistura de collations, em comparações de texto). |
| `UPDATE`/`DELETE` pela chave primária (ou `SET SQL_SAFE_UPDATES = 0` no povoamento) | O *safe update mode* do Workbench recusa `UPDATE`/`DELETE` sem chave no `WHERE` (erro 1175). |
| `DELIMITER $$` só no arquivo de triggers | Um trigger tem `;` dentro do corpo; o delimitador temporário evita cortar o comando no primeiro `;`. O Workbench nem sempre dá conta, daí o `aplicar_sql.dart`. |
| `DROP TRIGGER IF EXISTS` / `CREATE USER IF NOT EXISTS` / `CREATE TABLE IF NOT EXISTS` | O arquivo pode rodar de novo. |
| Textos de resultado **sem acento** (`NUMERACAO CORRIGIDA`, `conferencia`…) | Observação: os textos que os scripts de povoamento e de correção mostram como resultado não têm acento (provavelmente para não depender da codificação do cliente; o motivo não está escrito nos arquivos). |
| **Nenhuma senha em arquivo** | Seção 10. |

---

## 7. O que foi testado e com que resultado

### 7.1 Como foi testado

Todos os resultados marcados com ✔ vêm do `banco/validacao/validar_cadeia.sh` (e dos testes manuais da seção 7.4),
executados em **10/11/2026** no mesmo servidor:

- **MySQL 8.0.46** (pacote do Ubuntu 24.04), uma instância **privada**, criada só para o teste: sem rede (`--skip-networking`), só
  por socket, dados em pasta descartável, fuso `+00:00`.
- Cliente `mysql` de **linha de comando** (não o Workbench).
- O script **apaga e recria** o banco `caderno_fazenda` várias vezes, por isso recusa servidor remoto e servidor com cara de RDS
  (seção 4.16).
- Rodou **duas vezes** com o mesmo resultado: a partir da pasta do pacote e a partir da pasta do repositório (o layout `banco/…` que
  vai para o GitHub): **87 de 87 conferências OK** nas duas. O resultado completo está em
  `banco/validacao/resultado_2026-11-10.txt`. As saídas brutas de cada etapa (como o MySQL devolveu) ficam na pasta
  `saidas_brutas/` do **pacote de entrega** e não vão para o repositório; o script as gera de novo a cada execução (variável `SAIDA`).

### 7.2 Resultado por cenário

Os códigos (`T1`, `U2`…) são os que aparecem nas marcas ✔ ao longo do documento.

| Código | Cenário | Conferências | O que ficou provado (valores observados) |
|---|---|---|---|
| `T1` | Banco do zero: `tudo_em_um.sql` + `conferencia.sql` | 7 | Sem erro. Contagens `4 · 5 · 2 · 11 · 43 · 18 · 43 · 0 · 0 · 0 · 0`; 19 linhas `OK` e 0 `DIFERENTE` na conferência; **14 triggers**; collation `utf8mb4_0900_ai_ci`; **11 tabelas**. |
| `T2` | `alter_aplicacao_reaplicacao.sql` | 4 | Colunas `horas_ate_chuva decimal(6,2) NULL` e `motivo_reaplicacao varchar(20) NULL`. **Segunda execução: erro 3822** (nome de `CHECK` repetido). O `CHECK` recusa `'granizo'` (erro 3819). |
| `T3` | `auditoria.sql` como administrador | 6 | 12 linhas de resumo (1 por tabela e ação), todas com o usuário conectado; **nada sobra no histórico depois do `ROLLBACK`**; contadores ficam em 9002 (talhão 9003); `UPDATE` e `DELETE` no histórico: **erro 1644**. |
| `T4` | **Cenário do RDS:** ids 1–2 "queimados" + povoamento v6 + 1 cadastro manual + `corrigir_ids` | 15 | v6 sem erro; contagens `4 · 29 · 2 · 16 · 45 · 28 · 69 · 70 · 329 · 111 · 535`; ids 3 a 72; **próximo id 130** (127 ids gastos); o cadastro manual recebe o **130**. `corrigir_ids`: 71 aplicações, ids **1 a 71**, próximo **72**; as 9 verificações dão `OK` (as 3 somas `CRC32` iguais); 2ª execução: sem erro, nada a trocar, histórico não cresce. |
| `T5` | Banco novo + **povoamento v7** | 9 | `CARGA COMPLETA`; **70 aplicações, ids 1 a 70, próximo 71**; o cadastro manual recebe o **71** (sem pulo); `corrigir_ids` num banco já certo: nada a trocar; v7 **de novo**: sem erro e **nada duplica**. |
| `T6` | `desfazer_dados_ficticios.sql` e `apagar_so_os_exemplos.sql` | 4 | Depois do `desfazer`: `4 · 29 · 2 · 11 · 43 · 18 · 43` (a base real fica), **1** aplicação (o cadastro manual do teste, que não é fictício), tabela de controle **vazia**. `apagar_so_os_exemplos`: `exemplos_que_sobraram = 0` e a aplicação restante continua. |
| `T7` | v7 **por cima** de um banco que já tem a carga v6 (sem corrigir antes) | 3 | Sem erro; **nada duplica**; o v7 **não renumera** (ids continuam 3 a 72). |
| `U0`/`U1` | Usuário da aplicação (`usuario_app_LOCAL.sql`, senha gerada na hora) e `auditoria.sql` como `agrogestor_app` | 4 | Privilégios só `SELECT, INSERT, UPDATE, DELETE` (sem `DROP`, sem `TRIGGER`); sem erro; a coluna `usuario` mostra `agrogestor_app@localhost`, **nunca** `root` (prova do `USER()`). |
| `U2`/`U3` | O que o usuário da aplicação (sem `ALTER`/`CREATE`) **não** consegue rodar | 6 | `corrigir_ids` para com **erro 1142** ("ALTER command denied") no teste de permissão e nada muda; o povoamento v7 para com "CREATE command denied" (tabela de controle) e nada é gravado. |
| `U4`/`U5` | Base incompleta: item **fora** do conjunto usado, e banco só com tabelas e triggers (sem seeds) | 10 | Um insumo que o povoamento não usa foi renomeado: o script **não para** e o recria (insumos 43+1+2 = 46). Num banco **sem seeds**, o v7 cria tudo: contagens da base + dados reais + fictícios, as 2 colunas de reaplicação, tabela de controle com **87 linhas**. |
| `V1`–`V5` | A trava `PARE` do povoamento | 11 | Área `Sede` duplicada: para com 1064 e **nada é gravado**; grupo parcial (7 de 8 aplicadores, 14 de 15 insumos): para; item fora do conjunto (Jacto 10 apagado): **não** para, e recria (16 aplicadores); cliente que continua após o erro (`mysql --force`): nada gravado, e os comandos seguintes falham com **1792**. |
| `W1`–`W3` | As travas do `corrigir_ids` | 5 | Linha de talhão sem aplicação: `PARE`, nada muda; outra tabela ligada a `aplicacao`: `PARE`, nada muda; banco sem aplicações: sem erro e nada a trocar. |
| `X1`–`X2` | `ON DELETE CASCADE` × `DELETE` explícito das filhas | 3 | `X1`: `DELETE` só na aplicação, as filhas somem por cascata, mas **só o `DELETE` da aplicação é auditado** (`aplicacao:DELETE:1` e os 3 `INSERT`s anteriores). `X2`: filhas apagadas antes: **tudo auditado** (6 pares tabela:ação). |
| | **Total** | **87** | **87 de 87 OK** |

### 7.3 Números de referência (para conferir na apresentação)

Ordem das colunas: área · talhão · operação · aplicador · insumo · compra · item_compra · aplicação · aplicação_talhão ·
aplicação_insumo · histórico.

| Momento | Contagens |
|---|---|
| Depois do `tudo_em_um.sql` (`T1`) | `4 · 5 · 2 · 11 · 43 · 18 · 43 · 0 · 0 · 0 · 0` |
| Depois do povoamento v7 num banco novo (`T5`) | `4 · 29 · 2 · 16 · 45 · 28 · 69 · 70 · 329 · 111 · 531` |
| Depois do `desfazer_dados_ficticios.sql` (`T6`, com 1 cadastro manual) | `4 · 29 · 2 · 11 · 43 · 18 · 43 · 1 · 0 · 0 · 1051` |

**De onde vêm as 531 linhas de histórico do povoamento** (os triggers registram cada gravação): 70 + 329 + 111 = **510**
inserções de aplicações, talhões e insumos de aplicação; **2** insumos fictícios; e **19** correções de `tipo` de insumo (12 da
planilha de defensivos e 7 deduzidos pelo nome). ✔ manual: o mesmo banco, depois do `desfazer`, ficou com 1.050 linhas
(531 + 510 exclusões + 2 exclusões de insumo + 7 devoluções de tipo; no `T6` há +1, a linha do cadastro manual, dando 1.051).

**Distribuição dos dados do povoamento** (✔ manual, banco novo + `ALTER` + v7): 70 aplicações de 14/10/2025 a 12/11/2026 (3
programadas, **sem dose realizada**); motivo de reaplicação `NULL` em 58, `chuva` em 8, `vento` em 2, `sol` em 1 e `outro` em 1;
hectares por área: Sede 19,95 · Bela Vista 60,15 · Corujas 35,88 · Serra II 30,70.

### 7.4 Provas manuais (✔ manual)

Feitas à mão no mesmo servidor, dentro de transação com `ROLLBACK`, para sustentar as respostas da seção 8.

**Recusas de integridade** (banco depois do povoamento):

| Tentativa | O que o MySQL respondeu |
|---|---|
| Apagar um aplicador que está em uso | **1451** (`fk_aplicacao_aplicador`) |
| Apagar um talhão que está em uso | **1451** (`fk_aptalhao_talhao`) |
| Ligar uma aplicação a um talhão que não existe | **1452** (`fk_aptalhao_talhao`) |
| Talhão repetido na mesma área | **1062** (`uk_talhao_area_nome`, "Duplicate entry '1-Chico1'") |
| Talhão com `hectares = 0` | **3819** (`ck_talhao_hectares`) |
| Aplicador com `tipo = 'helicoptero'` | **1265** ("Data truncated for column 'tipo'", porque o servidor está em modo estrito) |
| Dose realizada negativa | **3819** (`ck_apinsumo_realizada`) |
| Repetir o par (aplicação, talhão) | **1062** (chave primária composta) |

**Limites da imutabilidade do histórico** (com os dois triggers `BEFORE` ativos):

| Quem | Comando | Resultado |
|---|---|---|
| Usuário da aplicação | `UPDATE` / `DELETE` em `historico_alteracoes` | **1644** ("é imutável: não é permitido alterar/apagar linhas") |
| Usuário da aplicação | `TRUNCATE`, `DROP TABLE`, `ALTER TABLE`, `DROP TRIGGER` | **1142** ("command denied") |
| Administrador | `DELETE` em `historico_alteracoes` | **1644** (o bloqueio vale até para ele) |
| Administrador | `DROP TRIGGER` e depois `DELETE` | **funciona** (o administrador pode remover a proteção) |
| Administrador | `TRUNCATE TABLE historico_alteracoes` (trigger ativo) | **funciona**: o `TRUNCATE` não dispara trigger |

**Achado dos triggers de `aplicacao`** (✔ manual): com o `ALTER` de reaplicação aplicado, `UPDATE aplicacao SET motivo_reaplicacao =
'chuva', horas_ate_chuva = 2.50 …` gera uma linha de histórico em que `dados_anteriores` e `dados_novos` são **idênticos** (os
triggers não listam as duas colunas). Veja a seção 9 (item 2) para a correção sugerida, que também foi testada.

### 7.5 O que **não** foi verificado (limites honestos)

| Não verificado | Por quê e o que existe no lugar |
|---|---|
| **A execução no RDS real** | Sem acesso ao RDS. O que se sabe vem de prints do grupo (◇ relatado): o v6 rodou, as aplicações ficaram com ids 7 a 135 e o `corrigir_ids` as levou para 1 a 71. O teste `T4` **reproduz** esse cenário localmente. |
| **MySQL 8.4** (versão do RDS da equipe) | Os testes rodaram no **8.0.46**. Nada nos scripts depende de recurso removido no 8.4, mas **não foi executado lá**. |
| **O código Dart** | Não foi compilado, formatado nem testado (sem SDK Dart). Seção 5. |
| **O arquivo do povoamento v7** | É uma **reconstrução** (seção 4.11): confere pelo tamanho (101.104 bytes), pelo `diff` mínimo contra o v6 (13 linhas) e pelos testes acima. O v6 é o original. |
| **Concorrência** (duas pessoas gravando ao mesmo tempo) | Nenhum teste. Cada gravação de aplicação é uma transação (seção 5.4), mas isso não foi exercitado em paralelo. |
| **Desempenho e volume** | O banco tem dezenas de linhas (70 aplicações). Nada foi medido com milhares. |
| **Workbench** | Os testes usaram o `mysql` de linha de comando. Comportamentos do Workbench (*safe update mode*, `DELIMITER`, Execute All) estão tratados nos scripts por relato do grupo, mas não foram reproduzidos. |
| **Backup e recuperação** | Não fazem parte dos scripts (é configuração do RDS) e não foram verificados. |
| **`seeds/opcionais/04_aplicacoes_drone_CONFERIR.sql`** | Não deve ser rodado (cria aplicações sem talhão e sem insumo) e **não** foi executado. |

---

## 8. Perguntas que a banca pode fazer

Respostas curtas, com o apontamento de onde está a prova. Onde a resposta honesta é "não sabemos" ou "ficou em aberto", está
dito assim.

### 8.1 Modelagem

**P1. Explique o modelo em uma frase.**
O banco registra **onde** (área, talhão), **com quê** (aplicador, insumo), **o que** (operação e aplicação) e **quanto**
(dose prevista × realizada) se aplicou numa fazenda de café, mais as **compras** de insumo e um **histórico de alterações**
que ninguém apaga. São 11 tabelas (12 depois do povoamento). Seção 3.1.

**P2. O modelo está normalizado? Em que forma normal?**
O desenho segue a **3ª forma normal**: cada tabela descreve uma coisa, os atributos dependem da chave inteira (nas tabelas de
ligação, da chave **composta**) e de nada além dela, e não há grupo repetido. Duas ressalvas honestas: (1) `historico_alteracoes`
guarda JSON, porque é um **log técnico** e não parte do modelo de negócio; (2) `aplicacao_insumo.unidade_dose` poderia ser
deduzida do insumo (líquido → `L/ha`, sólido → `kg/ha`); se todo insumo sempre usar a mesma unidade, isso seria uma
dependência parcial da chave composta. Foi guardada na dose porque o `insumo` **não tem unidade** (decisão do schema) e porque a
lista de unidades da compra (litro, galão, kg…) é outra. *Não foi feita uma verificação formal de dependências funcionais; é o
argumento do desenho.*

**P3. Por que tabelas de ligação com chave primária composta, e não um `id` próprio?**
A própria chave impede repetir o par (a mesma aplicação com o mesmo talhão duas vezes), o que um `id` próprio não faria sem
um `UNIQUE` a mais. ✔ manual: repetir o par dá erro 1062. O custo é não haver `id` na linha: o histórico usa o `id_aplicacao`
como `chave_registro`.

**P4. Por que `DECIMAL` e não `FLOAT`?**
Precisão exata para hectares, doses, quantidades e preços: `0.1 + 0.2` é `0.3` em `DECIMAL` e `0.30000000000000004` em ponto
flutuante. O programa arredonda para as casas da coluna antes de gravar (hectares 2, doses 3, horas até a chuva 2). Seções 3.2 e 5.4.

**P5. Por que `ENUM` em alguns campos e texto livre no `tipo` do insumo?**
`ENUM` onde a lista é **fechada**: `aplicador.tipo` (3 valores), `unidade_dose` (2), `unidade_medida` (6); o banco recusa o resto
(✔ manual: 1265). O `tipo` do insumo é uma lista **aberta** (Herbicida, Fungicida, Adjuvante, "Inseticida microbiologico",
"Inseticida/Fungicida"…), então é texto. Consequência: grafias diferentes viram categorias diferentes no BI. E o motivo da
reaplicação usa `VARCHAR(20)` com `CHECK`, e não `ENUM`: o script registra a escolha, mas **o motivo não está escrito**; uma
hipótese plausível é poder mudar a lista com um `ALTER` da restrição. *Convém perguntar ao Diogo.* Seção 4.9.

**P6. Por que o volume de calda não é uma coluna?**
Decisão **D1** (o README a lista como **em aberto**): hoje é um valor **calculado** (hectares × taxa em L/ha, função `volumeCalda`). Guardar duplicaria a
informação e poderia ficar inconsistente com os hectares do talhão. O cálculo está em `lib/logica/`. Seção 3.2.

**P7. Por que o nome da área e o do insumo não são `UNIQUE`?**
No schema só `operacao.nome` e `(talhao.id_area, talhao.nome)` são únicos. **Área e insumo aceitam nomes repetidos**: é uma
lacuna possível, e não uma decisão documentada. O povoamento **detecta** nomes repetidos que o confundiriam e para (✔ `V1`). Fechar
a lacuna seria um `ALTER TABLE … ADD CONSTRAINT … UNIQUE (nome)` depois de limpar duplicatas; para o insumo, talvez `(nome,
marca)`.

**P8. Cada aplicação tem um único aplicador. É uma limitação?**
Sim, e está **registrada no próprio schema** como pendência ("um aplicador por aplicação; pendência dos dois equipamentos em
aberto"). Uma aplicação com trator **e** drone pediria uma tabela de ligação `aplicacao_aplicador`. Seção 9.

**P9. Onde fica o desperdício?**
Em `aplicacao_insumo`: `dose_prevista` × `dose_realizada` (esta fica vazia até a aplicação acontecer). A diferença, multiplicada
pelos hectares e pelo preço, é o desperdício. Quem calcula é o programa (`lib/logica/calculo_desperdicio.dart`,
`totais_desperdicio.dart`) e o BI.

**P10. Por que chaves artificiais (`id_…`) e não o nome como chave?**
Nomes mudam e se repetem: o talhão "Chico1" só é único **dentro da área**, e uma nota fiscal pode trazer o mesmo produto em duas
linhas (por isso `item_compra` não tem `UNIQUE (compra, insumo)`). Com `id` automático, trocar um nome não mexe nas chaves
estrangeiras.

### 8.2 Integridade e segurança

**P11. Como o banco impede dado inválido?**
Com restrições nomeadas: `PRIMARY KEY`, `UNIQUE`, `FOREIGN KEY`, `CHECK`, `NOT NULL` e `ENUM`. ✔ manual (seção 7.4): apagar
pai em uso (1451), filho sem pai (1452), nome repetido (1062), `hectares = 0` (3819), tipo fora da lista (1265), dose negativa
(3819). Os `CHECK` **só valem a partir do MySQL 8.0.16** (por isso a conferência começa pela versão).

**P12. O que acontece se alguém tentar apagar um talhão que está em uso?**
Duas camadas: o **serviço** confere e recusa com "Exclusão negada: talhão X (usado na aplicação N; exclua-a antes)"; e, se o
serviço falhasse, o **banco** recusa com o erro 1451, porque a chave estrangeira é `NO ACTION`. Seção 5.7.

**P13. Quais permissões tem o usuário da aplicação, e por quê?**
Só `SELECT`, `INSERT`, `UPDATE` e `DELETE` em `caderno_fazenda.*` (menor privilégio): o programa só lê e grava dados.
Sem `ALTER`/`CREATE` ele não muda a estrutura, e sem `DROP`/`TRIGGER` não remove a proteção do histórico. ✔ `U0`, `U2`, `U3` e ✔ manual (1142 em
`TRUNCATE`, `DROP TABLE`, `ALTER TABLE` e `DROP TRIGGER`). Quem muda estrutura é o administrador (o DBA). Seção 4.7.

**P14. Como as senhas são protegidas?**
Nenhuma senha está em arquivo do repositório. O programa lê `DB_*` do **ambiente**; o `.env` e os `*.local.sql` estão no
`.gitignore`; o `toString()` da configuração imprime `senha: ***`; o `aplicar_sql.dart` **pede a senha do administrador no
terminal, sem eco**; os scripts de teste geram a senha do usuário de teste **ao acaso** e não a gravam. Seções 5.2 e 10.

**P15. Como o programa evita injeção de SQL?**
Todo valor digitado entra por **parâmetro nomeado** (`:nome`), que o driver escapa. Nomes de tabela e de coluna vêm de constantes
dos repositórios, nunca do usuário; o único `IN (…)` montado por concatenação só recebe números que acabaram de sair do banco.
Seção 5.6. *✘ Verificado por leitura do código; o Dart não foi executado.*

**P16. A conexão é criptografada?**
Sim: TLS, confiando só nos certificados do `global-bundle.pem` (as autoridades da AWS), o que também confere a identidade do
servidor. Seção 5.2. *✘ Não testado aqui (sem SDK Dart e sem acesso ao RDS).*

**P17. Quem consegue acessar o RDS?**
O acesso é limitado pelo *security group* da AWS (lista de IPs liberados); quando o IP não está liberado, a conexão simplesmente
não abre. Isso é configuração da AWS, **fora destes scripts** (◇ relatado pelo grupo).

### 8.3 Triggers e auditoria

**P18. Por que auditar com trigger e não no programa?**
Porque o trigger vale **para qualquer caminho de escrita**: o menu, o Workbench, um script ou alguém com SQL direto. Uma
auditoria só no programa seria contornada por quem não passa por ele.

**P19. Como se garante que o histórico não é alterado?**
Dois triggers `BEFORE UPDATE` e `BEFORE DELETE` em `historico_alteracoes` lançam `SIGNAL SQLSTATE '45000'` (erro **1644**), e o
usuário da aplicação não tem `DROP`, `TRUNCATE`, `TRIGGER` nem `ALTER`. ✔ `T3`, `U0`, ✔ manual. **Limite:** o **administrador**
pode `DROP TRIGGER` e pode `TRUNCATE` (que não dispara trigger). A proteção vale para o usuário comum, e não contra o DBA.
Mitigações **fora** dos scripts (log de auditoria do RDS, backups) não foram verificadas. Seção 7.4.

**P20. Por que `USER()` e não `CURRENT_USER()`?**
Dentro de um trigger, `CURRENT_USER()` devolve quem **criou** o trigger (o administrador): toda linha diria "root". `USER()`
devolve quem **realmente se conectou**. ✔ `U1`: a coluna mostra `agrogestor_app@localhost`, nunca `root`.

**P21. O histórico diz quem foi a *pessoa*?**
Não. Mostra o **usuário do banco e o computador de origem** (`agrogestor_app@IP`). Como todos usam o mesmo usuário da aplicação,
não distingue João de Cristiano. Decisão **D5**, em aberto. Seção 3.3.

**P22. Por que só 4 tabelas têm trigger?**
`aplicacao`, `aplicacao_insumo`, `aplicacao_talhao` e `insumo` são o que muda no dia a dia e produz o desperdício. `area`,
`talhao`, `operacao` e `aplicador` são cadastros estáveis. É uma escolha de escopo, e não uma limitação técnica.

**P23. O `ON DELETE CASCADE` é auditado?**
**Não.** O cascata não dispara os triggers das tabelas filhas: se alguém apagar só a aplicação, o histórico registra a exclusão da
aplicação, mas **não** a das filhas (✔ `X1`). O programa e os scripts de desfazer apagam as filhas **antes**, e aí tudo é
auditado (✔ `X2`). A PI-012 e a PI-018 pedem `RESTRICT`; a decisão está em aberto. Seção 9.

**P24. O histórico não vai crescer sem parar?**
Vai, **de propósito** (o histórico não deixa apagar). Além disso, cada edição de uma aplicação apaga e regrava todas as filhas
(seção 5.4), então gera um `DELETE` e um `INSERT` por filha mesmo que só a observação tenha mudado. Não há rotina de arquivamento.
No povoamento, 531 linhas; no `desfazer`, mais 519.

### 8.4 Povoamento e números (ids)

**P25. Por que os números das aplicações pularam?**
O contador `AUTO_INCREMENT` **só anda para a frente**. (1) Id de linha apagada ou de `INSERT` desfeito não volta (por isso a
carga começou no 3). (2) O `INSERT … SELECT` de 70 linhas reservou ids **em blocos que dobram** (1+2+4+…+64 = 127) e perdeu o
que sobrou: o contador foi de 3 para 130, e a aplicação cadastrada pelo menu saiu com o **130** (✔ `T4`). O programa não escolhe
o número: mostra o que o MySQL devolve. Seção 6.7.

**P26. Por que não zerar o contador com `TRUNCATE` ou `ALTER TABLE … AUTO_INCREMENT = 1`?**
`TRUNCATE` apagaria os dados. E o `ALTER … AUTO_INCREMENT` **nunca** baixa o contador abaixo de `MAX(id) + 1`: não fecha buracos
que já existem **no meio** dos ids. Era preciso **renumerar** as linhas (`corrigir_ids.sql`) e só então acertar o contador.

**P27. Renumerar chave primária não é perigoso?**
É, e por isso o `corrigir_ids.sql` se cerca de travas: para (`PARE`) se outra tabela estiver ligada a `aplicacao` ou houver linha
solta; guarda uma "foto" com contagens e somas `CRC32` do conteúdo; troca tudo numa **transação**, desligando as FKs só
durante a troca; **confere dentro da transação** (9 verificações) e só então faz `COMMIT`, senão `ROLLBACK`. ✔ `T4`, `W1`, `W2`. No
RDS real, 71 aplicações foram de ids 7..135 para 1..71 (◇ relatado). Seções 4.13 e 6.8.

**P28. O que garante que o povoamento não deixa o banco pela metade?**
Três coisas: a **verificação prévia** (só leitura) que para com `PARE` se algo estiver fora do esperado; o **teste de permissão**
(`WHERE 1 = 0`) que para antes de gravar; e a **transação com conferência dentro**, que decide `COMMIT` ou `ROLLBACK`. ✔ `T5`,
`U3`, `V1`–`V5`. Seções 4.11, 6.3 a 6.5.

**P29. Como o povoamento distingue dados reais de fictícios?**
Pela tabela `registro_dados_ficticios`, que guarda **só os ids** fictícios (87 linhas); o texto dos registros parece o de um
cadastro normal. O `desfazer` e o BI (coluna `origem_dado`) usam essa tabela. Decisão **D4**: dado sintético **declarado**, ou
seja, a apresentação deve dizer que são sintéticos. Seções 4.12 e 6.6.

**P30. De onde vêm os dados reais?**
Da **base do Diogo** (5 talhões da Sede, 11 aplicadores, 43 insumos, 18 compras reais), dos **mapas impressos** (24 talhões:
Bela Vista 10, Corujas 9, Serra II 5) e da **planilha de defensivos autorizados** da auditoria (o `tipo` de 12 produtos). A planilha
`auditoria-dados.xlsx` foi consolidada pelo Samuel em 07/09/2026. O que é fictício: 70 aplicações, 5 aplicadores, 2 insumos, 10
compras (com preços inventados). Seções 4.2, 4.11 e apêndices.

**P31. Os dados fictícios servem como resultado de pesquisa?**
**Não.** Servem para demonstrar o sistema. As doses e os preços são plausíveis, mas **não são recomendação agronômica** nem
medição. A apresentação deve declarar isso.

### 8.5 Operação e limites

**P32. Como vocês sabem que os scripts funcionam?**
Rodamos a cadeia inteira num MySQL local descartável, com **87 conferências automáticas** (todas OK), a partir do pacote e do
repositório. Seção 7. **O que não foi provado** (RDS real, MySQL 8.4, código Dart, concorrência) também está listado (7.5).

**P33. Existe backup?**
Backup **não faz parte destes scripts**: é configuração do RDS (backup automático e *snapshots*) e **não foi verificado**.
Antes de rodar qualquer script no RDS, convém um *snapshot* manual, porque `DROP DATABASE` e `TRUNCATE` não têm volta.

**P34. E se duas pessoas gravarem ao mesmo tempo?**
O InnoDB trata a concorrência (isolamento `REPEATABLE READ`, o padrão, ✔ conferido no servidor de teste) e cada aplicação é
gravada numa transação. **Nunca foi testado em paralelo.** O `corrigir_ids` deve rodar **sem ninguém usando o programa**.

**P35. E se o volume crescer?**
Hoje são 70 aplicações. Há índices nas chaves primárias, nas `UNIQUE` e nas chaves estrangeiras (o InnoDB cria o índice da FK), mas
**nenhum índice extra** (por exemplo, por data). O serviço de manutenção confere "está em uso?" lendo **todas** as aplicações
(`listarTodos`) e filtrando em Dart; com milhares de linhas, o certo seria trocar por consultas `EXISTS` no banco.

**P36. Por que MySQL na AWS, se o projeto começou em PostgreSQL (Supabase)?**
O primeiro script de dados (`seed_auditoria.sql`) é de PostgreSQL, e o modelo físico do Diogo é MySQL. **O motivo da troca não
está registrado em nenhum arquivo deste pacote.** *Perguntar ao Diogo ou ao Bruno antes de responder.* Seção 4.17.

**P37. O que ficou faltando?**
A lista completa, com severidade, está na seção 9: decisão `CASCADE` × `RESTRICT`, colunas novas fora dos triggers, `roles.sql`
(PI-014) ainda não entregue, tipos provisórios de insumo, DER ainda fora do repositório, e a falta de testes de integração dos
repositórios MySQL.

---

## 9. Pontos em aberto e riscos conhecidos

Lista honesta do que **não está resolvido** ou **tem limite conhecido**. A coluna "Prioridade" é a avaliação de quem escreveu
este documento, e não uma decisão da equipe. Onde há solução, ela foi **testada** no servidor de teste (✔ manual) e **não** foi
aplicada aos arquivos do repositório (cada arquivo tem dono: o `schema.sql` e o `triggers.sql` são do Diogo).

| # | Ponto | Prioridade | Quem decide |
|---|---|---|---|
| 9.1 | `ON DELETE CASCADE` × `RESTRICT` | Alta (auditoria) | Diogo e Bruno |
| 9.2 | Triggers de `aplicacao` não registram as 2 colunas novas | Alta (auditoria) | Diogo |
| 9.3 | `roles.sql` (PI-014) e a criação do `agrogestor_app` no RDS não estão no repositório | Média | Bruno e Diogo |
| 9.4 | Seed 01 provisório; 24 dos 45 insumos seguem com `tipo = 'Insumo'` | Média | Bruno e Diogo |
| 9.5 | `USER()` mostra o computador, não a pessoa (D5) | Média | grupo |
| 9.6 | O histórico cresce e tem ruído | Média/baixa | João e Cristiano |
| 9.7 | Um aplicador por aplicação | Média/baixa | Diogo e grupo |
| 9.8 | Testes do código Dart que toca o banco | Média | João e Cristiano |
| 9.9 | O v7 deste pacote é reconstrução; 5 arquivos auxiliares fora do pacote | Média | João |
| 9.10 | Branch `feat/PI-08-atualizacao-modelo` parada, com `fazendanovo.sql` idêntico ao `schema.sql` | Média | Diogo |
| 9.11 | Lacunas de unicidade: `area.nome` e `insumo.nome` | Baixa | Diogo |
| 9.12 | `insumo.tipo` é texto livre | Baixa | Bruno |
| 9.13 | Padrão de nomes: PI-012 × banco real; `ck_` × `chk_` | Baixa | grupo |
| 9.14 | O DER e o arquivo do Workbench (`.mwb`) não estão no repositório | Baixa | Diogo |
| 9.15 | Área estimada × soma dos mapas | Baixa | agrônomo e grupo |
| 9.16 | `seed_auditoria.sql`: dados pessoais, fora do repositório | Baixa | grupo (D8) |
| 9.17 | Cosméticos: `auditoria.sql` queima ids; `testar_conexao.dart` espera 11 tabelas | Baixa | Diogo e João |

> **Para a apresentação:** se a banca perguntar "o que vocês fariam diferente?", os itens 9.1, 9.2, 9.5 e 9.7 são boas respostas:
> são limites **reais e conhecidos**, e os dois primeiros já têm solução **testada**.

### 9.1 `ON DELETE CASCADE` × `RESTRICT`

**Situação.** O `schema.sql` usa `ON DELETE CASCADE` em três chaves: `fk_aptalhao_aplicacao`, `fk_apinsumo_aplicacao` e
`fk_itemcompra_compra`. A PI-012 e a PI-018 pedem `RESTRICT`. O Bruno ainda não respondeu qual vale.

**Efeito na auditoria.** Um `DELETE` direto na aplicação leva as filhas junto **sem disparar os triggers delas** (✔ `X1`): o
histórico fica sem a exclusão dos talhões e dos insumos. Hoje isso **não acontece pelo programa nem pelos scripts**, porque todos
apagam as filhas **antes** (✔ `X2`); só aconteceria com SQL direto.

| Opção | Vantagem | Custo |
|---|---|---|
| **A. Manter `CASCADE`** | Nada a mudar. | Auditoria completa **só enquanto** todos lembrarem de apagar as filhas antes. |
| **B. Trocar por `RESTRICT`** | O **banco** passa a recusar o `DELETE` direto da aplicação (erro 1451), e a auditoria fica completa por construção. | Todo código e script precisa apagar as filhas antes (o programa e os scripts de desfazer já fazem). |

**Como trocar** (✔ manual). **Um `ALTER` por comando**: tentar `DROP` e `ADD` da mesma chave no **mesmo** comando dá o erro 1826
("Duplicate foreign key constraint name"):

```sql
ALTER TABLE aplicacao_talhao DROP FOREIGN KEY fk_aptalhao_aplicacao;
ALTER TABLE aplicacao_talhao ADD CONSTRAINT fk_aptalhao_aplicacao
  FOREIGN KEY (id_aplicacao) REFERENCES aplicacao (id_aplicacao) ON DELETE RESTRICT;
-- o mesmo para aplicacao_insumo (fk_apinsumo_aplicacao) e item_compra (fk_itemcompra_compra)
```

**O que foi testado com `RESTRICT` ligado** (✔ manual, MySQL 8.0.46): as três chaves passam a `RESTRICT` em
`information_schema.referential_constraints`; um `DELETE` direto de aplicação com filhas dá **1451**; e o `povoamento` (v7), o
`apagar_so_os_exemplos`, o `corrigir_ids` (num banco já certo) e o `desfazer` rodam **sem erro**. *Não testado:* o caminho de
troca de ids do `corrigir_ids` com `RESTRICT` (ele só faz `UPDATE`, que a regra `ON DELETE` não afeta) e o código Dart.

**Cuidado.** `ALTER TABLE` é DDL: **não tem `ROLLBACK`**, e entre o `DROP` e o `ADD` a tabela fica sem a chave. Fazer sem
ninguém usando o programa, e com *snapshot* do RDS antes. No RDS, aplicar pelo `tool/aplicar_sql.dart` ou pelo Workbench, com o
usuário do DBA.

### 9.2 Os triggers de `aplicacao` não registram `horas_ate_chuva` nem `motivo_reaplicacao`

**Situação.** Os triggers foram escritos antes do `ALTER` de reaplicação e listam as colunas **uma a uma** em `JSON_OBJECT`.
O próprio `alter_aplicacao_reaplicacao.sql` avisa: "vale incluir as duas novas neles".

**Como reproduzir** (num banco de **teste**, com schema + triggers + `ALTER`; o `ROLLBACK` desfaz o teste):

```sql
START TRANSACTION;
UPDATE aplicacao SET motivo_reaplicacao = 'chuva', horas_ate_chuva = 2.50 WHERE id_aplicacao = 1;
SELECT dados_anteriores, dados_novos, (dados_anteriores = dados_novos) AS identico
  FROM historico_alteracoes WHERE tabela_afetada = 'aplicacao' AND acao = 'UPDATE'
 ORDER BY id_historico DESC LIMIT 1;
ROLLBACK;
```

**Resultado observado** (✔ manual): `identico = 1`. O histórico mostra que a aplicação mudou, mas **o antes e o depois são
iguais**: a mudança de motivo e de horas **não fica registrada**. (O mesmo vale para `INSERT` e `DELETE`: as duas colunas não
aparecem no JSON.)

**Correção sugerida** (testada numa **cópia** do `triggers.sql`; o arquivo do repositório **não foi alterado**): em cada
`JSON_OBJECT` de `trg_aplicacao_ai` (`NEW`), `trg_aplicacao_au` (`OLD` e `NEW`) e `trg_aplicacao_ad` (`OLD`), acrescentar duas
linhas depois de `'observacao', …`:

```sql
            'observacao', OLD.observacao,
            'horas_ate_chuva', OLD.horas_ate_chuva,
            'motivo_reaplicacao', OLD.motivo_reaplicacao
```

(com `NEW.` no lado novo). São **4 trechos**. Com a correção, o mesmo `UPDATE` do teste gerou `motivo_reaplicacao`
`null → "chuva"` e `horas_ate_chuva` `10.60 → 2.50`, e `identico = 0`. As linhas antigas do histórico continuam sem as duas
chaves (o histórico não se edita). Depois de alterar o arquivo, recriar os triggers (ele tem `DROP TRIGGER IF EXISTS`, então
pode rodar de novo) pelo `tool/aplicar_sql.dart`, e **rodar de novo o `validar_cadeia.sh`**.

### 9.3 `roles.sql` (PI-014) e o usuário da aplicação

O `roles.sql` do Bruno, que criaria o `agrogestor_app` no RDS com os 4 privilégios, **não chegou ao repositório**. O que existe é
o `usuario_app_LOCAL.sql`, um **modelo** para teste local. Consequência: **a criação do usuário que o programa usa no RDS não
está documentada em script versionado**. Se o Bruno mandar o `roles.sql`, o dele vale. O `banco/README.md` que a PI-014
reservava foi escrito neste pacote; se o Bruno entregar o dele, juntar os dois.

### 9.4 Seed 01 provisório e tipos de insumo

O `01_base.sql` oficial nunca chegou ao Diogo; o `01_base_RECONSTRUIDO.sql` foi montado para o banco poder ser recriado do zero.
**Sem fonte** (diz o próprio cabeçalho): `insumo.tipo` (valor provisório `'Insumo'`, porque a coluna é obrigatória),
a capacidade em kg dos aplicadores (70 e 20, igual aos litros) e `insumo.marca` (vazia). Mesmo **depois do povoamento v7**, ✔ manual:
**24 dos 45 insumos continuam com `tipo = 'Insumo'`** (21 têm tipo real: 12 da planilha de defensivos, 7 deduzidos pelo nome e 2
fictícios). No BI, essas 24 linhas viram uma grande categoria "Insumo". **Quando o Bruno mandar o `01_base.sql`, comparar e trocar.**

### 9.5 `USER()` mostra o computador, e não a pessoa (decisão D5)

O histórico registra `agrogestor_app@<IP>`. Como a equipe usa o mesmo usuário, o histórico não distingue quem fez. Caminhos
possíveis (**nenhum implementado**): (a) um usuário de banco por pessoa; (b) o programa grava o nome da pessoa numa variável de
sessão (`SET @usuario_app = …`) que o trigger lê, com `USER()` de reserva. A decisão D5 (identificar funcionários) segue em aberto
no README.

### 9.6 O histórico cresce e tem ruído

(a) Não há rotina de arquivamento; o histórico só cresce, de propósito. (b) Toda **edição** de aplicação apaga e regrava **todas** as
filhas (seção 5.4), gerando um `DELETE` e um `INSERT` por talhão e por insumo mesmo que só a observação tenha mudado. Uma melhoria
no repositório Dart seria **comparar e gravar só o que mudou** (✘ não implementada). (c) O povoamento e o `desfazer` também passam pelos
triggers (531 e 519 linhas), o que é esperado.

### 9.7 Um aplicador por aplicação

Registrado no próprio `schema.sql` como pendência ("pendência dos dois equipamentos em aberto"). Uma aplicação feita com trator
**e** drone não cabe hoje. A solução seria uma tabela de ligação `aplicacao_aplicador` e mover `id_aplicador` para ela, o que
exige migração dos dados e mudança no programa. Os 6 voos de drone do seed 04 foram deixados de fora por causa disso.

### 9.8 Testes do código Dart que toca o banco

Só a `AreaRepositoryMysql` tem teste de integração. **Não têm:** `TalhaoRepositoryMysql`, `InsumoRepositoryMysql`,
`AplicadorRepositoryMysql`, `OperacaoRepositoryMysql` e, principalmente, a **`AplicacaoRepositoryMysql`** (a mais complexa: três
tabelas e transação). O `tool/aplicar_sql.dart` também não tem teste e **não foi compilado** (seção 4.8). O CI do repositório roda
`dart format --output=none --set-exit-if-changed .`, `dart analyze --fatal-infos` e `dart test`: **rodar os três antes de abrir o PR**.

### 9.9 O v7 deste pacote e os 5 arquivos auxiliares

O povoamento v7 é uma **reconstrução** (seção 4.11), validada por tamanho, `diff` mínimo contra o v6 e pelos 87 testes. Antes de usar
no RDS, **comparar com o arquivo que a equipe já recebeu** (`povoamento_caderno_de_campo.zip`, versão 7). Os 5 arquivos auxiliares
(`exemplos_apresentacao.sql`, `diagnostico_banco.sql`, `auditoria_dados_reais.sql`, `criar_tabela_controle.sql` e
`exemplos_para_o_terminal.txt`) **não estão neste pacote** (seção 4.19).

### 9.10 Branch `feat/PI-08-atualizacao-modelo`

O commit "Reformulação das tabelas SQL" (Diogo, 20/10/2026) criou `banco/fazendanovo.sql` nessa branch, com conteúdo **idêntico** ao
`schema.sql` (só muda a última linha em branco). A branch **não foi mesclada**. Mesclar **e** adicionar o `schema.sql` deixaria **dois
arquivos iguais** e dois nomes para o mesmo schema. Escolher um (e fechar a branch).

### 9.11 a 9.17 (resumo)

- **9.11 Unicidade.** `area.nome` e `insumo.nome` não têm `UNIQUE` (seção 8, P7). O povoamento detecta nomes repetidos e para.
- **9.12 `insumo.tipo`.** Texto livre: `Inseticida`, `Inseticida microbiologico` e `Inseticida/Fungicida` viram três categorias no
  BI (✔ manual). Uma lista fechada ou uma tabela de tipos resolveria.
- **9.13 Nomes.** A PI-012 manda `schema agrogestor` e chave `id`; o banco real é `caderno_fazenda` com `id_<tabela>` (o
  `.env.example` e o README tratam como "em aberto"). Também há dois prefixos de `CHECK`: `ck_` no schema e `chk_` no `ALTER` de
  reaplicação.
- **9.14 DER.** O cabeçalho do `schema.sql` cita `docs/modelagem/der_completo.md` e o `.mwb`, que **não estão no repositório**
  (`docs/modelagem/` só tem `.gitkeep`).
- **9.15 Áreas.** A estimativa de 2026 e a soma dos mapas diferem: Bela Vista 60,00 × 60,15; Corujas 31,98 × 35,88; Serra II 30,60 ×
  30,70 (total impresso no mapa da Serra II: 32,79). O povoamento mantém os hectares da estimativa e **escreve a diferença na
  descrição da área** (passo A2). Qual vale é decisão de quem conhece a propriedade.
- **9.16 `seed_auditoria.sql`.** É PostgreSQL e tem nomes de pessoas físicas, coordenadas e valores comerciais; por isso fica **fora**
  do repositório (decisão D8: dados comerciais e pessoais de terceiros não vão para repositório público). Seção 4.17.
- **9.17 Cosméticos.** O `auditoria.sql` queima ids (contadores em 9002; rodar em banco de teste). O `bin/testar_conexao.dart` imprime
  "esperado: 11" tabelas, mas **depois do povoamento são 12** (a tabela de controle): parece falha e não é.

---

## 10. Segurança: o que nunca vai para o Git

O repositório é do GitHub e **deve ser tratado como público**. Nunca commitar:

| O quê | Por quê | Como o repositório já protege |
|---|---|---|
| **Senhas** (administrador, `agrogestor_app`, qualquer outra), em arquivo, em mensagem ou em chat | Quem as ler acessa o banco | Nenhum script tem senha. Os scripts de teste geram a senha ao acaso e não a gravam. O `aplicar_sql.dart` pede a do administrador sem eco. `MYSQL_PWD` só no terminal. |
| O arquivo **`.env`** | Guarda `DB_HOST`, `DB_USER`, `DB_PASSWORD` | No `.gitignore`. O `.env.example` só tem os **nomes**. |
| O **endereço do RDS** (`DB_HOST`) | Aponta para o servidor da equipe | Fica só no `.env`; peça ao Diogo. Não colar em README, issue, print ou script versionado. |
| Arquivos **`*.local.sql`** | Padrão para scripts com senha real | No `.gitignore`. |
| **`global-bundle.pem`** | Certificados da AWS (públicos, mas cada pessoa baixa o seu) | No `.gitignore`. |
| **Dados pessoais e comerciais de terceiros** (nomes de pessoas físicas, CNPJ, coordenadas, valores de venda) | Privacidade e decisão D8 | O `seed_auditoria.sql` fica **fora** do repositório; o povoamento não carrega esses dados. |
| **Dumps e backups** do banco; **prints** com host, usuário ou senha | Podem conter dados reais ou segredos | Nenhuma proteção automática: revisar antes de anexar. |

**Antes de cada commit**, conferir o que vai subir (o `grep` abaixo procura, nas linhas **adicionadas**, uma senha escrita no `IDENTIFIED BY`, um `DB_PASSWORD=` com valor ou o endereço de um RDS; **não deve imprimir nada**; o documento `porque_de_cada_script.md` fica de fora porque cita esses padrões como exemplo; e mesmo assim vale ler o `git diff`):

```
git status
git diff --cached -- . ':!docs/banco/porque_de_cada_script.md' | grep -n -i -E "^\+.*(identified by '[^<]|db_password=[^ ]|rds\.amazonaws\.com)"
```

**Se uma senha vazar** (foi para um commit, um chat ou um print): **trocar a senha no banco** (`ALTER USER … IDENTIFIED BY …`, feito pelo
Diogo) e avisar o grupo. **Apagar o arquivo depois não basta:** o texto continua no histórico do Git e em quem já clonou. Trocar a senha é o que resolve.

---

## 11. Glossário

| Termo | Significado |
|---|---|
| **Schema** | O conjunto de tabelas e restrições do banco (`caderno_fazenda`). No MySQL, "schema" e "database" são o mesmo. |
| **DDL / DML** | DDL: comandos que mudam a **estrutura** (`CREATE`, `ALTER`, `DROP`, `TRUNCATE`); confirmam sozinhos e **não têm `ROLLBACK`**. DML: comandos que mudam **dados** (`INSERT`, `UPDATE`, `DELETE`); podem ser desfeitos. |
| **Transação** | Um bloco de comandos que vale **tudo ou nada**: `START TRANSACTION` … `COMMIT` (confirma) ou `ROLLBACK` (desfaz). |
| **PK / FK** | Chave primária (identifica a linha) e chave estrangeira (aponta para a linha de outra tabela). |
| **Chave composta** | Chave primária formada por duas colunas, como `(id_aplicacao, id_talhao)`. |
| **`CASCADE` / `RESTRICT` / `NO ACTION`** | O que acontece com as filhas quando o pai é apagado: `CASCADE` apaga junto; `RESTRICT` e `NO ACTION` **recusam** (no InnoDB, equivalem). |
| **`CHECK`** | Regra que a linha precisa cumprir (`hectares > 0`). Só vale no MySQL ≥ 8.0.16. |
| **`UNIQUE`** | Impede valores repetidos. |
| **`ENUM`** | Coluna que só aceita valores de uma lista fechada. |
| **Collation** | Regra de comparação de texto (`utf8mb4_0900_ai_ci`: ignora acento e maiúscula). |
| **`AUTO_INCREMENT`** | Contador que gera o próximo id. Só anda para a frente (seção 6.7). |
| **Trigger** | Código que o banco roda sozinho antes (`BEFORE`) ou depois (`AFTER`) de um `INSERT`, `UPDATE` ou `DELETE`. |
| **`SIGNAL`** | Comando que **lança um erro** de propósito dentro de um trigger (erro 1644 com `SQLSTATE '45000'`). |
| **`USER()` / `CURRENT_USER()`** | Quem se conectou × quem criou o trigger (seção 4.3). |
| **`DELIMITER`** | Comando do cliente `mysql` que troca o terminador (`;` → `$$`) para o corpo de um trigger não ser cortado. |
| **`PREPARE`** | Executa um comando montado como **texto** (seção 6.2). |
| **Idempotente** | Que pode rodar de novo sem duplicar nem estragar (seção 6.1). |
| **Povoamento** | Script que enche o banco com dados (reais e fictícios). *Seed* é a carga inicial mínima. |
| **Tabela de controle** | `registro_dados_ficticios`: lista os ids dos dados fictícios (seção 4.12). |
| **`CRC32`** | Soma de verificação de um texto; serve para comparar conteúdo antes e depois (seção 6.8). |
| **InnoDB** | O mecanismo de armazenamento do MySQL que tem transação e chaves estrangeiras. Todas as 12 tabelas usam. |
| **RDS** | O MySQL gerenciado da AWS onde está o banco da equipe. O *security group* é a lista de IPs que podem conectar. |
| **TLS** | A criptografia da conexão. O `global-bundle.pem` tem os certificados da AWS que o programa usa para confiar no servidor. |
| **DBA** | Administrador do banco (Diogo): único que muda estrutura e triggers. |
| **BI** | *Business Intelligence*: painéis (Power BI) que leem o banco (Bruno e Samuel). |
| **PI-012, 014, 017, 018, 023** | Tarefas do Projeto Integrador: `schema.sql` (012), `roles.sql` e `banco/README.md` (014), seeds (017), triggers (018) e o repositório MySQL em Dart (023). |
| **D1, D4, D5, D8** | Decisões do projeto: D1 volume de calda (calculado); D4 dado sintético **declarado**; D5 como identificar funcionários (em aberto); D8 dados de terceiros fora de repositório público. |
| **Safe update mode** | Modo do Workbench que recusa `UPDATE`/`DELETE` sem chave no `WHERE` (erro 1175). |

## Apêndices

Dados de apoio que o documento cita: os insumos da base, os talhões e aplicadores da Sede, as compras reais e os talhões lidos dos mapas.

### Apêndice A. Os 43 insumos da base (seed 01)

| id | nome | tipo no seed 01 |
|---:|---|---|
| 1 | BioKiller | Insumo |
| 2 | Ammoles | Insumo |
| 3 | Acanne | Insumo |
| 4 | Polme | Insumo |
| 5 | Alfol Calcio | Insumo |
| 6 | Alfol Boro | Insumo |
| 7 | Coda Best | Insumo |
| 8 | Coda Eros | Insumo |
| 9 | Coda Drip | Insumo |
| 10 | Coda Harmony | Insumo |
| 11 | Coda Spill | Insumo |
| 12 | Valuva | Insumo |
| 13 | Orkestra SC | Insumo |
| 14 | Alion SC500 | Insumo |
| 15 | Galigan | Insumo |
| 16 | Glucare | Insumo |
| 17 | Glufosinate Ammonium 200 G/L SL | Insumo |
| 18 | Grasidim | Insumo |
| 19 | Tremor | Insumo |
| 20 | Zartan | Insumo |
| 21 | Melyra | Insumo |
| 22 | Opera | Insumo |
| 23 | Valpura EC | Insumo |
| 24 | Curbix SC200 | Insumo |
| 25 | Fastac | Insumo |
| 26 | Nomolt | Insumo |
| 27 | Premier Plus SC | Insumo |
| 28 | Verango Prime SC500 | Insumo |
| 29 | Supreme Mineral N1 | Insumo |
| 30 | Reforce Ultra | Insumo |
| 31 | YaraLiva Nitrabo | Insumo |
| 32 | Blend Mg-Zn-B | Insumo |
| 33 | Transfer UP | Insumo |
| 34 | Cal Super | Insumo |
| 35 | Boro Super | Insumo |
| 36 | Ferriflo NG | Insumo |
| 37 | Maxi Zinc | Insumo |
| 38 | Pledge | Insumo |
| 39 | Poquer | Insumo |
| 40 | Roundup Original | Insumo |
| 41 | Crop Best | Insumo |
| 42 | Crop Exit S | Insumo |
| 43 | Spirit | Insumo |

Total: **43** insumos, todos com `tipo = 'Insumo'` (valor provisório) e `marca` vazia.

### Apêndice B. Talhões da Sede e aplicadores da base (seed 01)

| talhão (área Sede, id 1) | hectares |
|---|---:|
| Chico1 | 2.80 |
| Chico2 | 3.80 |
| Pinheiro | 2.05 |
| Engenho | 4.90 |
| Cafe Velho | 6.40 |
| **soma** | **19.95** |

| id | modelo | tipo | capacidade (L) | capacidade (kg) |
|---:|---|---|---:|---:|
| 1 | Drone DJI | drone | 70 | 70 |
| 2 | Bomba costal Jacto 1 | bomba costal | 20 | 20 |
| 3 | Bomba costal Jacto 2 | bomba costal | 20 | 20 |
| 4 | Bomba costal Jacto 3 | bomba costal | 20 | 20 |
| 5 | Bomba costal Jacto 4 | bomba costal | 20 | 20 |
| 6 | Bomba costal Jacto 5 | bomba costal | 20 | 20 |
| 7 | Bomba costal Jacto 6 | bomba costal | 20 | 20 |
| 8 | Bomba costal Jacto 7 | bomba costal | 20 | 20 |
| 9 | Bomba costal Jacto 8 | bomba costal | 20 | 20 |
| 10 | Bomba costal Jacto 9 | bomba costal | 20 | 20 |
| 11 | Bomba costal Jacto 10 | bomba costal | 20 | 20 |

A capacidade em kg (70 e 20) **não tem fonte**: foi copiada igual à de litros (ver seção 9).

### Apêndice C. As 18 compras reais da base (seed 03)

| id | data da nota | número da nota | itens |
|---:|---|---|---:|
| 1 | 25/04/2025 | 3257 | 3 |
| 2 | 03/10/2025 | 4591 | 1 |
| 3 | 02/12/2025 | 5685 | 2 |
| 4 | 05/01/2026 | 6060 | 5 |
| 5 | 08/01/2026 | 418604 | 1 |
| 6 | 14/01/2026 | 419201 | 1 |
| 7 | 06/02/2026 | 6391 | 2 |
| 8 | 10/02/2026 | 68606 | 1 |
| 9 | 16/03/2026 | 424602 | 1 |
| 10 | 17/03/2026 | 6671 | 4 |
| 11 | 25/03/2026 | 6749 | 4 |
| 12 | 08/04/2026 | 6855 | 4 |
| 13 | 16/04/2026 | 6916 | 4 |
| 14 | 15/06/2026 | 432029 | 2 |
| 15 | 17/07/2026 | 388564 | 1 |
| 16 | 20/07/2026 | 388650 | 1 |
| 17 | 20/07/2026 | 7236 | 1 |
| 18 | 30/07/2026 | 7292 | 5 |

Total: **18** compras e **43** itens. Não entram preço, valor total, fornecedor nem CNPJ.

### Apêndice D. Os 24 talhões lidos dos mapas impressos (passo A1 do povoamento)

| área | talhão | hectares |
|---|---|---:|
| Bela Vista | 7 A (Cima) | 5.40 |
| Bela Vista | 7 B (Baixo) | 5.25 |
| Bela Vista | Caixa D'agua | 6.50 |
| Bela Vista | Tambor | 4.90 |
| Bela Vista | Casa | 7.00 |
| Bela Vista | Paulao | 9.40 |
| Bela Vista | Torres | 5.20 |
| Bela Vista | Pereira | 5.40 |
| Bela Vista | Gariroba | 6.55 |
| Bela Vista | Mato | 4.55 |
| Corujas | Serra | 3.35 |
| Corujas | Ype | 4.63 |
| Corujas | Mangueira | 3.20 |
| Corujas | Ladeirinha | 6.55 |
| Corujas | Bananeira Roxa | 2.30 |
| Corujas | Caixa D'agua | 1.70 |
| Corujas | Peao | 3.25 |
| Corujas | Carlinho | 6.30 |
| Corujas | Jose Candido | 4.60 |
| Serra II | Douglas 48 | 5.81 |
| Serra II | Douglas 49 | 5.83 |
| Serra II | Douglas 50 | 6.35 |
| Serra II | Douglas 51 | 5.91 |
| Serra II | Douglas Serra | 6.80 |

| área | talhões | soma dos mapas (ha) |
|---|---:|---:|
| Bela Vista | 10 | 60.15 |
| Corujas | 9 | 35.88 |
| Serra II | 5 | 30.70 |

A soma dos mapas **não bate** com a estimativa da auditoria (Bela Vista 60,00; Corujas 31,98; Serra II 30,60) e, na Serra II, nem com o total impresso no mapa (32,79). A diferença está registrada na descrição de cada área (passo A2).
