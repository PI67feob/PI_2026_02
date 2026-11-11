-- ============================================================
-- banco/testes/auditoria.sql
-- Prova que os triggers de auditoria funcionam, sem deixar linhas no banco
-- (tudo termina em ROLLBACK).
--
-- QUANDO RODAR: depois do schema (criar_banco.sql), dos seeds e do banco/triggers.sql.
--
-- COMO RODAR (duas vezes, com duas conexoes diferentes):
--   1) conectado como root;
--   2) conectado como agrogestor_app (usuario da tarefa PI-014).
--   Na segunda, a coluna "usuario" tem que mostrar agrogestor_app@...
--   e NAO root. Anexe o print das duas ao PR.
--
-- PARTE 1: roda o arquivo inteiro. Tudo acontece dentro de uma
--   transacao que termina em ROLLBACK. Os pais (area, talhao,
--   operacao, aplicador) tambem sao criados aqui dentro, entao o
--   teste nao depende dos seeds e nada fica no banco.
-- PARTE 2: comentada. Sao as tentativas que DEVEM FALHAR. Rode
--   cada comando sozinho (selecione a linha e Ctrl+Enter).
--
-- Workbench: todo UPDATE e DELETE usa WHERE com a chave primaria
-- por causa do safe update mode (Error 1175).
--
-- ATENCAO: o ROLLBACK desfaz as LINHAS, mas o contador de ids
-- (AUTO_INCREMENT) das tabelas usadas NAO volta. O teste usa os ids
-- 9001 e 9002, entao o proximo cadastro normal nessas tabelas sai com
-- id perto de 9002. Os dados nao sao afetados. Se isso incomodar,
-- rode o teste num banco de testes e nao no banco oficial.
-- ============================================================

USE caderno_fazenda;

-- ============================================================
-- PARTE 1: prova dos 12 triggers (termina em ROLLBACK)
-- ============================================================

-- Quem esta conectado (e o que o trigger vai gravar na coluna usuario)
SELECT USER() AS conectado_como;

-- Marca onde o historico estava antes do teste
SET @h0 = (SELECT COALESCE(MAX(id_historico), 0) FROM historico_alteracoes);

START TRANSACTION;

-- ---- insumo: INSERT, UPDATE ----
INSERT INTO insumo (id_insumo, nome, marca, tipo)
VALUES (9001, 'TESTE_AUDITORIA', 'Marca Teste', 'Teste');

UPDATE insumo SET marca = 'Marca Alterada' WHERE id_insumo = 9001;

-- ---- pais necessarios (tabelas nao auditadas) ----
INSERT INTO area (id_area, nome) VALUES (9001, 'TESTE_AREA');
INSERT INTO talhao (id_talhao, id_area, nome, hectares) VALUES (9001, 9001, 'TESTE_TALHAO_1', 1.00);
INSERT INTO talhao (id_talhao, id_area, nome, hectares) VALUES (9002, 9001, 'TESTE_TALHAO_2', 1.00);
INSERT INTO operacao (id_operacao, nome) VALUES (9001, 'TESTE_OPERACAO');
INSERT INTO aplicador (id_aplicador, modelo, tipo) VALUES (9001, 'TESTE_APLICADOR', 'drone');

-- ---- aplicacao, aplicacao_talhao, aplicacao_insumo: INSERT ----
INSERT INTO aplicacao (id_aplicacao, id_operacao, id_aplicador, data_aplicacao)
VALUES (9001, 9001, 9001, CURDATE());

INSERT INTO aplicacao_talhao (id_aplicacao, id_talhao) VALUES (9001, 9001);

INSERT INTO aplicacao_insumo (id_aplicacao, id_insumo, dose_prevista, dose_realizada, unidade_dose)
VALUES (9001, 9001, 1.000, NULL, 'L/ha');

-- ---- UPDATE ----
UPDATE aplicacao SET observacao = 'teste de auditoria' WHERE id_aplicacao = 9001;

UPDATE aplicacao_talhao SET id_talhao = 9002
 WHERE id_aplicacao = 9001 AND id_talhao = 9001;

UPDATE aplicacao_insumo SET dose_realizada = 0.950
 WHERE id_aplicacao = 9001 AND id_insumo = 9001;

-- ---- DELETE (filhos antes dos pais, por causa do RESTRICT) ----
DELETE FROM aplicacao_insumo WHERE id_aplicacao = 9001 AND id_insumo = 9001;
DELETE FROM aplicacao_talhao WHERE id_aplicacao = 9001 AND id_talhao = 9002;
DELETE FROM aplicacao WHERE id_aplicacao = 9001;
DELETE FROM insumo WHERE id_insumo = 9001;

-- ---- RESULTADO 1: as linhas geradas, uma a uma ----
SELECT id_historico, tabela_afetada, chave_registro, acao, usuario, data_hora,
       dados_anteriores, dados_novos
  FROM historico_alteracoes
 WHERE id_historico > @h0
 ORDER BY id_historico;

-- ---- RESULTADO 2: resumo. Esperado: 12 linhas, 1 por tabela e acao ----
SELECT tabela_afetada, acao, COUNT(*) AS linhas, MIN(usuario) AS usuario
  FROM historico_alteracoes
 WHERE id_historico > @h0
 GROUP BY tabela_afetada, acao
 ORDER BY tabela_afetada, FIELD(acao, 'INSERT', 'UPDATE', 'DELETE');

ROLLBACK;

-- ---- RESULTADO 3: depois do ROLLBACK nao sobrou nada. Esperado: 0 ----
SELECT COUNT(*) AS linhas_que_sobraram
  FROM historico_alteracoes
 WHERE id_historico > @h0;


-- ============================================================
-- PARTE 2: tentativas que DEVEM FALHAR (imutabilidade)
-- Tire o "-- " de cada linha e rode UM comando de cada vez, na
-- ordem, na mesma aba do Workbench. Os passos 2.2 e 2.3 devem dar:
--   Error 1644: historico_alteracoes é imutável: ...
-- Anexe o print dos dois erros ao PR.
-- ============================================================

-- 2.1 Prepara: abre transacao e cria uma linha de historico
-- START TRANSACTION;
-- INSERT INTO insumo (id_insumo, nome, marca, tipo) VALUES (9002, 'TESTE_IMUTAVEL', 'x', 'x');
-- SET @id_h = (SELECT MAX(id_historico) FROM historico_alteracoes);
-- SELECT * FROM historico_alteracoes WHERE id_historico = @id_h;

-- 2.2 UPDATE direto no historico (DEVE FALHAR)
-- UPDATE historico_alteracoes SET usuario = 'fraude' WHERE id_historico = @id_h;

-- 2.3 DELETE direto no historico (DEVE FALHAR)
-- DELETE FROM historico_alteracoes WHERE id_historico = @id_h;

-- 2.4 Desfaz tudo
-- ROLLBACK;
