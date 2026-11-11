-- =====================================================================
-- Caderno de Campo - DESFAZER os dados ficticios (so os ficticios!)
-- =====================================================================
-- Apaga: as aplicacoes ficticias e os 10 exemplos [DEMO #nn] (com talhoes e insumos), as
-- compras ficticias (com itens), os 5 aplicadores e os 2 insumos ficticios, e volta ao tipo
-- 'Insumo' os 7 produtos de tipo deduzido. NAO mexe nos dados reais (talhoes dos mapas,
-- descricao das areas e tipo dos 12 produtos da auditoria ficam).
-- Quem e ficticio esta na tabela registro_dados_ficticios (ids). Se o banco ainda estiver
-- com as etiquetas da versao ANTERIOR do povoamento, elas tambem sao reconhecidas.
-- Se alguma aplicacao REAL usar um dos aplicadores/insumos ficticios, o MySQL recusa
-- (chave estrangeira) e nada e apagado: rode ROLLBACK; e fale com o grupo.
-- A tabela historico_alteracoes nao deixa apagar: o rastro continua la (e proposital).
-- O numero (id) das linhas apagadas NAO volta sozinho: depois de desfazer, o proximo cadastro recebe
-- o proximo numero da fila (os contadores nao andam para tras). Para o proximo id voltar a ser
-- (maior id + 1), rode o corrigir_ids.sql (usuario do Diogo, precisa de ALTER).
-- =====================================================================
USE caderno_fazenda;
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET SQL_SAFE_UPDATES = 0;

-- Tabela de controle (se o banco nunca recebeu a versao nova do povoamento, ela ainda nao existe):
-- colunas: tabela = insumo, aplicador, compra ou aplicacao | id_registro = id nessa tabela |
--         ref = so para aplicacao: numero de ordem 1..70 da carga
SET @sql := IF((SELECT COUNT(*) FROM information_schema.tables
                WHERE table_schema = DATABASE() AND table_name = 'registro_dados_ficticios') = 0,
  'CREATE TABLE registro_dados_ficticios (id INT NOT NULL AUTO_INCREMENT, tabela VARCHAR(30) NOT NULL, id_registro INT NOT NULL, ref INT NULL, PRIMARY KEY (id), UNIQUE KEY uq_registro_dados_ficticios (tabela, id_registro), KEY ix_registro_dados_ficticios_ref (tabela, ref)) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci',
  'DO 0');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

START TRANSACTION;

-- 1. aplicacoes ficticias e exemplos [DEMO #nn] (primeiro talhoes e insumos, depois a aplicacao)
DELETE aiu FROM aplicacao_insumo aiu JOIN aplicacao a ON a.id_aplicacao = aiu.id_aplicacao
 WHERE a.id_aplicacao IN (SELECT id_registro FROM registro_dados_ficticios WHERE tabela = 'aplicacao')
    OR a.observacao LIKE '[DEMO #%' OR a.observacao LIKE '[SIMULADO #%';
DELETE apt FROM aplicacao_talhao apt JOIN aplicacao a ON a.id_aplicacao = apt.id_aplicacao
 WHERE a.id_aplicacao IN (SELECT id_registro FROM registro_dados_ficticios WHERE tabela = 'aplicacao')
    OR a.observacao LIKE '[DEMO #%' OR a.observacao LIKE '[SIMULADO #%';
DELETE FROM aplicacao
 WHERE id_aplicacao IN (SELECT id_registro FROM registro_dados_ficticios WHERE tabela = 'aplicacao')
    OR observacao LIKE '[DEMO #%' OR observacao LIKE '[SIMULADO #%';

-- 2. compras ficticias (itens primeiro)
DELETE ic FROM item_compra ic JOIN compra c ON c.id_compra = ic.id_compra
 WHERE c.id_compra IN (SELECT id_registro FROM registro_dados_ficticios WHERE tabela = 'compra') OR c.numero_nota LIKE 'SIM-%';
DELETE FROM compra WHERE id_compra IN (SELECT id_registro FROM registro_dados_ficticios WHERE tabela = 'compra') OR numero_nota LIKE 'SIM-%';

-- 3. aplicadores e insumos ficticios; tipo dos 7 produtos deduzidos volta a 'Insumo'
DELETE FROM aplicador WHERE id_aplicador IN (SELECT id_registro FROM registro_dados_ficticios WHERE tabela = 'aplicador') OR modelo IN ('DJI Agras T40 (serie 3WHDX00C)', 'Massey Ferguson 275 n.01 (placa QDE4F82)', 'Valtra A750 n.02 (placa PXK7H19)', 'New Holland TL75E n.03 (placa MJB3C56)', 'Massey Ferguson 4275 n.04 (placa RTA9K07)');
DELETE FROM insumo WHERE id_insumo IN (SELECT id_registro FROM registro_dados_ficticios WHERE tabela = 'insumo') OR marca = 'SIMULADO';
UPDATE insumo SET tipo = 'Insumo' WHERE nome IN ('Curbix SC200', 'Glufosinate Ammonium 200 G/L SL', 'YaraLiva Nitrabo', 'Boro Super', 'Maxi Zinc', 'Ferriflo NG', 'Blend Mg-Zn-B');

-- 4. limpa a tabela de controle
DELETE FROM registro_dados_ficticios;

COMMIT;

-- Conferencia (tudo 0):
SELECT (SELECT COUNT(*) FROM aplicacao WHERE observacao LIKE '[DEMO #%' OR observacao LIKE '[SIMULADO #%') AS exemplos_que_sobraram,
       (SELECT COUNT(*) FROM aplicador WHERE modelo IN ('DJI Agras T40 (serie 3WHDX00C)', 'Massey Ferguson 275 n.01 (placa QDE4F82)', 'Valtra A750 n.02 (placa PXK7H19)', 'New Holland TL75E n.03 (placa MJB3C56)', 'Massey Ferguson 4275 n.04 (placa RTA9K07)')) AS aplicadores_ficticios,
       (SELECT COUNT(*) FROM compra WHERE numero_nota LIKE 'SIM-%') AS compras_com_etiqueta_antiga,
       (SELECT COUNT(*) FROM insumo WHERE marca = 'SIMULADO') AS insumos_com_etiqueta_antiga,
       (SELECT COUNT(*) FROM registro_dados_ficticios) AS registros_no_controle;

-- OPCIONAL - apagar tambem a tabela de controle (so depois do desfazer; ela fica vazia):
--   DROP TABLE registro_dados_ficticios;
-- OPCIONAL - voltar tambem os dados REAIS carregados (so se nenhuma aplicacao usar os talhoes):
--   DELETE t FROM talhao t JOIN area a ON a.id_area = t.id_area WHERE a.nome IN ('Bela Vista', 'Corujas', 'Serra II');
-- (insumos ficticios, para referencia: 'NPK 20-05-20', 'Calcario dolomitico')
