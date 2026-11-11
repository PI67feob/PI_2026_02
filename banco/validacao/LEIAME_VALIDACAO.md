# Validação da cadeia de scripts do banco

Este arquivo explica **o que foi testado**, **como foi testado** e **como repetir o teste** no seu computador.

> **Resultado de 10/11/2026:** `87 de 87 conferências OK` — MySQL 8.0.46 (Ubuntu 24.04), servidor privado e descartável.
> Veja `resultado_2026-11-10.txt` (resumo). A saída completa de cada script, como o MySQL devolveu, fica na pasta `saidas_brutas/`
> do **pacote de entrega** (não vai para o repositório) e é gerada de novo a cada execução, na pasta indicada por `SAIDA` (veja abaixo).

## O que a validação prova (e o que não prova)

**Prova**, num MySQL 8.0.46 limpo:

| Bloco | O que foi provado |
|---|---|
| T1 | `tudo_em_um.sql` cria 11 tabelas, 14 triggers, collation `utf8mb4_0900_ai_ci`, e a base do Diogo entra com as contagens esperadas (4 áreas, 5 talhões, 2 operações, 11 aplicadores, 43 insumos, 18 compras, 43 itens). `testes/conferencia.sql` dá 19 linhas `OK` e nenhuma `DIFERENTE`. |
| T2 | `alter_aplicacao_reaplicacao.sql` cria `horas_ate_chuva DECIMAL(6,2)` e `motivo_reaplicacao VARCHAR(20)`, ambas aceitando NULL. **Rodar o ALTER duas vezes dá erro 3822** (nome de CHECK repetido): ele não é repetível, e isso está documentado. O CHECK recusa motivo fora da lista (erro 3819). |
| T3 | `testes/auditoria.sql` prova os 12 triggers de auditoria (INSERT/UPDATE/DELETE em 4 tabelas), a coluna `usuario` e que `UPDATE`/`DELETE` em `historico_alteracoes` são recusados (erro 1644). O `ROLLBACK` final não deixa histórico, mas os contadores de AUTO_INCREMENT ficam em 9002 (talhão 9003). |
| T4 | Cenário igual ao do RDS: ids 1–2 "queimados", povoamento v6 (o que foi executado), 70 aplicações com ids começando em 3, **próximo id pulando para 130** (o `INSERT … SELECT` reserva ids em blocos), e `corrigir_ids.sql` reduz para 1..71 com próximo id 72. Rodar `corrigir_ids` de novo não troca nada e não cresce o histórico. |
| T5 | Banco novo + povoamento v7: 70 aplicações com ids 1..70, próximo id 71, cadastro manual recebe 71. Rodar o v7 de novo não duplica nada (idempotente). |
| T6 | `desfazer_dados_ficticios.sql` volta ao estado "base real + talhões reais"; `apagar_so_os_exemplos.sql` apaga só as aplicações `[DEMO #n]`. |
| T7 | O v7 rodado **por cima** de um banco que já recebeu o v6 não duplica nada e **não renumera** (ids continuam 3..72; quem renumera é o `corrigir_ids.sql`). |
| U0–U1 | Com o usuário da aplicação (`agrogestor_app`, só SELECT/INSERT/UPDATE/DELETE) a auditoria funciona e a coluna `usuario` mostra `agrogestor_app@localhost` — nunca `root@` (porque o trigger usa `USER()`, não `CURRENT_USER()`). |
| U2–U3 | Esse mesmo usuário **não** consegue rodar `corrigir_ids` (`ALTER command denied`) nem o povoamento (`CREATE command denied`): o script para e nada é gravado. |
| U4–U5 | Item fora do conjunto usado pelo povoamento não trava; banco só com tabelas+triggers (sem seeds) recebe tudo (`CARGA COMPLETA`, 574 linhas de histórico, 87 linhas na tabela de controle). |
| V1–V5 | A trava `PARE` do povoamento: área "Sede" duplicada, aplicador usado faltando, insumo usado renomeado → para com erro 1064 e nada é gravado. Cliente que **continua após erro** (`mysql --force`) também não grava: a sessão vira somente-leitura e os comandos seguintes dão erro 1792. |
| W1–W3 | As travas do `corrigir_ids.sql`: linha órfã de talhão/insumo, outra tabela ligada a `aplicacao`, banco sem aplicações. |
| X1–X2 | **O `ON DELETE CASCADE` não dispara os triggers das tabelas filhas.** Apagar só a `aplicacao` remove `aplicacao_talhao` e `aplicacao_insumo` por cascata, e o histórico registra apenas o `DELETE` da aplicação (as filhas somem sem rastro). Apagando as filhas antes (como faz o programa Dart e os scripts de desfazer), o histórico registra as três exclusões. É o argumento técnico a favor de `RESTRICT` (decisão em aberto). |

**Não prova:**

