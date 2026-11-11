-- =====================================================================
-- Caderno de Campo - apagar SO os 10 exemplos [DEMO #nn]
-- =====================================================================
-- (Este arquivo nao precisa da tabela de controle: acha os exemplos pela etiqueta [DEMO #nn]
--  que voce digita na observacao.)
-- Use depois de ensaiar (ou entre um ensaio e outro): apaga so as aplicacoes cuja
-- observacao comeca com [DEMO #...] (com seus talhoes e insumos) e deixa o historico
-- de aplicacoes e todo o resto como esta. Pode rodar de novo sem medo.
-- Para apagar TAMBEM os dados ficticios: desfazer_dados_ficticios.sql.
-- Obs.: as exclusoes tambem ficam registradas em historico_alteracoes (nao deixa apagar).
-- Obs.: o numero (id) de uma aplicacao apagada NAO volta sozinho: o proximo cadastro recebe o proximo
--       numero da fila, nao o do buraco. Para o proximo id voltar a ser (maior id + 1), rode o
--       corrigir_ids.sql (usuario do Diogo) depois de apagar e antes de cadastrar de novo.
-- =====================================================================
USE caderno_fazenda;
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET SQL_SAFE_UPDATES = 0;

START TRANSACTION;
DELETE aiu FROM aplicacao_insumo aiu JOIN aplicacao a ON a.id_aplicacao = aiu.id_aplicacao
 WHERE a.observacao LIKE '[DEMO #%';
DELETE apt FROM aplicacao_talhao apt JOIN aplicacao a ON a.id_aplicacao = apt.id_aplicacao
 WHERE a.observacao LIKE '[DEMO #%';
DELETE FROM aplicacao WHERE observacao LIKE '[DEMO #%';
COMMIT;

-- Conferencia: o primeiro numero tem de ser 0; o segundo e o total de aplicacoes que
-- continuam no banco (o historico do povoamento: 70, se mais ninguem registrou nada).
SELECT (SELECT COUNT(*) FROM aplicacao WHERE observacao LIKE '[DEMO #%') AS exemplos_que_sobraram,
       (SELECT COUNT(*) FROM aplicacao) AS aplicacoes_que_continuam;
