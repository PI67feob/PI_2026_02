-- =====================================================================
-- Caderno de Campo - corrigir a numeracao (ids) das aplicacoes
-- =====================================================================
-- O QUE APARECEU: as aplicacoes comecavam no id 3 (e nao no 1) e a aplicacao nova,
--   cadastrada pelo terminal, recebeu um id muito maior (136), pulando dezenas de numeros.
--
-- CAUSA: cada tabela tem um contador (AUTO_INCREMENT) que o MySQL usa para dar o proximo id.
--   O programa nao inventa o numero: ele grava a aplicacao e mostra o que o MySQL devolve
--   (ajuda_mysql.dart, funcao inserirLinha). O contador so anda para a frente:
--   - id de linha apagada ou de insert desfeito nao volta (foi o que fez comecar no 3);
--   - quando o MySQL grava muitas linhas de uma vez (INSERT ... SELECT, que o povoamento usa
--     nas 70 aplicacoes) ele reserva os ids em blocos de 1, 2, 4, 8... e perde o que sobra do
--     ultimo bloco. Foram 127 ids reservados para 70 linhas: o contador foi de 3 para 130.
--
-- O QUE ESTE SCRIPT FAZ (pode rodar de novo sem medo: se ja estiver tudo certo, nao muda nada):
--   1. mostra o estado de cada tabela (so leitura);
--   2. verifica, ANTES de gravar qualquer coisa, se pode seguir: nenhuma outra tabela ligada a
--      aplicacao, nenhuma linha de talhao/insumo solta e permissao de ALTER (veja "PARE" abaixo);
--   3. renumera as aplicacoes para 1, 2, 3... NA MESMA ORDEM de hoje, acertando junto as linhas
--      de talhao e de insumo de cada uma e a tabela de controle dos dados ficticios, e confere tudo
--      ainda DENTRO da transacao (quantidades, ids sem buraco, nenhuma linha solta e o conteudo de
--      cada aplicacao igual ao de antes). Tudo certo = COMMIT; qualquer diferenca = ROLLBACK sozinho;
--   4. acerta o contador de cada tabela para (maior id + 1): a proxima aplicacao nova passa a
--      ser a seguinte da fila, sem pulo;
--   5. mostra o estado final.
--
-- COMO RODAR (MySQL Workbench), de preferencia sem ninguem usando o programa ao mesmo tempo:
--   1. Conecte com o usuario do Diogo (DBA). O passo 4 usa ALTER TABLE, que o usuario comum
--      pode nao ter. O script testa isso antes de gravar qualquer coisa: se o MySQL responder
--      "ALTER command denied", ele para ali, sem ter mudado nada, e basta rodar de novo com o
--      usuario do Diogo.
--   2. Abra este arquivo (File > Open SQL Script) e clique no raio (Execute All).
--   3. Olhe as abas, de cima para baixo:
--      a) ANTES: cada tabela com menor id, maior id, linhas e o proximo id que o MySQL vai dar;
--      b) CONFERENCIA: todas as linhas OK (senao o script ja desfez tudo sozinho);
--      c) resultado: NUMERACAO CORRIGIDA;
--      d) DEPOIS: todas as linhas OK, e o proximo id de aplicacao = maior id + 1.
--   Se o script parar com o erro 1064 "...near 'PARE: ...'", e DE PROPOSITO: a verificacao do passo 2
--   achou algo fora do esperado (diz o que) e nada foi gravado. Mande a mensagem para mim.
--   Se aparecer outro erro no meio: rode  ROLLBACK;  e depois  SET FOREIGN_KEY_CHECKS = 1;  e me
--   mande a mensagem (ou rode o arquivo de novo: o comeco dele ja desfaz o que ficou aberto).
--   Nada fica pela metade: a renumeracao e uma transacao so.
--
-- O QUE MUDA E O QUE NAO MUDA:
--   - mudam so os numeros (ids) das aplicacoes; data, operacao, aplicador, talhoes, insumos e
--     doses de cada aplicacao ficam iguais (a conferencia prova isso);
--   - o historico_alteracoes registra cada troca (UPDATE: id antigo e id novo). Sao centenas de
--     linhas, e isso e o esperado: o historico nao pode ser alterado nem apagado;
--   - linhas da tabela de controle dos dados ficticios que apontam para registro que ja foi
--     apagado sao removidas (se ficassem, o id reaproveitado depois seria tratado como ficticio);
--   - permissoes: UPDATE e DELETE nas tabelas citadas e ALTER nas 8 tabelas com id automatico.
--
-- Requer MySQL 8.0 ou mais novo (usa ROW_NUMBER()).
-- =====================================================================

