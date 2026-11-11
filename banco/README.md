# Banco de dados do Caderno de Campo (`banco/`)

Scripts SQL do banco `caderno_fazenda` (MySQL 8, hospedado no AWS RDS). Esta pasta reúne **tudo o que a equipe usou no banco**:
o modelo, a carga inicial, a auditoria por triggers, o povoamento de demonstração, os scripts de correção e os testes.

> **Leitura completa, com o porquê de cada script, os testes e as perguntas prováveis da banca:**
> [`docs/banco/porque_de_cada_script.md`](../docs/banco/porque_de_cada_script.md).
> O contrato entre o código Dart e o SQL (nomes, regras, o que ainda falta) está em
> [`RESERVADO_PARA_SQL.md`](RESERVADO_PARA_SQL.md).

## O que há aqui

```
banco/
├── schema.sql                        as 11 tabelas (PI-012). COMEÇA COM DROP DATABASE: apaga o banco
├── triggers.sql                      14 triggers: auditoria + histórico imutável (PI-018)
├── alter_aplicacao_reaplicacao.sql   2 colunas em aplicacao: horas_ate_chuva e motivo_reaplicacao
├── seeds/                            carga inicial, para banco VAZIO (PI-017)
│   ├── 01_base_RECONSTRUIDO.sql      provisório (o 01_base.sql oficial ainda não chegou)
│   ├── 02_areas_operacoes.sql
│   ├── 03_compras.sql
│   └── opcionais/04_aplicacoes_drone_CONFERIR.sql   NÃO rodar no banco que o programa usa
├── recriar_do_zero/tudo_em_um.sql    schema + seeds 01 a 03 + triggers, de uma vez. APAGA o banco
├── povoamento/                       dados reais (mapas e planilha da auditoria) + fictícios, para a demonstração
│   ├── povoamento_caderno_de_campo.sql   versão 7: roda em banco que já tem dados e não duplica
│   ├── corrigir_ids.sql              renumera as aplicações (1, 2, 3…) e acerta os contadores
│   ├── desfazer_dados_ficticios.sql  apaga só o que é fictício
│   ├── apagar_so_os_exemplos.sql     apaga só os 10 exemplos de apresentação ([DEMO #nn])
│   ├── LEIA-ME.txt                   passo a passo original do povoamento
│   └── historico/povoamento_v6_executado_no_rds.sql   o que foi executado no RDS (não rodar de novo)
├── testes/
│   ├── conferencia.sql               8 consultas de só leitura (logo depois do tudo_em_um)
│   ├── auditoria.sql                 prova dos triggers (termina em ROLLBACK)
│   └── usuario_app_LOCAL.sql         modelo do usuário da aplicação, só para teste local
└── validacao/
    ├── validar_cadeia.sh             roda tudo num MySQL local descartável e confere 87 resultados
    ├── LEIAME_VALIDACAO.md           o que foi provado, o que não, e como repetir
    └── resultado_2026-11-10.txt      87 de 87 conferências OK (MySQL 8.0.46)
```

O programa em Dart que usa o banco está em `lib/repositories/mysql/`, e `tool/aplicar_sql.dart` aplica um arquivo `.sql` no RDS
pelo terminal (usado para os triggers).

## Qual script rodar

| Situação | O que rodar, nesta ordem | Cuidado |
|---|---|---|
| **A. Banco novo no seu computador** (MySQL 8.0.16 ou mais novo) | `recriar_do_zero/tudo_em_um.sql` → `testes/conferencia.sql` → `alter_aplicacao_reaplicacao.sql` → (opcional) `povoamento/povoamento_caderno_de_campo.sql` | `tudo_em_um.sql` **apaga** o banco `caderno_fazenda`. No Workbench, abrir o arquivo e clicar no raio **sem selecionar nenhuma linha**. |
| **B. O banco que já está no ar (RDS da equipe)** | **Nunca** `schema.sql` nem `tudo_em_um.sql`. Para carregar dados: `povoamento/povoamento_caderno_de_campo.sql`. Se as aplicações estiverem com números pulados: `povoamento/corrigir_ids.sql` (usuário do DBA). Triggers: `dart run tool/aplicar_sql.dart banco/triggers.sql` | Qualquer arquivo com `DROP DATABASE` apaga os dados da equipe. |
| **C. Ensaio e apresentação** | ensaiar no terminal → `povoamento/apagar_so_os_exemplos.sql` → `povoamento/corrigir_ids.sql` (antes de apresentar, para a numeração não pular) → apresentar → `povoamento/desfazer_dados_ficticios.sql` | O número de uma linha apagada não volta sozinho. |

**Regra de ouro:** só `povoamento/` e `alter_aplicacao_reaplicacao.sql` foram escritos para rodar **num banco que já tem dados**.
`schema.sql`, `recriar_do_zero/` e `seeds/` são para banco **vazio**.

## Avisos

- **Senhas nunca vão para o Git, para o chat nem para um arquivo `.sql`.** Os scripts de teste geram a senha ao acaso; o
  `aplicar_sql.dart` pede a senha do administrador no terminal; o programa lê `DB_*` do ambiente. Veja `.env.example`.
- O usuário do programa (`agrogestor_app`) só tem `SELECT`, `INSERT`, `UPDATE` e `DELETE`. Criar tabela, alterar estrutura e
  trigger é com o **administrador** (o DBA).
- **"PARE" não é bug.** O povoamento e o `corrigir_ids` terminam com o erro 1064 e a mensagem `PARE: …` quando acham algo fora do
  esperado, **antes de gravar qualquer coisa**.
- **Depois do povoamento o banco tem 12 tabelas**: ele cria a tabela de controle `registro_dados_ficticios` (não faz parte do
  `schema.sql`), que guarda quais registros são fictícios.
- Os dados fictícios são **sintéticos e declarados** (decisão D4): servem para demonstrar o sistema, não são recomendação
  agronômica nem medição.

## O que foi verificado e o que não foi

Toda a cadeia (schema → seeds → triggers → `ALTER` → povoamento → correção → desfazer) foi executada em **MySQL 8.0.46** local
e descartável, com **87 conferências automáticas, todas OK**. Não foram verificados: a execução no **MySQL 8.4 do RDS**, o
código Dart (não compilado nessa validação), concorrência e volume. A lista completa está na seção 7 do documento
`docs/banco/porque_de_cada_script.md`.

## O que ainda falta

- `roles.sql` (PI-014): criação do usuário `agrogestor_app` no RDS. Hoje só existe o modelo local `testes/usuario_app_LOCAL.sql`.
- Decisão `ON DELETE CASCADE` × `RESTRICT` (PI-012 e PI-018 pedem `RESTRICT`) e inclusão das colunas de reaplicação nos
  triggers de `aplicacao`: seção 9 do documento, com a correção testada.
- `01_base.sql` oficial (o do `seeds/` é reconstruído e traz o tipo provisório `'Insumo'`).
- DER e arquivo do Workbench em `docs/modelagem/`.
- Cinco arquivos auxiliares do povoamento citados em `povoamento/LEIA-ME.txt` (`exemplos_apresentacao.sql`,
  `diagnostico_banco.sql`, `auditoria_dados_reais.sql`, `criar_tabela_controle.sql` e `exemplos_para_o_terminal.txt`) ficam no
  pacote `povoamento_caderno_de_campo.zip` que o grupo recebeu; não estão neste repositório.