* Nada foi executado no RDS da equipe por este teste. O que rodou no RDS foi feito pelo Diogo/João e está nos prints do Discord (povoamento v6 → 71 aplicações, ids 7..135; `corrigir_ids` → ids 1..71, próximo id 72).
* O MySQL do RDS é 8.4; este teste usou **8.0.46**. As versões 8.0.16 em diante têm os recursos usados (CHECK, `ROW_NUMBER()`, `utf8mb4_0900_ai_ci`), mas a execução em 8.4 desta sessão **não foi refeita** (o LEIA-ME do povoamento v7, da sessão anterior, registra testes em 8.4.0; só 8.0.46 foi reverificado hoje).
* O código Dart (`app_dart/`, `tool/aplicar_sql.dart`) **não foi compilado nem testado** aqui (não havia SDK Dart disponível). `dart format`, `dart analyze` e `dart test` precisam ser rodados por quem tem o SDK.
* O arquivo `povoamento_caderno_de_campo.sql` (v7) deste pacote é uma **reconstrução** a partir da conversa, conferida pelo tamanho (101.104 bytes) e pelos resultados dos testes acima; o v6, que foi o executado no RDS, é o arquivo original enviado pelo João (100.261 bytes).

## Como repetir (no seu computador, **nunca no RDS**)

O script `validar_cadeia.sh` **apaga e recria** o banco `caderno_fazenda` várias vezes. Ele tem travas: só aceita servidor local (socket ou 127.0.0.1), recusa servidor com cara de RDS, exige a variável de confirmação e exige MySQL ≥ 8.0.16 (MariaDB não vale).

### 1. Suba um MySQL 8 descartável (só por socket, sem rede)

```bash
B=$HOME/mysql_teste
mkdir -p $B/data $B/run
mysqld --initialize-insecure --datadir=$B/data          # cria os dados; usuário root sem senha, só por socket
mysqld --daemonize --datadir=$B/data --socket=$B/run/mysql.sock --pid-file=$B/run/mysql.pid \
       --skip-networking --mysqlx=OFF --log-error=$B/run/erro.log \
       --secure-file-priv=NULL --default-time-zone=+00:00
```

(`--skip-networking` garante que nada fora do seu computador consiga se conectar. Se o `mysqld` reclamar de `/var/lib/mysql-files`, é por isso que existe o `--secure-file-priv=NULL`.)

Esta receita foi usada no **Ubuntu 24.04 com o pacote `mysql-server` 8.0**. Em outros sistemas o que importa é: servidor **local**, MySQL **≥ 8.0.16** e a conexão do teste chegando como `localhost` (os usuários de teste são `'agrogestor_app'@'localhost'`). Atenção: um MySQL em container Docker acessado por TCP a partir do computador **não** chega como `localhost` (chega com o IP da ponte do Docker) e os testes U falhariam; se usar Docker, rode o script **dentro** do container, pelo socket. Essa variante não foi testada aqui.

### 2. Rode

```bash
export MYSQL_SOCKET=$HOME/mysql_teste/run/mysql.sock     # ou: export MYSQL_HOST=127.0.0.1 MYSQL_PORT=3307
export CONFIRMO_APAGAR_CADERNO_FAZENDA_LOCAL=sim
bash validacao/validar_cadeia.sh                         # no repositório: bash banco/validacao/validar_cadeia.sh
```

Termina com `TUDO OK.` e código de saída 0 se as 87 conferências derem OK; se alguma falhar, imprime `obtido` e `esperado` e sai com o número de falhas. Leva cerca de 6 segundos.

### 3. Observações

* **Senha:** nunca vai em arquivo. Se o seu MySQL de teste tiver senha para o administrador, use `export MYSQL_PWD=...` só no terminal (o cliente `mysql` lê sozinho). A senha do usuário `agrogestor_app` usada nos testes U é gerada na hora, ao acaso, e não é gravada em lugar nenhum.
* Os testes **U** conectam como `agrogestor_app@localhost`; por isso a conexão tem de ser local (socket ou 127.0.0.1/localhost).
* O teste **U5** usa `python3` (com `-I`) só para montar o arquivo "só tabelas + triggers" a partir dos marcadores do `tudo_em_um.sql`.
* `SAIDA=/pasta` muda onde ficam as saídas brutas (padrão: `validacao/saida`, apagada a cada execução).
* A pasta `historico_sessao_anterior/` guarda, **só como registro**, dois scripts de uma sessão anterior (`sim_rds.sh`, `cenarios.sh`). Eles apontam para caminhos de uma máquina que não existe mais e dependem de arquivos auxiliares que não estão aqui; não os rode. Servem para mostrar quais cenários (C1–C9) foram pensados para o `corrigir_ids.sql`: estado igual ao do RDS, buracos + contador alto, só contador alto, sem aplicações, sem tabela de controle, usuário sem ALTER, linha órfã, outra tabela ligada, e cadastro novo depois da correção (recebe id 78).