ROLLBACK;                                        -- (descarta o que uma execucao anterior, parada no meio, possa ter deixado aberto)
USE caderno_fazenda;
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET SESSION transaction_read_only = 0;            -- (volta ao normal, caso uma parada anterior tenha deixado ligado)
SET SESSION foreign_key_checks = 1;               -- (idem: se uma execucao anterior parou no meio da troca)
SET SESSION information_schema_stats_expiry = 0;  -- o "proximo id" aparece ao vivo, sem cache
SET SESSION sql_safe_updates = 0;                 -- o modo seguro do Workbench barra UPDATE de varias linhas

-- ---------------------------------------------------------------------
-- 1. ANTES (so leitura)
-- ---------------------------------------------------------------------
SELECT t.tabela, t.menor_id, t.maior_id, t.linhas, t.proximo_id,
       IF(t.proximo_id = IFNULL(t.maior_id, 0) + 1,
          IF(t.tabela = 'aplicacao' AND t.linhas > 0 AND (t.menor_id <> 1 OR t.maior_id <> t.linhas), 'RENUMERAR', 'OK'),
          IF(t.tabela = 'aplicacao' AND t.linhas > 0 AND (t.menor_id <> 1 OR t.maior_id <> t.linhas), 'RENUMERAR E ACERTAR O CONTADOR', 'ACERTAR O CONTADOR')) AS situacao
FROM (
SELECT 'aplicacao' AS tabela, MIN(id_aplicacao) AS menor_id, MAX(id_aplicacao) AS maior_id, COUNT(*) AS linhas,
       (SELECT AUTO_INCREMENT FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'aplicacao') AS proximo_id FROM aplicacao
UNION ALL SELECT 'aplicador', MIN(id_aplicador), MAX(id_aplicador), COUNT(*),
       (SELECT AUTO_INCREMENT FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'aplicador') FROM aplicador
UNION ALL SELECT 'area', MIN(id_area), MAX(id_area), COUNT(*),
       (SELECT AUTO_INCREMENT FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'area') FROM area
UNION ALL SELECT 'compra', MIN(id_compra), MAX(id_compra), COUNT(*),
       (SELECT AUTO_INCREMENT FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'compra') FROM compra
UNION ALL SELECT 'insumo', MIN(id_insumo), MAX(id_insumo), COUNT(*),
       (SELECT AUTO_INCREMENT FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'insumo') FROM insumo
UNION ALL SELECT 'item_compra', MIN(id_item_compra), MAX(id_item_compra), COUNT(*),
       (SELECT AUTO_INCREMENT FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'item_compra') FROM item_compra
UNION ALL SELECT 'operacao', MIN(id_operacao), MAX(id_operacao), COUNT(*),
       (SELECT AUTO_INCREMENT FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'operacao') FROM operacao
UNION ALL SELECT 'talhao', MIN(id_talhao), MAX(id_talhao), COUNT(*),
       (SELECT AUTO_INCREMENT FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'talhao') FROM talhao
) t;

-- ---------------------------------------------------------------------
-- 2. Verificacao previa: o script so mexe em aplicacao e nas duas tabelas ligadas a ela.
--    Se houver outra tabela ligada, ou linha de talhao/insumo sem aplicacao, ele PARA antes de gravar.
-- ---------------------------------------------------------------------
SET @fk_outras := (SELECT COUNT(*) FROM information_schema.key_column_usage
                   WHERE table_schema = DATABASE() AND referenced_table_name = 'aplicacao'
                     AND table_name NOT IN ('aplicacao_talhao', 'aplicacao_insumo'));
