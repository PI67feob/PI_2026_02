-- ============================================================
-- testes/conferencia.sql
-- Consultas de conferencia para mostrar na apresentacao.
-- So le dados (SELECT). Nao altera nada.
-- Rode DEPOIS do tudo_em_um.sql (ou de criar_banco, 01, 02, 03, triggers).
-- Use COUNT(1) e nao COUNT(*): o asterisco some ao copiar de chat (erro 1064).
-- Tire um print de cada resultado.
-- ============================================================
USE caderno_fazenda;

-- 1. Versao. Precisa ser 8.0.16 ou maior. Se aparecer "MariaDB", NAO vale para a entrega.
SELECT VERSION() AS versao;

-- 2. Linhas por tabela. A coluna "situacao" tem de dar OK em todas.
--    Observacao: aplicacao = 6 so se o 04 foi rodado; historico = 6 so se o 04
--    rodou DEPOIS dos triggers.
SELECT t.tabela, t.linhas, t.esperado,
       IF(t.linhas = t.esperado, 'OK', 'DIFERENTE') AS situacao
  FROM (
        SELECT 'area' AS tabela, COUNT(1) AS linhas, 4 AS esperado FROM area
        UNION ALL SELECT 'talhao', COUNT(1), 5 FROM talhao
        UNION ALL SELECT 'operacao', COUNT(1), 2 FROM operacao
        UNION ALL SELECT 'aplicador', COUNT(1), 11 FROM aplicador
        UNION ALL SELECT 'insumo', COUNT(1), 43 FROM insumo
        UNION ALL SELECT 'compra', COUNT(1), 18 FROM compra
        UNION ALL SELECT 'item_compra', COUNT(1), 43 FROM item_compra
        UNION ALL SELECT 'aplicacao', COUNT(1), 0 FROM aplicacao
        UNION ALL SELECT 'aplicacao_talhao', COUNT(1), 0 FROM aplicacao_talhao
        UNION ALL SELECT 'aplicacao_insumo', COUNT(1), 0 FROM aplicacao_insumo
        UNION ALL SELECT 'historico_alteracoes', COUNT(1), 0 FROM historico_alteracoes
       ) t;

-- 3. Os 5 talhoes e a soma de hectares. Esperado: 19,95
SELECT a.nome AS area, t.nome AS talhao, t.hectares
  FROM talhao t
  JOIN area a ON a.id_area = t.id_area
 ORDER BY t.id_talhao;

SELECT SUM(hectares) AS total_hectares, 19.95 AS esperado,
       IF(SUM(hectares) = 19.95, 'OK', 'DIFERENTE') AS situacao
  FROM talhao;

-- 4. Totais em litros de 7 notas fiscais (valores do indice, informados pelo Bruno)
SELECT e.nota, e.litros_esperados,
       COALESCE(SUM(i.quantidade), 0) AS litros_obtidos,
       IF(COALESCE(SUM(i.quantidade), 0) = e.litros_esperados, 'OK', 'DIFERENTE') AS situacao
  FROM (
        SELECT '3257' AS nota, 740 AS litros_esperados
        UNION ALL SELECT '6060', 183
        UNION ALL SELECT '6671', 195
        UNION ALL SELECT '6749', 206
        UNION ALL SELECT '6855', 184
        UNION ALL SELECT '6916', 61
        UNION ALL SELECT '7292', 23
       ) e
  LEFT JOIN compra c ON c.numero_nota = e.nota
  LEFT JOIN item_compra i ON i.id_compra = c.id_compra AND i.unidade_medida = 'litro'
 GROUP BY e.nota, e.litros_esperados
 ORDER BY e.nota;

-- 5. Itens de compra por unidade. Esperado: litro 40, kg 2, grama 1
SELECT unidade_medida, COUNT(1) AS itens
  FROM item_compra
 GROUP BY unidade_medida
 ORDER BY itens DESC;

-- 6. Periodo das compras e quantos insumos diferentes foram comprados. Esperado: 2025-04-25 a 2026-07-30; 23 insumos
SELECT MIN(data_compra) AS primeira_compra, MAX(data_compra) AS ultima_compra,
       (SELECT COUNT(DISTINCT id_insumo) FROM item_compra) AS insumos_comprados
  FROM compra;

-- 7. Triggers criados. Esperado: 14
SELECT COUNT(1) AS triggers, 14 AS esperado
  FROM information_schema.triggers
 WHERE trigger_schema = 'caderno_fazenda';

SELECT event_object_table AS tabela, trigger_name, action_timing AS quando, event_manipulation AS evento
  FROM information_schema.triggers
 WHERE trigger_schema = 'caderno_fazenda'
 ORDER BY event_object_table, trigger_name;

-- 8. Regra de DELETE de cada chave estrangeira (para a decisao CASCADE x RESTRICT)
SELECT table_name AS tabela, constraint_name AS chave, referenced_table_name AS tabela_pai, delete_rule
  FROM information_schema.referential_constraints
 WHERE constraint_schema = 'caderno_fazenda'
 ORDER BY table_name, constraint_name;