SET @orfaos_ini := (SELECT COUNT(*) FROM aplicacao_talhao t LEFT JOIN aplicacao a ON a.id_aplicacao = t.id_aplicacao WHERE a.id_aplicacao IS NULL)
                 + (SELECT COUNT(*) FROM aplicacao_insumo i LEFT JOIN aplicacao a ON a.id_aplicacao = i.id_aplicacao WHERE a.id_aplicacao IS NULL);
SET @problemas := @fk_outras + @orfaos_ini;
-- Se algo estiver fora do esperado: liga o modo so-leitura da sessao (nada e gravado nem que o
-- Workbench continue depois do erro) e da o erro 'PARE', que termina o script aqui.
SET @sql := IF(@problemas = 0, 'DO 0', 'SET SESSION transaction_read_only = 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @sql := IF(@problemas = 0, 'DO 0', CONCAT('PARE: ', CONCAT_WS(', ',
  IF(@fk_outras > 0, CONCAT(@fk_outras, ' tabela(s) ligada(s) a aplicacao alem de talhao e insumo'), NULL),
  IF(@orfaos_ini > 0, CONCAT(@orfaos_ini, ' linha(s) de talhao/insumo sem aplicacao'), NULL))));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------------------
-- 2b. Teste de permissao ANTES de gravar qualquer coisa. O passo 4 precisa de ALTER TABLE; se o
--     seu usuario nao tiver, o MySQL responde "ALTER command denied" aqui e o script PARA sem
--     ter mudado nada (nesse caso rode com o usuario do Diogo). Este comando e inofensivo: ele
--     nunca baixa o contador abaixo de (maior id + 1), so tira o excesso.
-- ---------------------------------------------------------------------
ALTER TABLE aplicacao AUTO_INCREMENT = 1;

-- ---------------------------------------------------------------------
-- 3. Renumerar as aplicacoes (uma transacao so)
-- ---------------------------------------------------------------------
-- A chave estrangeira de talhao/insumo para aplicacao nao tem ON UPDATE CASCADE, entao ela e
-- desligada SO NESTA SESSAO durante a troca e religada logo depois da conferencia.
SET FOREIGN_KEY_CHECKS = 0;
START TRANSACTION;

SET @tem_controle := (SELECT COUNT(*) FROM information_schema.tables
                      WHERE table_schema = DATABASE() AND table_name = 'registro_dados_ficticios');

-- 3a. Foto do que existe hoje: quantidades e uma soma de controle do conteudo de cada aplicacao
--     (o numero de ordem entra na conta, entao a ordem tambem e conferida).
SELECT (SELECT COUNT(*) FROM aplicacao), (SELECT COUNT(*) FROM aplicacao_talhao), (SELECT COUNT(*) FROM aplicacao_insumo)
  INTO @n_ap, @n_at, @n_ai;
SELECT
  (SELECT IFNULL(SUM(CRC32(CONCAT_WS('|', (SELECT COUNT(*) FROM aplicacao b WHERE b.id_aplicacao <= a.id_aplicacao),
        a.id_operacao, a.id_aplicador, a.data_aplicacao, IFNULL(a.observacao, '~'), IFNULL(a.horas_ate_chuva, '~'), IFNULL(a.motivo_reaplicacao, '~')))), 0)
   FROM aplicacao a),
  (SELECT IFNULL(SUM(CRC32(CONCAT_WS('|', (SELECT COUNT(*) FROM aplicacao b WHERE b.id_aplicacao <= t.id_aplicacao), t.id_talhao))), 0)
   FROM aplicacao_talhao t),
  (SELECT IFNULL(SUM(CRC32(CONCAT_WS('|', (SELECT COUNT(*) FROM aplicacao b WHERE b.id_aplicacao <= i.id_aplicacao),
        i.id_insumo, i.dose_prevista, IFNULL(i.dose_realizada, '~'), i.unidade_dose))), 0)
   FROM aplicacao_insumo i)
  INTO @fp_ap, @fp_at, @fp_ai;

-- 3b. Linhas de controle que apontam para registro que nao existe mais saem agora: depois do
--     passo 4 o MySQL reaproveita esses numeros, e o desfazer_dados_ficticios.sql apagaria a
--     linha nova por engano.
SET @sql := IF(@tem_controle = 0, 'DO 0',
  'DELETE r FROM registro_dados_ficticios r WHERE (r.tabela = ''aplicacao'' AND NOT EXISTS (SELECT 1 FROM aplicacao x WHERE x.id_aplicacao = r.id_registro)) OR (r.tabela = ''insumo'' AND NOT EXISTS (SELECT 1 FROM insumo x WHERE x.id_insumo = r.id_registro)) OR (r.tabela = ''aplicador'' AND NOT EXISTS (SELECT 1 FROM aplicador x WHERE x.id_aplicador = r.id_registro)) OR (r.tabela = ''compra'' AND NOT EXISTS (SELECT 1 FROM compra x WHERE x.id_compra = r.id_registro))');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 3c. Primeiro id fora do lugar (o numero de ordem 1, 2, 3... da aplicacao e diferente do id).
--     Daqui para a frente todas estao fora do lugar. NULL = ja esta tudo certo, nada a trocar.
SET @primeiro_fora := (SELECT MIN(m.antigo)
                       FROM (SELECT id_aplicacao AS antigo, ROW_NUMBER() OVER (ORDER BY id_aplicacao) AS novo FROM aplicacao) m
                       WHERE m.antigo <> m.novo);

-- 3d. Troca dos numeros. Cada UPDATE vai em ordem crescente de id (ORDER BY): o numero novo e sempre
--     menor que o antigo e o lugar dele ja foi liberado, entao nada colide. Filhas primeiro, mae por ultimo.
UPDATE aplicacao_talhao
   SET id_aplicacao = (SELECT m.novo FROM (SELECT id_aplicacao AS antigo, ROW_NUMBER() OVER (ORDER BY id_aplicacao) AS novo FROM aplicacao) m
                       WHERE m.antigo = aplicacao_talhao.id_aplicacao)
 WHERE id_aplicacao >= @primeiro_fora
 ORDER BY id_aplicacao;

UPDATE aplicacao_insumo
   SET id_aplicacao = (SELECT m.novo FROM (SELECT id_aplicacao AS antigo, ROW_NUMBER() OVER (ORDER BY id_aplicacao) AS novo FROM aplicacao) m
                       WHERE m.antigo = aplicacao_insumo.id_aplicacao)
 WHERE id_aplicacao >= @primeiro_fora
 ORDER BY id_aplicacao;

SET @sql := IF(@tem_controle = 0, 'DO 0',
  'UPDATE registro_dados_ficticios SET id_registro = (SELECT m.novo FROM (SELECT id_aplicacao AS antigo, ROW_NUMBER() OVER (ORDER BY id_aplicacao) AS novo FROM aplicacao) m WHERE m.antigo = registro_dados_ficticios.id_registro) WHERE tabela = ''aplicacao'' AND id_registro >= @primeiro_fora ORDER BY id_registro');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

UPDATE aplicacao
   SET id_aplicacao = (SELECT m.novo FROM (SELECT id_aplicacao AS antigo, ROW_NUMBER() OVER (ORDER BY id_aplicacao) AS novo FROM aplicacao) m
                       WHERE m.antigo = aplicacao.id_aplicacao)
 WHERE id_aplicacao >= @primeiro_fora
 ORDER BY id_aplicacao;

-- 3e. Conferencia, ainda dentro da transacao.
SELECT (SELECT COUNT(*) FROM aplicacao), IFNULL((SELECT MIN(id_aplicacao) FROM aplicacao), 0), IFNULL((SELECT MAX(id_aplicacao) FROM aplicacao), 0),
       (SELECT COUNT(*) FROM aplicacao_talhao), (SELECT COUNT(*) FROM aplicacao_insumo),
       (SELECT COUNT(*) FROM aplicacao_talhao t LEFT JOIN aplicacao a ON a.id_aplicacao = t.id_aplicacao WHERE a.id_aplicacao IS NULL)
     + (SELECT COUNT(*) FROM aplicacao_insumo i LEFT JOIN aplicacao a ON a.id_aplicacao = i.id_aplicacao WHERE a.id_aplicacao IS NULL)
  INTO @c_n, @c_min, @c_max, @c_at, @c_ai, @c_orf;
SELECT
  (SELECT IFNULL(SUM(CRC32(CONCAT_WS('|', a.id_aplicacao,
        a.id_operacao, a.id_aplicador, a.data_aplicacao, IFNULL(a.observacao, '~'), IFNULL(a.horas_ate_chuva, '~'), IFNULL(a.motivo_reaplicacao, '~')))), 0)
   FROM aplicacao a),
  (SELECT IFNULL(SUM(CRC32(CONCAT_WS('|', t.id_aplicacao, t.id_talhao))), 0) FROM aplicacao_talhao t),
  (SELECT IFNULL(SUM(CRC32(CONCAT_WS('|', i.id_aplicacao, i.id_insumo, i.dose_prevista, IFNULL(i.dose_realizada, '~'), i.unidade_dose))), 0) FROM aplicacao_insumo i)
  INTO @c_fp_ap, @c_fp_at, @c_fp_ai;

SELECT g.item AS itens, g.esperado, g.encontrado, g.status
FROM (
SELECT 1 AS o, 'aplicacoes (quantidade)' AS item, CAST(@n_ap AS CHAR) AS esperado, CAST(@c_n AS CHAR) AS encontrado, IF(@c_n = @n_ap, 'OK', 'DIFERENTE') AS status
UNION ALL SELECT 2, 'menor id (1, ou 0 se nao ha aplicacao)', CAST(IF(@n_ap = 0, 0, 1) AS CHAR), CAST(@c_min AS CHAR), IF(@c_min = IF(@n_ap = 0, 0, 1), 'OK', 'DIFERENTE')
UNION ALL SELECT 3, 'maior id (= quantidade, sem buraco)', CAST(@n_ap AS CHAR), CAST(@c_max AS CHAR), IF(@c_max = @n_ap, 'OK', 'DIFERENTE')
UNION ALL SELECT 4, 'linhas de talhao (quantidade)', CAST(@n_at AS CHAR), CAST(@c_at AS CHAR), IF(@c_at = @n_at, 'OK', 'DIFERENTE')
UNION ALL SELECT 5, 'linhas de insumo (quantidade)', CAST(@n_ai AS CHAR), CAST(@c_ai AS CHAR), IF(@c_ai = @n_ai, 'OK', 'DIFERENTE')
UNION ALL SELECT 6, 'talhao/insumo sem aplicacao', '0', CAST(@c_orf AS CHAR), IF(@c_orf = 0, 'OK', 'DIFERENTE')
UNION ALL SELECT 7, 'conteudo das aplicacoes igual ao de antes (soma de controle)', CAST(@fp_ap AS CHAR), CAST(@c_fp_ap AS CHAR), IF(@c_fp_ap = @fp_ap, 'OK', 'DIFERENTE')
UNION ALL SELECT 8, 'talhoes de cada aplicacao iguais aos de antes', CAST(@fp_at AS CHAR), CAST(@c_fp_at AS CHAR), IF(@c_fp_at = @fp_at, 'OK', 'DIFERENTE')
UNION ALL SELECT 9, 'insumos e doses de cada aplicacao iguais aos de antes', CAST(@fp_ai AS CHAR), CAST(@c_fp_ai AS CHAR), IF(@c_fp_ai = @fp_ai, 'OK', 'DIFERENTE')
) g ORDER BY g.o;

-- Decide: tudo OK = COMMIT; qualquer DIFERENTE = ROLLBACK (nada fica pela metade).
SET @ok := IF(@c_n = @n_ap AND @c_min = IF(@n_ap = 0, 0, 1) AND @c_max = @n_ap AND @c_at = @n_at AND @c_ai = @n_ai AND @c_orf = 0
              AND @c_fp_ap = @fp_ap AND @c_fp_at = @fp_at AND @c_fp_ai = @fp_ai, 1, 0);
SET @sql := IF(@ok = 1, 'COMMIT', 'ROLLBACK');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET FOREIGN_KEY_CHECKS = 1;
SELECT IF(@ok = 1,
          IF(@primeiro_fora IS NULL, 'NUMERACAO JA ESTAVA CERTA: nenhum id foi trocado.', 'NUMERACAO CORRIGIDA: as aplicacoes agora vao de 1 ate o total, na mesma ordem.'),
          'NUMERACAO NAO CORRIGIDA: ROLLBACK automatico, nada mudou. Veja as linhas DIFERENTE da conferencia e me mande.') AS resultado,
       DATABASE() AS banco, @n_ap AS aplicacoes, @primeiro_fora AS primeiro_id_trocado;

-- ---------------------------------------------------------------------
-- 4. Acertar o contador (proximo id) de cada tabela para (maior id + 1).
--    ALTER TABLE ... AUTO_INCREMENT = 1 nunca baixa o contador abaixo de (maior id + 1): so tira o excesso.
--    Precisa da permissao ALTER (usuario do Diogo).
-- ---------------------------------------------------------------------
ALTER TABLE aplicacao AUTO_INCREMENT = 1;
ALTER TABLE aplicador AUTO_INCREMENT = 1;
ALTER TABLE area AUTO_INCREMENT = 1;
ALTER TABLE compra AUTO_INCREMENT = 1;
ALTER TABLE insumo AUTO_INCREMENT = 1;
ALTER TABLE item_compra AUTO_INCREMENT = 1;
ALTER TABLE operacao AUTO_INCREMENT = 1;
ALTER TABLE talhao AUTO_INCREMENT = 1;

-- ---------------------------------------------------------------------
-- 5. DEPOIS (so leitura): o proximo id de cada tabela tem de ser (maior id + 1) e as aplicacoes, de 1 ate o total.
-- ---------------------------------------------------------------------
SELECT t.tabela, t.menor_id, t.maior_id, t.linhas, t.proximo_id,
       IF(t.proximo_id = IFNULL(t.maior_id, 0) + 1
          AND (t.tabela <> 'aplicacao' OR t.linhas = 0 OR (t.menor_id = 1 AND t.maior_id = t.linhas)), 'OK', 'VERIFICAR') AS status
FROM (
SELECT 'aplicacao' AS tabela, MIN(id_aplicacao) AS menor_id, MAX(id_aplicacao) AS maior_id, COUNT(*) AS linhas,
       (SELECT AUTO_INCREMENT FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'aplicacao') AS proximo_id FROM aplicacao
UNION ALL SELECT 'aplicador', MIN(id_aplicador), MAX(id_aplicador), COUNT(*),
       (SELECT AUTO_INCREMENT FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'aplicador') FROM aplicador
UNION ALL SELECT 'area', MIN(id_area), MAX(id_area), COUNT(*),
       (SELECT AUTO_INCREMENT FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'area') FROM area
UNION ALL SELECT 'compra', MIN(id_compra), MAX(id_compra), COUNT(*),
       (SELECT AUTO_INCREMENT FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'compra') FROM compra
UNION ALL SELECT 'insumo', MIN(id_insumo), MAX(id_insumo), COUNT(*),
       (SELECT AUTO_INCREMENT FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'insumo') FROM insumo
UNION ALL SELECT 'item_compra', MIN(id_item_compra), MAX(id_item_compra), COUNT(*),
       (SELECT AUTO_INCREMENT FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'item_compra') FROM item_compra
UNION ALL SELECT 'operacao', MIN(id_operacao), MAX(id_operacao), COUNT(*),
       (SELECT AUTO_INCREMENT FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'operacao') FROM operacao
UNION ALL SELECT 'talhao', MIN(id_talhao), MAX(id_talhao), COUNT(*),
       (SELECT AUTO_INCREMENT FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'talhao') FROM talhao
) t;
