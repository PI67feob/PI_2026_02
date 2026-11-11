-- =====================================================================
-- Caderno de Campo - povoamento do banco `caderno_fazenda`
-- Dados REAIS da auditoria + dados FICTICIOS para a demonstracao
-- =====================================================================
-- COMO RODAR (MySQL Workbench):
--   1. Conecte no servidor com o SEU usuario e abra este arquivo (File > Open SQL Script).
--   2. Clique no raio (Execute All). Pode rodar de novo sem medo: o script e IDEMPOTENTE
--      (cada insercao so acontece se o registro ainda nao existir).
--   3. Olhe as abas de resultado, de cima para baixo:
--      a) VERIFICACAO PREVIA: tem de terminar em PODE SEGUIR (linhas CRIAR sao normais: o banco ainda nao
--         tinha a base do Diogo e o script cria o que falta). Se alguma linha disser FALTA, o
--         script PARA DE PROPOSITO com o erro 1064 "...near 'PARE: faltam ...'"
--         sem gravar nada (o banco tem algo com outro nome ou faltando). A tabela mostra o que
--         falta e o que o banco tem no lugar: mande essa tabela para mim.
--      b) CONFERENCIA (itens / encontrado / esperado / status): todas as linhas OK.
--      c) resultado: CARGA COMPLETA (e o nome do banco com o total de aplicacoes).
--      d) hectares por area e, por ultimo, NUMEROS PARA DIGITAR NO TERMINAL (10 linhas OK).
--      O script confere o resultado ainda DENTRO da transacao: se alguma linha ficar DIFERENTE,
--      ele faz ROLLBACK sozinho e diz CARGA INCOMPLETA (nada fica pela metade).
--   Se aparecer outro ERRO no meio (por exemplo "command denied"): rode  ROLLBACK;  e me mande a
--   mensagem. Para ver o que o banco tem, rode diagnostico_banco.sql (so leitura).
--   Permissoes: o script usa so SELECT, INSERT e UPDATE (nao usa tabela temporaria). CREATE so e
--   preciso se a tabela de controle ainda nao existir, e ALTER so se faltarem as colunas de
--   reaplicacao. Logo depois da verificacao previa ele testa essas permissoes com comandos que
--   NAO gravam nada (WHERE 1 = 0): se o MySQL responder "command denied" ou "Access denied", o
--   seu usuario nao pode gravar. Rode este arquivo com o usuario do Diogo (DBA).
--
-- COMO O FICTICIO FICA IDENTIFICADO: os registros ficticios NAO levam etiqueta no texto (nome,
--   marca, observacao e numero da nota parecem os de um cadastro normal). Os ids ficam na
--   tabela de controle registro_dados_ficticios, que o programa nao usa. E ela que o
--   desfazer_dados_ficticios.sql e as consultas do BI usam. Banco ja carregado com a versao
--   ANTERIOR deste script (a que gravava etiqueta no texto)? A etapa B0 converte no lugar:
--   mesmos ids, nada duplica.
--
-- O QUE E REAL (vem dos mapas impressos e da planilha de defensivos da auditoria):
--   A0  BASE DO DIOGO (seeds 01, 02 e 03 do 'banco do zero': 4 areas, 5 talhoes da Sede, operacoes, 11 aplicadores,
--       43 insumos, 18 compras reais com 43 itens), SO o que o banco ainda nao tiver. Banco que ja recebeu os
--       seeds dele: 0 linhas. Banco que so tem as tabelas: cria tudo, com os mesmos ids do Diogo.
--   A1  24 talhoes novos (Bela Vista 10, Corujas 9, Serra II 5) com nome e hectares dos mapas
--   A2  descricao das areas Bela Vista, Corujas e Serra II (dizia "talhoes ainda nao cadastrados")
--   A3  tipo de 12 produtos (Herbicida, Fungicida...) conforme a planilha de defensivos autorizados
--
-- O QUE E FICTICIO (registrado na tabela de controle; da para separar e desfazer):
--   B1  2 insumos ficticios (NPK 20-05-20 e Calcario dolomitico), sem marca como os demais
--       + tipo DEDUZIDO pelo nome para 7 produtos que NAO estao na auditoria
--   B2  5 aplicadores: 4 tratores (com placa ficticia) e 1 drone (serie ficticia)
--   B3  10 compras (notas numeradas de 5 algarismos) com preco unitario ficticio
--   B4  70 aplicacoes, 3 delas ainda nao aplicadas, mais as
--       respectivas linhas de talhao e insumo
--
-- O QUE NAO FOI CARREGADO DA AUDITORIA, DE PROPOSITO (ver o LEIA-ME):
--   voos de drone (viram linhas de aplicacao SEM talhao/insumo e o programa nao abre
--   essas linhas), notas fiscais (CNPJ e valores), geolocalizacao, dados de pessoas.
--
-- REGRA DE GERACAO DOS DADOS FICTICIOS (equipe: decisao D4 - dado sintetico declarado):
--   semente fixa; datas de 14/10/2025 a 30/10/2026 (+3 programadas); trator e drone
--   erram menos que bomba costal; mais chuva em dez-mar; doses plausiveis, NAO sao
--   recomendacao agronomica.
--
-- RESULTADO ESPERADO (banco do Diogo + estes dados):
--   (banco que ja tinha a base do Diogo; se estava sem ela, some area +4, talhao +5, operacao +2, aplicador +11,
--    insumo +43, compra +18 e item_compra +43)
--   talhao +24 | aplicador +5 | insumo +2 | compra +10 | item_compra +26
--   aplicacao +70 | aplicacao_talhao +329 | aplicacao_insumo +111
--   registro_dados_ficticios +87 (tabela nova)
--
-- ATENCAO - AUDITORIA: os triggers gravam cada insercao em historico_alteracoes
--   (e essa tabela nao deixa apagar). Espere ~531 linhas novas la, com o SEU usuario
--   (+43 se o banco estava sem a base do Diogo: os insumos dela tambem passam pelos gatilhos;
--   ~72 se for a conversao de um banco da versao anterior).
--   Quem fizer conferencia por contagem de historico vai ver diferenca.
-- =====================================================================

USE caderno_fazenda;
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET SQL_SAFE_UPDATES = 0;

-- ---------------------------------------------------------------------
-- VERIFICACAO PREVIA (so leitura). O povoamento liga os dados novos a coisas que JA existem
-- no banco (areas, talhoes da Sede, aplicadores, insumos). Se algo estiver com outro
-- nome ou faltando, o MySQL nao avisa: o script antigo passava 'verde' sem gravar. Agora a
-- tabela abaixo mostra o que falta (e o que o banco tem no lugar) e o script PARA
-- (erro 'PARE: ...') antes de gravar qualquer coisa.
-- ---------------------------------------------------------------------
SET SESSION transaction_read_only = 0;   -- (volta ao normal, caso uma parada anterior tenha deixado ligado)
SET SESSION group_concat_max_len = 100000;
SELECT COUNT(*), GROUP_CONCAT(CONCAT(r.t, '.', r.c) ORDER BY r.t, r.c SEPARATOR ', ') INTO @fl_col_n, @fl_col_l
FROM (
SELECT 'area' AS t, 'id_area' AS c UNION ALL SELECT 'area', 'nome' UNION ALL SELECT 'area', 'descricao'
UNION ALL SELECT 'talhao', 'id_talhao' UNION ALL SELECT 'talhao', 'id_area' UNION ALL SELECT 'talhao', 'nome' UNION ALL SELECT 'talhao', 'hectares'
UNION ALL SELECT 'insumo', 'id_insumo' UNION ALL SELECT 'insumo', 'nome' UNION ALL SELECT 'insumo', 'marca' UNION ALL SELECT 'insumo', 'tipo'
UNION ALL SELECT 'aplicador', 'id_aplicador' UNION ALL SELECT 'aplicador', 'modelo' UNION ALL SELECT 'aplicador', 'tipo' UNION ALL SELECT 'aplicador', 'capacidade_max_litros' UNION ALL SELECT 'aplicador', 'capacidade_max_kg'
UNION ALL SELECT 'compra', 'id_compra' UNION ALL SELECT 'compra', 'data_compra' UNION ALL SELECT 'compra', 'numero_nota'
UNION ALL SELECT 'item_compra', 'id_compra' UNION ALL SELECT 'item_compra', 'id_insumo' UNION ALL SELECT 'item_compra', 'quantidade' UNION ALL SELECT 'item_compra', 'unidade_medida' UNION ALL SELECT 'item_compra', 'preco_unitario'
UNION ALL SELECT 'operacao', 'id_operacao' UNION ALL SELECT 'operacao', 'nome' UNION ALL SELECT 'operacao', 'descricao'
UNION ALL SELECT 'aplicacao', 'id_aplicacao' UNION ALL SELECT 'aplicacao', 'id_operacao' UNION ALL SELECT 'aplicacao', 'id_aplicador' UNION ALL SELECT 'aplicacao', 'data_aplicacao' UNION ALL SELECT 'aplicacao', 'observacao'
UNION ALL SELECT 'aplicacao_talhao', 'id_aplicacao' UNION ALL SELECT 'aplicacao_talhao', 'id_talhao'
UNION ALL SELECT 'aplicacao_insumo', 'id_aplicacao' UNION ALL SELECT 'aplicacao_insumo', 'id_insumo' UNION ALL SELECT 'aplicacao_insumo', 'dose_prevista' UNION ALL SELECT 'aplicacao_insumo', 'dose_realizada' UNION ALL SELECT 'aplicacao_insumo', 'unidade_dose'
) r
LEFT JOIN information_schema.columns k ON k.table_schema = DATABASE() AND k.table_name = r.t AND k.column_name = r.c
WHERE k.column_name IS NULL;
SELECT COUNT(*), GROUP_CONCAT(r.nome ORDER BY r.nome SEPARATOR ', ') INTO @fl_oper_n, @fl_oper_l
FROM (SELECT 'Adubacao' AS nome UNION ALL SELECT 'Pulverizacao' AS nome) r
LEFT JOIN operacao o ON o.nome = r.nome
WHERE o.id_operacao IS NULL;
SELECT COUNT(*), GROUP_CONCAT(r.nome ORDER BY r.nome SEPARATOR ', ') INTO @fl_area_n, @fl_area_l
FROM (SELECT 'Sede' AS nome UNION ALL SELECT 'Bela Vista' AS nome UNION ALL SELECT 'Corujas' AS nome UNION ALL SELECT 'Serra II' AS nome) r
LEFT JOIN area a ON a.nome = r.nome
WHERE a.id_area IS NULL;
SELECT COUNT(*), GROUP_CONCAT(r.nome ORDER BY r.nome SEPARATOR ', ') INTO @fl_sede_n, @fl_sede_l
FROM (SELECT 'Chico1' AS nome UNION ALL SELECT 'Chico2' AS nome UNION ALL SELECT 'Pinheiro' AS nome UNION ALL SELECT 'Engenho' AS nome UNION ALL SELECT 'Cafe Velho' AS nome) r
LEFT JOIN (SELECT t.nome FROM talhao t JOIN area a ON a.id_area = t.id_area WHERE a.nome = 'Sede') s ON s.nome = r.nome
WHERE s.nome IS NULL;
SELECT COUNT(*), GROUP_CONCAT(r.nome ORDER BY r.nome SEPARATOR ', ') INTO @fl_apl_n, @fl_apl_l
FROM (SELECT 'Bomba costal Jacto 1' AS nome UNION ALL SELECT 'Bomba costal Jacto 2' AS nome UNION ALL SELECT 'Bomba costal Jacto 4' AS nome UNION ALL SELECT 'Bomba costal Jacto 5' AS nome UNION ALL SELECT 'Bomba costal Jacto 6' AS nome UNION ALL SELECT 'Bomba costal Jacto 7' AS nome UNION ALL SELECT 'Bomba costal Jacto 8' AS nome UNION ALL SELECT 'Drone DJI' AS nome) r
LEFT JOIN aplicador x ON x.modelo = r.nome
WHERE x.id_aplicador IS NULL;
SELECT COUNT(*), GROUP_CONCAT(r.nome ORDER BY r.nome SEPARATOR ', ') INTO @fl_ins_n, @fl_ins_l
FROM (SELECT 'Alion SC500' AS nome UNION ALL SELECT 'Blend Mg-Zn-B' AS nome UNION ALL SELECT 'Boro Super' AS nome UNION ALL SELECT 'Curbix SC200' AS nome UNION ALL SELECT 'Ferriflo NG' AS nome UNION ALL SELECT 'Glufosinate Ammonium 200 G/L SL' AS nome UNION ALL SELECT 'Maxi Zinc' AS nome UNION ALL SELECT 'Melyra' AS nome UNION ALL SELECT 'Orkestra SC' AS nome UNION ALL SELECT 'Pledge' AS nome UNION ALL SELECT 'Roundup Original' AS nome UNION ALL SELECT 'Spirit' AS nome UNION ALL SELECT 'Supreme Mineral N1' AS nome UNION ALL SELECT 'Valpura EC' AS nome UNION ALL SELECT 'YaraLiva Nitrabo' AS nome) r
LEFT JOIN insumo x ON x.nome = r.nome
WHERE x.id_insumo IS NULL;
SELECT COUNT(*) INTO @fl_enum FROM (
  SELECT 1 FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'aplicador'
     AND column_name = 'tipo' AND column_type LIKE '%''trator''%' AND column_type LIKE '%''drone''%' AND column_type LIKE '%''bomba costal''%'
  UNION ALL SELECT 1 FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'aplicacao_insumo'
     AND column_name = 'unidade_dose' AND column_type LIKE '%''L/ha''%' AND column_type LIKE '%''kg/ha''%'
  UNION ALL SELECT 1 FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'item_compra'
     AND column_name = 'unidade_medida' AND column_type LIKE '%''litro''%' AND column_type LIKE '%''kg''%'
) e;
SELECT COUNT(*), GROUP_CONCAT(d.repetido SEPARATOR ', ') INTO @fl_dup_n, @fl_dup_l FROM (
  SELECT CONCAT('insumo ', i.nome) AS repetido FROM insumo i WHERE i.nome IN ('Alion SC500', 'Blend Mg-Zn-B', 'Boro Super', 'Curbix SC200', 'Ferriflo NG', 'Glufosinate Ammonium 200 G/L SL', 'Maxi Zinc', 'Melyra', 'Orkestra SC', 'Pledge', 'Roundup Original', 'Spirit', 'Supreme Mineral N1', 'Valpura EC', 'YaraLiva Nitrabo', 'NPK 20-05-20', 'Calcario dolomitico') GROUP BY i.nome HAVING COUNT(*) > 1
  UNION ALL SELECT CONCAT('aplicador ', x.modelo) FROM aplicador x WHERE x.modelo IN ('Bomba costal Jacto 1', 'Bomba costal Jacto 2', 'Bomba costal Jacto 4', 'Bomba costal Jacto 5', 'Bomba costal Jacto 6', 'Bomba costal Jacto 7', 'Bomba costal Jacto 8', 'Drone DJI', 'DJI Agras T40 (serie 3WHDX00C)', 'Massey Ferguson 275 n.01 (placa QDE4F82)', 'Valtra A750 n.02 (placa PXK7H19)', 'New Holland TL75E n.03 (placa MJB3C56)', 'Massey Ferguson 4275 n.04 (placa RTA9K07)') GROUP BY x.modelo HAVING COUNT(*) > 1
  UNION ALL SELECT CONCAT('area ', a.nome) FROM area a WHERE a.nome IN ('Sede', 'Bela Vista', 'Corujas', 'Serra II') GROUP BY a.nome HAVING COUNT(*) > 1
) d;
-- Base do Diogo: se faltar TODO um grupo (talhoes da Sede, aplicadores, insumos), o banco nunca recebeu os
-- seeds dele e o script cria o grupo (linha CRIAR). Se faltar SO PARTE do grupo, alguem renomeou ou apagou algo:
-- nao da para adivinhar, entao o script PARA (linha FALTA). Areas e operacoes faltantes sao sempre criadas.
SET @bl_apl := IF(@fl_apl_n = 8, 0, @fl_apl_n), @bl_ins := IF(@fl_ins_n = 15, 0, @fl_ins_n),
    @bl_sede := IF(@fl_sede_n = 5 AND (SELECT COUNT(*) FROM talhao t JOIN area a ON a.id_area = t.id_area WHERE a.nome = 'Sede') = 0, 0, @fl_sede_n);
SET @falta := @fl_col_n + @bl_sede + @bl_apl + @bl_ins + @fl_dup_n + (3 - @fl_enum);
SELECT item, encontrado, esperado, status, faltando, no_banco FROM (
SELECT 1 AS o, 'ambiente: banco / usuario / MySQL' AS item, CONCAT(IFNULL(DATABASE(), '(nenhum)'), ' / ', CURRENT_USER(), ' / ', VERSION()) AS encontrado, '-' AS esperado, 'INFO' AS status, '' AS faltando, '' AS no_banco
UNION ALL SELECT 2, 'linhas antes do povoamento', CONCAT('area=', (SELECT COUNT(*) FROM area), ' talhao=', (SELECT COUNT(*) FROM talhao), ' insumo=', (SELECT COUNT(*) FROM insumo), ' aplicador=', (SELECT COUNT(*) FROM aplicador), ' aplicacao=', (SELECT COUNT(*) FROM aplicacao), ' compra=', (SELECT COUNT(*) FROM compra)), '-', 'INFO', '', ''
UNION ALL SELECT 3, 'colunas que o script usa (tabelas e colunas)', CONCAT(39 - @fl_col_n), '39', IF(@fl_col_n = 0, 'OK', 'FALTA'), IFNULL(@fl_col_l, ''), IF(@fl_col_n = 0, '', IFNULL((SELECT GROUP_CONCAT(CONCAT(table_name, '.', column_name) ORDER BY table_name, ordinal_position SEPARATOR ', ') FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name IN ('area', 'talhao', 'insumo', 'aplicador', 'compra', 'item_compra', 'operacao', 'aplicacao', 'aplicacao_talhao', 'aplicacao_insumo')), '(vazio)'))
UNION ALL SELECT 4, 'operacoes que ja existem (as que faltarem, o script cria)', CONCAT(2 - @fl_oper_n), '2', IF(@fl_oper_n = 0, 'OK', 'CRIAR'), IFNULL(@fl_oper_l, ''), IF(@fl_oper_n = 0, '', IFNULL((SELECT GROUP_CONCAT(CONCAT(id_operacao, '=', nome) ORDER BY id_operacao SEPARATOR ', ') FROM operacao), '(vazio)'))
UNION ALL SELECT 5, 'areas que ja existem (as que faltarem, o script cria)', CONCAT(4 - @fl_area_n), '4', IF(@fl_area_n = 0, 'OK', 'CRIAR'), IFNULL(@fl_area_l, ''), IF(@fl_area_n = 0, '', IFNULL((SELECT GROUP_CONCAT(CONCAT(id_area, '=', nome) ORDER BY id_area SEPARATOR ', ') FROM area), '(vazio)'))
UNION ALL SELECT 6, 'talhoes da Sede (se faltarem os 5 e a Sede estiver vazia, o script cria)', CONCAT(5 - @fl_sede_n), '5', IF(@fl_sede_n = 0, 'OK', IF(@bl_sede = 0, 'CRIAR', 'FALTA')), IFNULL(@fl_sede_l, ''), IF(@fl_sede_n = 0, '', IFNULL((SELECT GROUP_CONCAT(CONCAT(a.nome, '/', t.nome) ORDER BY t.id_talhao SEPARATOR ', ') FROM talhao t JOIN area a ON a.id_area = t.id_area), '(vazio)'))
UNION ALL SELECT 7, 'aplicadores (drone e bombas costais, se faltarem os 8 o script cria)', CONCAT(8 - @fl_apl_n), '8', IF(@fl_apl_n = 0, 'OK', IF(@bl_apl = 0, 'CRIAR', 'FALTA')), IFNULL(@fl_apl_l, ''), IF(@fl_apl_n = 0, '', IFNULL((SELECT GROUP_CONCAT(CONCAT(id_aplicador, '=', modelo) ORDER BY id_aplicador SEPARATOR ', ') FROM aplicador), '(vazio)'))
UNION ALL SELECT 8, 'insumos reais usados (se faltarem os 15, o script cria)', CONCAT(15 - @fl_ins_n), '15', IF(@fl_ins_n = 0, 'OK', IF(@bl_ins = 0, 'CRIAR', 'FALTA')), IFNULL(@fl_ins_l, ''), IF(@fl_ins_n = 0, '', IFNULL((SELECT GROUP_CONCAT(CONCAT(id_insumo, '=', nome) ORDER BY id_insumo SEPARATOR ', ') FROM insumo), '(vazio)'))
UNION ALL SELECT 9, 'colunas enum compativeis (tipo, unidade_dose, unidade_medida)', CONCAT(@fl_enum), '3', IF(@fl_enum = 3, 'OK', 'FALTA'), '', IF(@fl_enum = 3, '', (SELECT GROUP_CONCAT(CONCAT(table_name, '.', column_name, ' = ', column_type) SEPARATOR ' | ') FROM information_schema.columns WHERE table_schema = DATABASE() AND ((table_name = 'aplicador' AND column_name = 'tipo') OR (table_name = 'aplicacao_insumo' AND column_name = 'unidade_dose') OR (table_name = 'item_compra' AND column_name = 'unidade_medida'))))
UNION ALL SELECT 10, 'nomes repetidos que confundem o script', CONCAT(@fl_dup_n), '0', IF(@fl_dup_n = 0, 'OK', 'FALTA'), IFNULL(@fl_dup_l, ''), ''
UNION ALL SELECT 11, 'RESULTADO DA VERIFICACAO', IF(@falta = 0, 'tudo certo', CONCAT(@falta, ' problema(s)')), '0 problemas', IF(@falta = 0, 'PODE SEGUIR', 'PARE'), IF(@falta = 0, IF(@fl_area_n + @fl_sede_n + @fl_apl_n + @fl_ins_n + @fl_oper_n > 0, 'o script vai criar o que as linhas CRIAR mostram (base do Diogo)', ''), 'veja as linhas FALTA acima'), ''
) v
ORDER BY o;
-- Se faltou algo: (1) liga o modo so-leitura da sessao, para nada ser gravado nem que o
-- Workbench continue depois do erro; (2) da o erro 'PARE' e o script termina aqui.
SET @sql := IF(@falta = 0, 'DO 0', 'SET SESSION transaction_read_only = 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
-- (o texto do erro so mostra QUANTOS faltam de cada coisa; a tabela acima diz quais)
SET @sql := IF(@falta = 0, 'DO 0', CONCAT('PARE: faltam ', CONCAT_WS(', ',
  IF(@fl_col_n > 0, CONCAT('colunas: ', @fl_col_n), NULL),
  IF(@bl_sede > 0, CONCAT('talhoes: ', @bl_sede), NULL), IF(@bl_apl > 0, CONCAT('aplicadores: ', @bl_apl), NULL),
  IF(@bl_ins > 0, CONCAT('insumos: ', @bl_ins), NULL), IF(@fl_dup_n > 0, CONCAT('repetidos: ', @fl_dup_n), NULL),
  IF(@fl_enum < 3, 'tipo/unidade', NULL)), ' (veja a tabela)'));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------------------
-- PASSO 0 - colunas de reaplicacao em `aplicacao` (so cria se faltar).
-- Se o seu usuario nao tiver permissao de ALTER, peca ao Diogo para rodar o
-- alter_aplicacao_reaplicacao.sql dele antes.
-- ---------------------------------------------------------------------
SET @sql := IF((SELECT COUNT(*) FROM information_schema.columns
                WHERE table_schema = DATABASE() AND table_name = 'aplicacao'
                  AND column_name = 'horas_ate_chuva') = 0,
  'ALTER TABLE aplicacao ADD COLUMN horas_ate_chuva DECIMAL(6,2) NULL, ADD CONSTRAINT chk_aplicacao_horas_chuva CHECK (horas_ate_chuva IS NULL OR horas_ate_chuva >= 0)',
  'DO 0');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @sql := IF((SELECT COUNT(*) FROM information_schema.columns
                WHERE table_schema = DATABASE() AND table_name = 'aplicacao'
                  AND column_name = 'motivo_reaplicacao') = 0,
  'ALTER TABLE aplicacao ADD COLUMN motivo_reaplicacao VARCHAR(20) NULL, ADD CONSTRAINT chk_aplicacao_motivo_reaplicacao CHECK (motivo_reaplicacao IS NULL OR motivo_reaplicacao IN (''chuva'', ''sol'', ''vento'', ''outro''))',
  'DO 0');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
-- ---------------------------------------------------------------------
-- PASSO 0b - tabela de controle: guarda os ids dos registros ficticios.
-- (o programa nao usa; so o desfazer e o BI. Sem gatilho, nao enche o historico.)
-- So cria se ainda nao existir (se faltar permissao de CREATE: criar_tabela_controle.sql).
-- ---------------------------------------------------------------------
-- colunas: tabela = insumo, aplicador, compra ou aplicacao | id_registro = id nessa tabela |
--         ref = so para aplicacao: numero de ordem 1..70 da carga
SET @sql := IF((SELECT COUNT(*) FROM information_schema.tables
                WHERE table_schema = DATABASE() AND table_name = 'registro_dados_ficticios') = 0,
  'CREATE TABLE registro_dados_ficticios (id INT NOT NULL AUTO_INCREMENT, tabela VARCHAR(30) NOT NULL, id_registro INT NOT NULL, ref INT NULL, PRIMARY KEY (id), UNIQUE KEY uq_registro_dados_ficticios (tabela, id_registro), KEY ix_registro_dados_ficticios_ref (tabela, ref)) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci',
  'DO 0');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------------------
-- TESTE DE PERMISSOES (nao grava nada: todos os comandos abaixo tem WHERE 1 = 0).
-- Se o seu usuario nao puder gravar numa tabela, o MySQL para aqui com 'command denied'
-- (ou 'Access denied') ANTES de qualquer coisa ser gravada. Nesse caso use o usuario do Diogo.
-- ---------------------------------------------------------------------
INSERT INTO area (id_area) SELECT id_area FROM area WHERE 1 = 0;
INSERT INTO operacao (id_operacao) SELECT id_operacao FROM operacao WHERE 1 = 0;
INSERT INTO talhao (id_talhao) SELECT id_talhao FROM talhao WHERE 1 = 0;
INSERT INTO insumo (id_insumo) SELECT id_insumo FROM insumo WHERE 1 = 0;
INSERT INTO aplicador (id_aplicador) SELECT id_aplicador FROM aplicador WHERE 1 = 0;
INSERT INTO compra (id_compra) SELECT id_compra FROM compra WHERE 1 = 0;
INSERT INTO item_compra (id_compra) SELECT id_compra FROM item_compra WHERE 1 = 0;
INSERT INTO aplicacao (id_aplicacao) SELECT id_aplicacao FROM aplicacao WHERE 1 = 0;
INSERT INTO aplicacao_talhao (id_aplicacao) SELECT id_aplicacao FROM aplicacao_talhao WHERE 1 = 0;
INSERT INTO aplicacao_insumo (id_aplicacao) SELECT id_aplicacao FROM aplicacao_insumo WHERE 1 = 0;
INSERT INTO registro_dados_ficticios (id) SELECT id FROM registro_dados_ficticios WHERE 1 = 0;
UPDATE area SET descricao = descricao WHERE 1 = 0;
UPDATE insumo SET tipo = tipo WHERE 1 = 0;
UPDATE insumo SET nome = nome WHERE 1 = 0;
UPDATE insumo SET marca = marca WHERE 1 = 0;
UPDATE aplicacao SET observacao = observacao WHERE 1 = 0;
UPDATE compra SET numero_nota = numero_nota WHERE 1 = 0;

START TRANSACTION;

-- =====================  PARTE A - DADOS REAIS  =====================

-- =====================  PARTE A0 - BASE DO DIOGO (so o que faltar)  =====================
-- Seeds 01, 02 e 03 do 'banco do zero' do Diogo. Banco que ja recebeu os seeds: tudo abaixo grava 0 linhas.
-- Banco que so tem as tabelas (nunca recebeu os seeds): cria aqui, na mesma ordem e com os mesmos ids do Diogo.
-- Nao altera nem apaga nada que ja existe. O desfazer NAO remove a base (e dado real, nao ficticio).

-- A0.1 Areas: Sede, Bela Vista, Corujas e Serra II
SET @vz := (SELECT COUNT(*) = 0 FROM area);
INSERT INTO area (id_area, nome, descricao)
SELECT IF(@vz = 1, v.ord, NULL), v.nome, v.descricao
FROM (
SELECT 'Sede' AS nome, 'Area de producao de 19,95 ha (estimativa 2026); soma dos 5 talhoes cadastrados' AS descricao, 1 AS ord
UNION ALL SELECT 'Bela Vista', 'Area de producao de 60,00 ha (estimativa 2026); talhoes ainda nao cadastrados', 2
UNION ALL SELECT 'Corujas', 'Area de producao de 31,98 ha (estimativa 2026); talhoes ainda nao cadastrados', 3
UNION ALL SELECT 'Serra II', 'Area de producao de 30,60 ha (estimativa 2026); talhoes ainda nao cadastrados', 4
) v
WHERE NOT EXISTS (SELECT 1 FROM area x WHERE x.nome = v.nome)
ORDER BY v.ord;

-- A0.2 Talhoes da Sede: 5 talhoes, 19,95 ha
SET @vz := (SELECT COUNT(*) = 0 FROM talhao);
INSERT INTO talhao (id_talhao, id_area, nome, hectares)
SELECT IF(@vz = 1, v.ord, NULL), a.id_area, v.nome, v.hectares
FROM (
SELECT 'Chico1' AS nome, 2.80 AS hectares, 1 AS ord
UNION ALL SELECT 'Chico2', 3.80, 2
UNION ALL SELECT 'Pinheiro', 2.05, 3
UNION ALL SELECT 'Engenho', 4.90, 4
UNION ALL SELECT 'Cafe Velho', 6.40, 5
) v
JOIN area a ON a.nome = 'Sede'
WHERE NOT EXISTS (SELECT 1 FROM talhao t WHERE t.id_area = a.id_area AND t.nome = v.nome)
ORDER BY v.ord;

-- A0.3 Operacoes (Adubacao e Pulverizacao). O programa grava a operacao como texto livre, entao o banco pode nao ter alguma
--      delas: cria so o que faltar (maiusculas e acentos nao contam, como no programa).
SET @vz := (SELECT COUNT(*) = 0 FROM operacao);
INSERT INTO operacao (id_operacao, nome, descricao)
SELECT IF(@vz = 1, v.ord, NULL), v.nome, v.descricao
FROM (
SELECT 'Adubacao' AS nome, 'Aplicacao de fertilizante' AS descricao, 1 AS ord
UNION ALL SELECT 'Pulverizacao', 'Aplicacao de defensivo ou foliar em calda', 2
) v
WHERE NOT EXISTS (SELECT 1 FROM operacao o WHERE o.nome = v.nome)
ORDER BY v.ord;

-- A0.4 Aplicadores: 1 drone e 10 bombas costais
SET @vz := (SELECT COUNT(*) = 0 FROM aplicador);
INSERT INTO aplicador (id_aplicador, modelo, tipo, capacidade_max_litros, capacidade_max_kg)
SELECT IF(@vz = 1, v.ord, NULL), v.modelo, v.tipo, v.litros, v.kg
FROM (
SELECT 'Drone DJI' AS modelo, 'drone' AS tipo, 70 AS litros, 70 AS kg, 1 AS ord
UNION ALL SELECT 'Bomba costal Jacto 1', 'bomba costal', 20, 20, 2
UNION ALL SELECT 'Bomba costal Jacto 2', 'bomba costal', 20, 20, 3
UNION ALL SELECT 'Bomba costal Jacto 3', 'bomba costal', 20, 20, 4
UNION ALL SELECT 'Bomba costal Jacto 4', 'bomba costal', 20, 20, 5
UNION ALL SELECT 'Bomba costal Jacto 5', 'bomba costal', 20, 20, 6
UNION ALL SELECT 'Bomba costal Jacto 6', 'bomba costal', 20, 20, 7
UNION ALL SELECT 'Bomba costal Jacto 7', 'bomba costal', 20, 20, 8
UNION ALL SELECT 'Bomba costal Jacto 8', 'bomba costal', 20, 20, 9
UNION ALL SELECT 'Bomba costal Jacto 9', 'bomba costal', 20, 20, 10
UNION ALL SELECT 'Bomba costal Jacto 10', 'bomba costal', 20, 20, 11
) v
WHERE NOT EXISTS (SELECT 1 FROM aplicador x WHERE x.modelo = v.modelo)
ORDER BY v.ord;

-- A0.5 Insumos: 43 (tipo provisorio 'Insumo'; a etapa A3 acerta os da planilha de defensivos)
SET @vz := (SELECT COUNT(*) = 0 FROM insumo);
INSERT INTO insumo (id_insumo, nome, tipo)
SELECT IF(@vz = 1, v.ord, NULL), v.nome, v.tipo
FROM (
SELECT 'BioKiller' AS nome, 'Insumo' AS tipo, 1 AS ord
UNION ALL SELECT 'Ammoles', 'Insumo', 2
UNION ALL SELECT 'Acanne', 'Insumo', 3
UNION ALL SELECT 'Polme', 'Insumo', 4
UNION ALL SELECT 'Alfol Calcio', 'Insumo', 5
UNION ALL SELECT 'Alfol Boro', 'Insumo', 6
UNION ALL SELECT 'Coda Best', 'Insumo', 7
UNION ALL SELECT 'Coda Eros', 'Insumo', 8
UNION ALL SELECT 'Coda Drip', 'Insumo', 9
UNION ALL SELECT 'Coda Harmony', 'Insumo', 10
UNION ALL SELECT 'Coda Spill', 'Insumo', 11
UNION ALL SELECT 'Valuva', 'Insumo', 12
UNION ALL SELECT 'Orkestra SC', 'Insumo', 13
UNION ALL SELECT 'Alion SC500', 'Insumo', 14
UNION ALL SELECT 'Galigan', 'Insumo', 15
UNION ALL SELECT 'Glucare', 'Insumo', 16
UNION ALL SELECT 'Glufosinate Ammonium 200 G/L SL', 'Insumo', 17
UNION ALL SELECT 'Grasidim', 'Insumo', 18
UNION ALL SELECT 'Tremor', 'Insumo', 19
UNION ALL SELECT 'Zartan', 'Insumo', 20
UNION ALL SELECT 'Melyra', 'Insumo', 21
UNION ALL SELECT 'Opera', 'Insumo', 22
UNION ALL SELECT 'Valpura EC', 'Insumo', 23
UNION ALL SELECT 'Curbix SC200', 'Insumo', 24
UNION ALL SELECT 'Fastac', 'Insumo', 25
UNION ALL SELECT 'Nomolt', 'Insumo', 26
UNION ALL SELECT 'Premier Plus SC', 'Insumo', 27
UNION ALL SELECT 'Verango Prime SC500', 'Insumo', 28
UNION ALL SELECT 'Supreme Mineral N1', 'Insumo', 29
UNION ALL SELECT 'Reforce Ultra', 'Insumo', 30
UNION ALL SELECT 'YaraLiva Nitrabo', 'Insumo', 31
UNION ALL SELECT 'Blend Mg-Zn-B', 'Insumo', 32
UNION ALL SELECT 'Transfer UP', 'Insumo', 33
UNION ALL SELECT 'Cal Super', 'Insumo', 34
UNION ALL SELECT 'Boro Super', 'Insumo', 35
UNION ALL SELECT 'Ferriflo NG', 'Insumo', 36
UNION ALL SELECT 'Maxi Zinc', 'Insumo', 37
UNION ALL SELECT 'Pledge', 'Insumo', 38
UNION ALL SELECT 'Poquer', 'Insumo', 39
UNION ALL SELECT 'Roundup Original', 'Insumo', 40
UNION ALL SELECT 'Crop Best', 'Insumo', 41
UNION ALL SELECT 'Crop Exit S', 'Insumo', 42
UNION ALL SELECT 'Spirit', 'Insumo', 43
) v
WHERE NOT EXISTS (SELECT 1 FROM insumo x WHERE x.nome = v.nome)
ORDER BY v.ord;

-- A0.6 Compras reais (18 notas) e seus itens (43): so entram se NENHUMA das 18 notas existir no banco
SET @base_compra := (SELECT COUNT(*) FROM compra WHERE numero_nota IN ('3257', '4591', '5685', '6060', '418604', '419201', '6391', '68606', '424602', '6671', '6749', '6855', '6916', '432029', '388564', '388650', '7236', '7292'));
SET @vz := (SELECT COUNT(*) = 0 FROM compra);
INSERT INTO compra (id_compra, data_compra, numero_nota)
SELECT IF(@vz = 1, v.ord, NULL), v.dt, v.nota
FROM (
SELECT '2025-04-25' AS dt, '3257' AS nota, 1 AS ord
UNION ALL SELECT '2025-10-03', '4591', 2
UNION ALL SELECT '2025-12-02', '5685', 3
UNION ALL SELECT '2026-01-05', '6060', 4
UNION ALL SELECT '2026-01-08', '418604', 5
UNION ALL SELECT '2026-01-14', '419201', 6
UNION ALL SELECT '2026-02-06', '6391', 7
UNION ALL SELECT '2026-02-10', '68606', 8
UNION ALL SELECT '2026-03-16', '424602', 9
UNION ALL SELECT '2026-03-17', '6671', 10
UNION ALL SELECT '2026-03-25', '6749', 11
UNION ALL SELECT '2026-04-08', '6855', 12
UNION ALL SELECT '2026-04-16', '6916', 13
UNION ALL SELECT '2026-06-15', '432029', 14
UNION ALL SELECT '2026-07-17', '388564', 15
UNION ALL SELECT '2026-07-20', '388650', 16
UNION ALL SELECT '2026-07-20', '7236', 17
UNION ALL SELECT '2026-07-30', '7292', 18
) v
WHERE @base_compra = 0 AND NOT EXISTS (SELECT 1 FROM compra x WHERE x.numero_nota = v.nota)
ORDER BY v.ord;

SET @vz := (SELECT COUNT(*) = 0 FROM item_compra);
INSERT INTO item_compra (id_item_compra, id_compra, id_insumo, quantidade, unidade_medida)
SELECT IF(@vz = 1, v.ord, NULL), c.id_compra, i.id_insumo, v.qtd, v.un
FROM (
SELECT '3257' AS nota, 'Alion SC500' AS insumo, 20 AS qtd, 'litro' AS un, 1 AS ord
UNION ALL SELECT '3257', 'Premier Plus SC', 640, 'litro', 2
UNION ALL SELECT '3257', 'Verango Prime SC500', 80, 'litro', 3
UNION ALL SELECT '4591', 'Verango Prime SC500', 60, 'litro', 4
UNION ALL SELECT '5685', 'Blend Mg-Zn-B', 15, 'litro', 5
UNION ALL SELECT '5685', 'Curbix SC200', 240, 'litro', 6
UNION ALL SELECT '6060', 'Glufosinate Ammonium 200 G/L SL', 100, 'litro', 7
UNION ALL SELECT '6060', 'Grasidim', 40, 'litro', 8
UNION ALL SELECT '6060', 'Glucare', 20, 'litro', 9
UNION ALL SELECT '6060', 'Tremor', 3, 'litro', 10
UNION ALL SELECT '6060', 'Supreme Mineral N1', 20, 'litro', 11
UNION ALL SELECT '418604', 'Galigan', 20, 'litro', 12
UNION ALL SELECT '419201', 'Zartan', 200, 'grama', 13
UNION ALL SELECT '6391', 'Curbix SC200', 240, 'litro', 14
UNION ALL SELECT '6391', 'Valpura EC', 145, 'litro', 15
UNION ALL SELECT '68606', 'Melyra', 100, 'litro', 16
UNION ALL SELECT '424602', 'Galigan', 20, 'litro', 17
UNION ALL SELECT '6671', 'Glucare', 120, 'litro', 18
UNION ALL SELECT '6671', 'Grasidim', 20, 'litro', 19
UNION ALL SELECT '6671', 'Tremor', 15, 'litro', 20
UNION ALL SELECT '6671', 'Supreme Mineral N1', 40, 'litro', 21
UNION ALL SELECT '6749', 'Glucare', 100, 'litro', 22
UNION ALL SELECT '6749', 'Grasidim', 40, 'litro', 23
UNION ALL SELECT '6749', 'Tremor', 6, 'litro', 24
UNION ALL SELECT '6749', 'Supreme Mineral N1', 60, 'litro', 25
UNION ALL SELECT '6855', 'Glucare', 100, 'litro', 26
UNION ALL SELECT '6855', 'Grasidim', 40, 'litro', 27
UNION ALL SELECT '6855', 'Tremor', 4, 'litro', 28
UNION ALL SELECT '6855', 'Supreme Mineral N1', 40, 'litro', 29
UNION ALL SELECT '6916', 'Glucare', 20, 'litro', 30
UNION ALL SELECT '6916', 'Grasidim', 20, 'litro', 31
UNION ALL SELECT '6916', 'Tremor', 1, 'litro', 32
UNION ALL SELECT '6916', 'Supreme Mineral N1', 20, 'litro', 33
UNION ALL SELECT '432029', 'Fastac', 1, 'litro', 34
UNION ALL SELECT '432029', 'Nomolt', 1, 'litro', 35
UNION ALL SELECT '388564', 'YaraLiva Nitrabo', 250, 'kg', 36
UNION ALL SELECT '388650', 'YaraLiva Nitrabo', 750, 'kg', 37
UNION ALL SELECT '7236', 'Transfer UP', 10, 'litro', 38
UNION ALL SELECT '7292', 'Reforce Ultra', 5, 'litro', 39
UNION ALL SELECT '7292', 'Ferriflo NG', 5, 'litro', 40
UNION ALL SELECT '7292', 'Cal Super', 10, 'litro', 41
UNION ALL SELECT '7292', 'Boro Super', 2, 'litro', 42
UNION ALL SELECT '7292', 'Maxi Zinc', 1, 'litro', 43
) v
JOIN compra c ON c.numero_nota = v.nota
JOIN insumo i ON i.nome = v.insumo
WHERE @base_compra = 0
  AND NOT EXISTS (SELECT 1 FROM item_compra x WHERE x.id_compra = c.id_compra AND x.id_insumo = i.id_insumo)
ORDER BY v.ord;

-- A1. Talhoes lidos dos mapas impressos (nome e hectares como no papel)
INSERT INTO talhao (id_area, nome, hectares)
SELECT a.id_area, v.nome, v.hectares
FROM (
SELECT 'Bela Vista' AS area, '7 A (Cima)' AS nome, 5.40 AS hectares, 1 AS ord
UNION ALL SELECT 'Bela Vista', '7 B (Baixo)', 5.25, 2
UNION ALL SELECT 'Bela Vista', 'Caixa D''agua', 6.50, 3
UNION ALL SELECT 'Bela Vista', 'Tambor', 4.90, 4
UNION ALL SELECT 'Bela Vista', 'Casa', 7.00, 5
UNION ALL SELECT 'Bela Vista', 'Paulao', 9.40, 6
UNION ALL SELECT 'Bela Vista', 'Torres', 5.20, 7
UNION ALL SELECT 'Bela Vista', 'Pereira', 5.40, 8
UNION ALL SELECT 'Bela Vista', 'Gariroba', 6.55, 9
UNION ALL SELECT 'Bela Vista', 'Mato', 4.55, 10
UNION ALL SELECT 'Corujas', 'Serra', 3.35, 11
UNION ALL SELECT 'Corujas', 'Ype', 4.63, 12
UNION ALL SELECT 'Corujas', 'Mangueira', 3.20, 13
UNION ALL SELECT 'Corujas', 'Ladeirinha', 6.55, 14
UNION ALL SELECT 'Corujas', 'Bananeira Roxa', 2.30, 15
UNION ALL SELECT 'Corujas', 'Caixa D''agua', 1.70, 16
UNION ALL SELECT 'Corujas', 'Peao', 3.25, 17
UNION ALL SELECT 'Corujas', 'Carlinho', 6.30, 18
UNION ALL SELECT 'Corujas', 'Jose Candido', 4.60, 19
UNION ALL SELECT 'Serra II', 'Douglas 48', 5.81, 20
UNION ALL SELECT 'Serra II', 'Douglas 49', 5.83, 21
UNION ALL SELECT 'Serra II', 'Douglas 50', 6.35, 22
UNION ALL SELECT 'Serra II', 'Douglas 51', 5.91, 23
UNION ALL SELECT 'Serra II', 'Douglas Serra', 6.80, 24
) v
JOIN area a ON a.nome = v.area
WHERE NOT EXISTS (SELECT 1 FROM talhao t WHERE t.id_area = a.id_area AND t.nome = v.nome)
ORDER BY v.ord;

-- A2. Descricao das areas (so troca o texto; hectares da estimativa 2026 ficam)
UPDATE area SET descricao = 'Area de producao de 60,00 ha (estimativa 2026); 10 talhoes cadastrados (soma dos mapas: 60,15 ha)' WHERE nome = 'Bela Vista';
UPDATE area SET descricao = 'Area de producao de 31,98 ha (estimativa 2026); 9 talhoes cadastrados (soma dos mapas: 35,88 ha)' WHERE nome = 'Corujas';
UPDATE area SET descricao = 'Area de producao de 30,60 ha (estimativa 2026); 5 talhoes cadastrados (soma dos mapas: 30,70 ha; total impresso no mapa: 32,79 ha)' WHERE nome = 'Serra II';

-- A3. Tipo dos produtos, conforme a planilha de defensivos autorizados (safra 2025/2026)
UPDATE insumo SET tipo = CASE nome WHEN 'Spirit' THEN 'Inseticida/Fungicida' WHEN 'Pledge' THEN 'Herbicida' WHEN 'Melyra' THEN 'Fungicida' WHEN 'Poquer' THEN 'Herbicida' WHEN 'Roundup Original' THEN 'Herbicida' WHEN 'Alion SC500' THEN 'Herbicida' WHEN 'Supreme Mineral N1' THEN 'Adjuvante' WHEN 'Valpura EC' THEN 'Fungicida' WHEN 'Orkestra SC' THEN 'Fungicida' WHEN 'BioKiller' THEN 'Inseticida microbiologico' WHEN 'Crop Best' THEN 'Herbicida' WHEN 'Crop Exit S' THEN 'Herbicida' END
WHERE nome IN ('Spirit', 'Pledge', 'Melyra', 'Poquer', 'Roundup Original', 'Alion SC500', 'Supreme Mineral N1', 'Valpura EC', 'Orkestra SC', 'BioKiller', 'Crop Best', 'Crop Exit S') AND tipo = 'Insumo';

-- =====================  PARTE B - DADOS FICTICIOS  =====================

-- B0. Banco ja carregado pela versao ANTERIOR deste script? (ela gravava etiquetas no texto)
--     Entao converte no lugar: mesmos ids, texto normal, nada duplica. Banco novo: 0 linhas, nada acontece.
-- aplicacoes: guarda o id no controle (o numero de ordem vem da etiqueta antiga) e troca o texto
INSERT INTO registro_dados_ficticios (tabela, id_registro, ref)
SELECT 'aplicacao', a.id_aplicacao, CAST(SUBSTRING(a.observacao, 12, 3) AS UNSIGNED)
FROM aplicacao a
WHERE a.observacao LIKE '[SIMULADO #___]%'
  AND NOT EXISTS (SELECT 1 FROM registro_dados_ficticios r WHERE r.tabela = 'aplicacao' AND r.id_registro = a.id_aplicacao);
UPDATE aplicacao a JOIN (
SELECT 1 AS n, 'Herbicida pre-florada - Sede (Chico1, Chico2, Pinheiro)' AS obs
UNION ALL SELECT 2, 'Herbicida pre-florada - Sede (Engenho, Cafe Velho)'
UNION ALL SELECT 3, 'Herbicida pre-florada - Bela Vista (7 A, 7 B)'
UNION ALL SELECT 4, 'Herbicida pre-florada - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)'
UNION ALL SELECT 5, 'Herbicida pre-florada - Corujas (Serra, Ype, Mangueira)'
UNION ALL SELECT 6, 'Herbicida pre-florada - Corujas (Ladeirinha, Bananeira Roxa, Caixa Dagua, Peao, Carlinho, Jose Candido)'
UNION ALL SELECT 7, 'Adubacao NPK 1a parcela - Sede (todos os talhoes)'
UNION ALL SELECT 8, 'Adubacao NPK 1a parcela - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)'
UNION ALL SELECT 9, 'Adubacao NPK 1a parcela - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)'
UNION ALL SELECT 10, 'Adubacao NPK 1a parcela - Corujas (Serra, Ype, Mangueira)'
UNION ALL SELECT 11, 'Adubacao NPK 1a parcela - Corujas (Ladeirinha, Bananeira Roxa, Caixa Dagua, Peao, Carlinho, Jose Candido)'
UNION ALL SELECT 12, 'Adubacao NPK 1a parcela - Serra II (Douglas 48, 49, 50, 51 e Serra)'
UNION ALL SELECT 13, 'Inseticida bicho-mineiro - Sede (todos os talhoes)'
UNION ALL SELECT 14, 'Inseticida bicho-mineiro - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)'
UNION ALL SELECT 15, 'Reaplicacao da aplicacao de 02/12/2025 (chuva) - Sede (todos os talhoes)'
UNION ALL SELECT 16, 'Inseticida bicho-mineiro - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)'
UNION ALL SELECT 17, 'Inseticida bicho-mineiro - Corujas (Ladeirinha, Bananeira Roxa, Caixa Dagua, Peao, Carlinho, Jose Candido)'
UNION ALL SELECT 18, 'Inseticida bicho-mineiro - Serra II (Douglas 48, 49, 50, 51 e Serra)'
UNION ALL SELECT 19, 'Fungicida ferrugem e cercospora (Orkestra) - Sede (todos os talhoes)'
UNION ALL SELECT 20, 'Adubacao NPK 2a parcela - Sede (todos os talhoes)'
UNION ALL SELECT 21, 'Fungicida ferrugem e cercospora (Orkestra) - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)'
UNION ALL SELECT 22, 'Fungicida ferrugem e cercospora (Orkestra) - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)'
UNION ALL SELECT 23, 'Adubacao NPK 2a parcela - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)'
UNION ALL SELECT 24, 'Adubacao NPK 2a parcela - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)'
UNION ALL SELECT 25, 'Fungicida ferrugem e cercospora (Orkestra) - Corujas (Serra, Ype, Mangueira)'
UNION ALL SELECT 26, 'Adubacao NPK 2a parcela - Corujas (Ladeirinha, Bananeira Roxa, Caixa Dagua, Peao, Carlinho, Jose Candido)'
UNION ALL SELECT 27, 'Reaplicacao da aplicacao de 21/01/2026 (vento) - Corujas (Serra, Ype, Mangueira)'
UNION ALL SELECT 28, 'Fungicida ferrugem e cercospora (Orkestra) - Serra II (Douglas 48, 49, 50, 51 e Serra)'
UNION ALL SELECT 29, 'Adubacao NPK 2a parcela - Serra II (Douglas 48, 49, 50, 51 e Serra)'
UNION ALL SELECT 30, 'Adubacao foliar (boro e zinco) - Sede (todos os talhoes)'
UNION ALL SELECT 31, 'Adubacao foliar (boro e zinco) - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)'
UNION ALL SELECT 32, 'Reaplicacao da aplicacao de 04/02/2026 (chuva) - Sede (todos os talhoes)'
UNION ALL SELECT 33, 'Adubacao foliar (boro e zinco) - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato) - falha no bico do pulverizador'
UNION ALL SELECT 34, 'Reaplicacao da aplicacao de 10/02/2026 (outro) - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)'
UNION ALL SELECT 35, 'Fungicida ferrugem (Melyra) - Sede (todos os talhoes)'
UNION ALL SELECT 36, 'Fungicida ferrugem (Melyra) - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)'
UNION ALL SELECT 37, 'Adubacao foliar (boro e zinco) - Corujas (Ladeirinha, Bananeira Roxa, Caixa Dagua, Peao, Carlinho, Jose Candido)'
UNION ALL SELECT 38, 'Reaplicacao da aplicacao de 12/02/2026 (chuva) - Sede (todos os talhoes)'
UNION ALL SELECT 39, 'Fungicida ferrugem (Melyra) - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)'
UNION ALL SELECT 40, 'Reaplicacao da aplicacao de 17/02/2026 (chuva) - Corujas (Ladeirinha, Bananeira Roxa, Caixa Dagua, Peao, Carlinho, Jose Candido)'
UNION ALL SELECT 41, 'Reaplicacao da aplicacao de 18/02/2026 (chuva) - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)'
UNION ALL SELECT 42, 'Fungicida ferrugem (Melyra) - Corujas (Serra, Ype, Mangueira)'
UNION ALL SELECT 43, 'Fungicida ferrugem (Melyra) - Serra II (Douglas 48, 49, 50, 51 e Serra)'
UNION ALL SELECT 44, 'Reaplicacao da aplicacao de 24/02/2026 (chuva) - Corujas (Serra, Ype, Mangueira)'
UNION ALL SELECT 45, 'Reaplicacao da aplicacao de 26/02/2026 (vento) - Serra II (Douglas 48, 49, 50, 51 e Serra)'
UNION ALL SELECT 46, 'Inseticida cigarra e mineiro (Spirit) - Sede (todos os talhoes)'
UNION ALL SELECT 47, 'Inseticida cigarra e mineiro (Spirit) - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)'
UNION ALL SELECT 48, 'Reaplicacao da aplicacao de 05/03/2026 (sol) - Sede (todos os talhoes)'
UNION ALL SELECT 49, 'Adubacao NPK 3a parcela - Sede (todos os talhoes)'
UNION ALL SELECT 50, 'Adubacao NPK 3a parcela - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)'
UNION ALL SELECT 51, 'Inseticida cigarra e mineiro (Spirit) - Corujas (Ladeirinha, Bananeira Roxa, Caixa Dagua, Peao, Carlinho, Jose Candido)'
UNION ALL SELECT 52, 'Adubacao NPK 3a parcela - Serra II (Douglas 48, 49, 50, 51 e Serra)'
UNION ALL SELECT 53, 'Reaplicacao da aplicacao de 17/03/2026 (chuva) - Corujas (Ladeirinha, Bananeira Roxa, Caixa Dagua, Peao, Carlinho, Jose Candido)'
UNION ALL SELECT 54, 'Fungicida fechamento (Valpura) - Sede (todos os talhoes)'
UNION ALL SELECT 55, 'Fungicida fechamento (Valpura) - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)'
UNION ALL SELECT 56, 'Fungicida fechamento (Valpura) - Serra II (Douglas 48, 49, 50, 51 e Serra)'
UNION ALL SELECT 57, 'Herbicida pos-colheita - Sede (todos os talhoes)'
UNION ALL SELECT 58, 'Herbicida pos-colheita - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)'
UNION ALL SELECT 59, 'Herbicida pos-colheita - Corujas (Ladeirinha, Bananeira Roxa, Caixa Dagua, Peao, Carlinho, Jose Candido)'
UNION ALL SELECT 60, 'Herbicida pos-colheita - Serra II (Douglas 48 e 49)'
UNION ALL SELECT 61, 'Nitrato de calcio no solo - Sede (Chico1, Chico2, Pinheiro)'
UNION ALL SELECT 62, 'Calagem - Bela Vista (Caixa Dagua, Tambor, Casa)'
UNION ALL SELECT 63, 'Foliar pre-florada - Sede (todos os talhoes)'
UNION ALL SELECT 64, 'Foliar pre-florada - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)'
UNION ALL SELECT 65, 'Herbicida de manutencao - Sede (Engenho, Cafe Velho)'
UNION ALL SELECT 66, 'Herbicida de manutencao - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)'
UNION ALL SELECT 67, 'Reaplicacao da aplicacao de 27/10/2026 (chuva) - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)'
UNION ALL SELECT 68, 'Fungicida programado - Sede (todos os talhoes)'
UNION ALL SELECT 69, 'Inseticida programado - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)'
UNION ALL SELECT 70, 'Foliar programada - Serra II (Douglas 48, 49, 50, 51 e Serra)'
) t ON a.observacao LIKE CONCAT('[SIMULADO #', LPAD(t.n, 3, '0'), ']%')
   SET a.observacao = t.obs;

-- insumos: guarda o id, tira o sufixo do nome e a marca
INSERT INTO registro_dados_ficticios (tabela, id_registro)
SELECT 'insumo', i.id_insumo FROM insumo i
WHERE i.marca = 'SIMULADO' AND i.nome IN ('NPK 20-05-20 (simulado)', 'Calcario dolomitico (simulado)')
  AND NOT EXISTS (SELECT 1 FROM registro_dados_ficticios r WHERE r.tabela = 'insumo' AND r.id_registro = i.id_insumo);
UPDATE insumo SET nome = CASE nome WHEN 'NPK 20-05-20 (simulado)' THEN 'NPK 20-05-20' WHEN 'Calcario dolomitico (simulado)' THEN 'Calcario dolomitico' END, marca = NULL
WHERE marca = 'SIMULADO' AND nome IN ('NPK 20-05-20 (simulado)', 'Calcario dolomitico (simulado)');

-- compras: guarda o id e troca o numero da nota
INSERT INTO registro_dados_ficticios (tabela, id_registro)
SELECT 'compra', c.id_compra FROM compra c
WHERE c.numero_nota IN ('SIM-001', 'SIM-002', 'SIM-003', 'SIM-004', 'SIM-005', 'SIM-006', 'SIM-007', 'SIM-008', 'SIM-009', 'SIM-010')
  AND NOT EXISTS (SELECT 1 FROM registro_dados_ficticios r WHERE r.tabela = 'compra' AND r.id_registro = c.id_compra);
UPDATE compra SET numero_nota = CASE numero_nota WHEN 'SIM-001' THEN '21721' WHEN 'SIM-002' THEN '22098' WHEN 'SIM-003' THEN '22564' WHEN 'SIM-004' THEN '22999' WHEN 'SIM-005' THEN '23273' WHEN 'SIM-006' THEN '23745' WHEN 'SIM-007' THEN '24229' WHEN 'SIM-008' THEN '24417' WHEN 'SIM-009' THEN '24736' WHEN 'SIM-010' THEN '25203' END
WHERE numero_nota IN ('SIM-001', 'SIM-002', 'SIM-003', 'SIM-004', 'SIM-005', 'SIM-006', 'SIM-007', 'SIM-008', 'SIM-009', 'SIM-010');

SET @max_insumo := (SELECT COALESCE(MAX(id_insumo), 0) FROM insumo);

-- B1. Insumos ficticios e tipos deduzidos pelo nome (NAO constam na auditoria)
INSERT INTO insumo (nome, marca, tipo)
SELECT v.nome, v.marca, v.tipo
FROM (
SELECT 'NPK 20-05-20' AS nome, NULL AS marca, 'Fertilizante' AS tipo, 1 AS ord
UNION ALL SELECT 'Calcario dolomitico', NULL, 'Corretivo', 2
) v
WHERE NOT EXISTS (SELECT 1 FROM insumo x WHERE x.nome = v.nome)
ORDER BY v.ord;

INSERT INTO registro_dados_ficticios (tabela, id_registro)
SELECT 'insumo', i.id_insumo FROM insumo i
WHERE i.nome IN ('NPK 20-05-20', 'Calcario dolomitico') AND i.id_insumo > @max_insumo   -- so os criados agora (nao adota insumo de mesmo nome que outra pessoa cadastrou)
  AND NOT EXISTS (SELECT 1 FROM registro_dados_ficticios r WHERE r.tabela = 'insumo' AND r.id_registro = i.id_insumo);

UPDATE insumo SET tipo = CASE nome WHEN 'Curbix SC200' THEN 'Inseticida' WHEN 'Glufosinate Ammonium 200 G/L SL' THEN 'Herbicida' WHEN 'YaraLiva Nitrabo' THEN 'Fertilizante' WHEN 'Boro Super' THEN 'Fertilizante' WHEN 'Maxi Zinc' THEN 'Fertilizante' WHEN 'Ferriflo NG' THEN 'Fertilizante' WHEN 'Blend Mg-Zn-B' THEN 'Fertilizante' END
WHERE nome IN ('Curbix SC200', 'Glufosinate Ammonium 200 G/L SL', 'YaraLiva Nitrabo', 'Boro Super', 'Maxi Zinc', 'Ferriflo NG', 'Blend Mg-Zn-B') AND tipo = 'Insumo';

-- B2. Aplicadores ficticios: 4 tratores (placas inventadas) e 1 drone (serie inventada)
INSERT INTO aplicador (modelo, tipo, capacidade_max_litros, capacidade_max_kg)
SELECT v.modelo, v.tipo, v.cap_l, v.cap_kg
FROM (
SELECT 'DJI Agras T40 (serie 3WHDX00C)' AS modelo, 'drone' AS tipo, 40.00 AS cap_l, 50.00 AS cap_kg, 1 AS ord
UNION ALL SELECT 'Massey Ferguson 275 n.01 (placa QDE4F82)', 'trator', 600.00, NULL, 2
UNION ALL SELECT 'Valtra A750 n.02 (placa PXK7H19)', 'trator', 800.00, NULL, 3
UNION ALL SELECT 'New Holland TL75E n.03 (placa MJB3C56)', 'trator', NULL, 1200.00, 4
UNION ALL SELECT 'Massey Ferguson 4275 n.04 (placa RTA9K07)', 'trator', 1000.00, NULL, 5
) v
WHERE NOT EXISTS (SELECT 1 FROM aplicador x WHERE x.modelo = v.modelo)
ORDER BY v.ord;

INSERT INTO registro_dados_ficticios (tabela, id_registro)
SELECT 'aplicador', a.id_aplicador FROM aplicador a
WHERE a.modelo IN ('DJI Agras T40 (serie 3WHDX00C)', 'Massey Ferguson 275 n.01 (placa QDE4F82)', 'Valtra A750 n.02 (placa PXK7H19)', 'New Holland TL75E n.03 (placa MJB3C56)', 'Massey Ferguson 4275 n.04 (placa RTA9K07)')
  AND NOT EXISTS (SELECT 1 FROM registro_dados_ficticios r WHERE r.tabela = 'aplicador' AND r.id_registro = a.id_aplicador);

-- B3. Compras ficticias com preco unitario (R$ por litro ou por kg, inventado)
INSERT INTO compra (data_compra, numero_nota)
SELECT v.dt, v.nota
FROM (
SELECT DATE '2025-09-30' AS dt, '21721' AS nota, 1 AS ord
UNION ALL SELECT DATE '2025-10-30', '22098', 2
UNION ALL SELECT DATE '2025-11-27', '22564', 3
UNION ALL SELECT DATE '2025-12-29', '22999', 4
UNION ALL SELECT DATE '2026-01-30', '23273', 5
UNION ALL SELECT DATE '2026-02-27', '23745', 6
UNION ALL SELECT DATE '2026-03-31', '24229', 7
UNION ALL SELECT DATE '2026-07-30', '24417', 8
UNION ALL SELECT DATE '2026-09-02', '24736', 9
UNION ALL SELECT DATE '2026-10-02', '25203', 10
) v
WHERE NOT EXISTS (SELECT 1 FROM compra c WHERE c.numero_nota = v.nota AND c.data_compra = v.dt)
ORDER BY v.ord;

INSERT INTO item_compra (id_compra, id_insumo, quantidade, unidade_medida, preco_unitario)
SELECT c.id_compra, i.id_insumo, v.qtd, v.un, v.preco
FROM (
SELECT DATE '2025-09-30' AS dt, '21721' AS nota, 'NPK 20-05-20' AS insumo, 61700.000 AS qtd, 'kg' AS un, 3.45 AS preco, 1 AS ord
UNION ALL SELECT DATE '2025-09-30', '21721', 'Pledge', 20.000, 'kg', 417.91, 2
UNION ALL SELECT DATE '2025-09-30', '21721', 'Roundup Original', 270.000, 'litro', 28.74, 3
UNION ALL SELECT DATE '2025-10-30', '22098', 'Curbix SC200', 210.000, 'litro', 272.83, 4
UNION ALL SELECT DATE '2025-11-27', '22564', 'Orkestra SC', 35.000, 'litro', 374.63, 5
UNION ALL SELECT DATE '2025-11-27', '22564', 'Supreme Mineral N1', 65.000, 'litro', 17.77, 6
UNION ALL SELECT DATE '2025-12-29', '22999', 'Boro Super', 225.000, 'litro', 24.33, 7
UNION ALL SELECT DATE '2025-12-29', '22999', 'Maxi Zinc', 180.000, 'litro', 39.33, 8
UNION ALL SELECT DATE '2025-12-29', '22999', 'Melyra', 195.000, 'litro', 333.10, 9
UNION ALL SELECT DATE '2025-12-29', '22999', 'NPK 20-05-20', 59400.000, 'kg', 3.43, 10
UNION ALL SELECT DATE '2026-01-30', '23273', 'Spirit', 65.000, 'litro', 295.39, 11
UNION ALL SELECT DATE '2026-02-27', '23745', 'Roundup Original', 260.000, 'litro', 28.85, 12
UNION ALL SELECT DATE '2026-02-27', '23745', 'Valpura EC', 90.000, 'litro', 303.52, 13
UNION ALL SELECT DATE '2026-03-31', '24229', 'Boro Super', 210.000, 'litro', 25.13, 14
UNION ALL SELECT DATE '2026-03-31', '24229', 'Maxi Zinc', 170.000, 'litro', 39.07, 15
UNION ALL SELECT DATE '2026-03-31', '24229', 'Orkestra SC', 35.000, 'litro', 387.64, 16
UNION ALL SELECT DATE '2026-03-31', '24229', 'Spirit', 65.000, 'litro', 302.38, 17
UNION ALL SELECT DATE '2026-03-31', '24229', 'Supreme Mineral N1', 65.000, 'litro', 17.71, 18
UNION ALL SELECT DATE '2026-07-30', '24417', 'Alion SC500', 40.000, 'litro', 537.94, 19
UNION ALL SELECT DATE '2026-07-30', '24417', 'YaraLiva Nitrabo', 650.000, 'kg', 3.86, 20
UNION ALL SELECT DATE '2026-09-02', '24736', 'Blend Mg-Zn-B', 115.000, 'litro', 36.33, 21
UNION ALL SELECT DATE '2026-09-02', '24736', 'Calcario dolomitico', 14600.000, 'kg', 0.37, 22
UNION ALL SELECT DATE '2026-09-02', '24736', 'Ferriflo NG', 60.000, 'litro', 42.90, 23
UNION ALL SELECT DATE '2026-09-02', '24736', 'YaraLiva Nitrabo', 550.000, 'kg', 4.03, 24
UNION ALL SELECT DATE '2026-10-02', '25203', 'Calcario dolomitico', 14100.000, 'kg', 0.40, 25
UNION ALL SELECT DATE '2026-10-02', '25203', 'Glufosinate Ammonium 200 G/L SL', 240.000, 'litro', 45.36, 26
) v
JOIN compra c ON c.numero_nota = v.nota AND c.data_compra = v.dt
JOIN insumo i ON i.nome = v.insumo
WHERE NOT EXISTS (SELECT 1 FROM item_compra x WHERE x.id_compra = c.id_compra AND x.id_insumo = i.id_insumo)
ORDER BY v.ord;

INSERT INTO registro_dados_ficticios (tabela, id_registro)
SELECT 'compra', c.id_compra FROM compra c
WHERE (c.data_compra, c.numero_nota) IN (
    (DATE '2025-09-30', '21721'),
    (DATE '2025-10-30', '22098'),
    (DATE '2025-11-27', '22564'),
    (DATE '2025-12-29', '22999'),
    (DATE '2026-01-30', '23273'),
    (DATE '2026-02-27', '23745'),
    (DATE '2026-03-31', '24229'),
    (DATE '2026-07-30', '24417'),
    (DATE '2026-09-02', '24736'),
    (DATE '2026-10-02', '25203'))
  AND NOT EXISTS (SELECT 1 FROM registro_dados_ficticios r WHERE r.tabela = 'compra' AND r.id_registro = c.id_compra);

-- B4. Aplicacoes ficticias (safra 2025/2026 ate hoje). Ordem: aplicacao, controle, talhoes, insumos.
--     Reaplicacoes citam a data da aplicacao de origem.
INSERT INTO aplicacao (id_operacao, id_aplicador, data_aplicacao, observacao, horas_ate_chuva, motivo_reaplicacao)
SELECT o.id_operacao, ap.id_aplicador, t.dt, t.obs, t.horas, t.motivo
FROM (
SELECT 1 AS n, 'Pulverizacao' AS operacao, 'Bomba costal Jacto 1' AS aplicador, DATE '2025-10-14' AS dt, 'Herbicida pre-florada - Sede (Chico1, Chico2, Pinheiro)' AS obs, 10.60 AS horas, NULL AS motivo
UNION ALL SELECT 2, 'Pulverizacao', 'Bomba costal Jacto 2', DATE '2025-10-15', 'Herbicida pre-florada - Sede (Engenho, Cafe Velho)', 5.90, NULL
UNION ALL SELECT 3, 'Pulverizacao', 'Massey Ferguson 275 n.01 (placa QDE4F82)', DATE '2025-10-21', 'Herbicida pre-florada - Bela Vista (7 A, 7 B)', 17.30, NULL
UNION ALL SELECT 4, 'Pulverizacao', 'Valtra A750 n.02 (placa PXK7H19)', DATE '2025-10-28', 'Herbicida pre-florada - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)', NULL, NULL
UNION ALL SELECT 5, 'Pulverizacao', 'Bomba costal Jacto 4', DATE '2025-11-03', 'Herbicida pre-florada - Corujas (Serra, Ype, Mangueira)', 5.50, NULL
UNION ALL SELECT 6, 'Pulverizacao', 'Bomba costal Jacto 5', DATE '2025-11-04', 'Herbicida pre-florada - Corujas (Ladeirinha, Bananeira Roxa, Caixa Dagua, Peao, Carlinho, Jose Candido)', 7.90, NULL
UNION ALL SELECT 7, 'Adubacao', 'New Holland TL75E n.03 (placa MJB3C56)', DATE '2025-11-06', 'Adubacao NPK 1a parcela - Sede (todos os talhoes)', NULL, NULL
UNION ALL SELECT 8, 'Adubacao', 'New Holland TL75E n.03 (placa MJB3C56)', DATE '2025-11-10', 'Adubacao NPK 1a parcela - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)', NULL, NULL
UNION ALL SELECT 9, 'Adubacao', 'Drone DJI', DATE '2025-11-12', 'Adubacao NPK 1a parcela - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)', NULL, NULL
UNION ALL SELECT 10, 'Adubacao', 'DJI Agras T40 (serie 3WHDX00C)', DATE '2025-11-18', 'Adubacao NPK 1a parcela - Corujas (Serra, Ype, Mangueira)', NULL, NULL
UNION ALL SELECT 11, 'Adubacao', 'DJI Agras T40 (serie 3WHDX00C)', DATE '2025-11-19', 'Adubacao NPK 1a parcela - Corujas (Ladeirinha, Bananeira Roxa, Caixa Dagua, Peao, Carlinho, Jose Candido)', NULL, NULL
UNION ALL SELECT 12, 'Adubacao', 'Drone DJI', DATE '2025-11-24', 'Adubacao NPK 1a parcela - Serra II (Douglas 48, 49, 50, 51 e Serra)', NULL, NULL
UNION ALL SELECT 13, 'Pulverizacao', 'Massey Ferguson 275 n.01 (placa QDE4F82)', DATE '2025-12-02', 'Inseticida bicho-mineiro - Sede (todos os talhoes)', 0.90, 'chuva'
UNION ALL SELECT 14, 'Pulverizacao', 'Valtra A750 n.02 (placa PXK7H19)', DATE '2025-12-04', 'Inseticida bicho-mineiro - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)', 26.20, NULL
UNION ALL SELECT 15, 'Pulverizacao', 'Massey Ferguson 275 n.01 (placa QDE4F82)', DATE '2025-12-06', 'Reaplicacao da aplicacao de 02/12/2025 (chuva) - Sede (todos os talhoes)', 23.60, NULL
UNION ALL SELECT 16, 'Pulverizacao', 'Valtra A750 n.02 (placa PXK7H19)', DATE '2025-12-09', 'Inseticida bicho-mineiro - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)', 3.60, NULL
UNION ALL SELECT 17, 'Pulverizacao', 'DJI Agras T40 (serie 3WHDX00C)', DATE '2025-12-11', 'Inseticida bicho-mineiro - Corujas (Ladeirinha, Bananeira Roxa, Caixa Dagua, Peao, Carlinho, Jose Candido)', 30.00, NULL
UNION ALL SELECT 18, 'Pulverizacao', 'Drone DJI', DATE '2025-12-16', 'Inseticida bicho-mineiro - Serra II (Douglas 48, 49, 50, 51 e Serra)', 10.10, NULL
UNION ALL SELECT 19, 'Pulverizacao', 'Massey Ferguson 275 n.01 (placa QDE4F82)', DATE '2026-01-08', 'Fungicida ferrugem e cercospora (Orkestra) - Sede (todos os talhoes)', 32.20, NULL
UNION ALL SELECT 20, 'Adubacao', 'New Holland TL75E n.03 (placa MJB3C56)', DATE '2026-01-12', 'Adubacao NPK 2a parcela - Sede (todos os talhoes)', NULL, NULL
UNION ALL SELECT 21, 'Pulverizacao', 'Valtra A750 n.02 (placa PXK7H19)', DATE '2026-01-13', 'Fungicida ferrugem e cercospora (Orkestra) - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)', 26.50, NULL
UNION ALL SELECT 22, 'Pulverizacao', 'Valtra A750 n.02 (placa PXK7H19)', DATE '2026-01-14', 'Fungicida ferrugem e cercospora (Orkestra) - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)', 25.50, NULL
UNION ALL SELECT 23, 'Adubacao', 'New Holland TL75E n.03 (placa MJB3C56)', DATE '2026-01-15', 'Adubacao NPK 2a parcela - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)', 6.20, NULL
UNION ALL SELECT 24, 'Adubacao', 'Drone DJI', DATE '2026-01-20', 'Adubacao NPK 2a parcela - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)', NULL, NULL
UNION ALL SELECT 25, 'Pulverizacao', 'DJI Agras T40 (serie 3WHDX00C)', DATE '2026-01-21', 'Fungicida ferrugem e cercospora (Orkestra) - Corujas (Serra, Ype, Mangueira)', 17.50, 'vento'
UNION ALL SELECT 26, 'Adubacao', 'DJI Agras T40 (serie 3WHDX00C)', DATE '2026-01-22', 'Adubacao NPK 2a parcela - Corujas (Ladeirinha, Bananeira Roxa, Caixa Dagua, Peao, Carlinho, Jose Candido)', NULL, NULL
UNION ALL SELECT 27, 'Pulverizacao', 'DJI Agras T40 (serie 3WHDX00C)', DATE '2026-01-22', 'Reaplicacao da aplicacao de 21/01/2026 (vento) - Corujas (Serra, Ype, Mangueira)', 4.20, NULL
UNION ALL SELECT 28, 'Pulverizacao', 'Drone DJI', DATE '2026-01-26', 'Fungicida ferrugem e cercospora (Orkestra) - Serra II (Douglas 48, 49, 50, 51 e Serra)', 33.90, NULL
UNION ALL SELECT 29, 'Adubacao', 'Drone DJI', DATE '2026-01-27', 'Adubacao NPK 2a parcela - Serra II (Douglas 48, 49, 50, 51 e Serra)', NULL, NULL
UNION ALL SELECT 30, 'Pulverizacao', 'Massey Ferguson 275 n.01 (placa QDE4F82)', DATE '2026-02-04', 'Adubacao foliar (boro e zinco) - Sede (todos os talhoes)', 2.60, 'chuva'
UNION ALL SELECT 31, 'Pulverizacao', 'Valtra A750 n.02 (placa PXK7H19)', DATE '2026-02-09', 'Adubacao foliar (boro e zinco) - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)', 20.20, NULL
UNION ALL SELECT 32, 'Pulverizacao', 'Massey Ferguson 275 n.01 (placa QDE4F82)', DATE '2026-02-09', 'Reaplicacao da aplicacao de 04/02/2026 (chuva) - Sede (todos os talhoes)', 22.50, NULL
UNION ALL SELECT 33, 'Pulverizacao', 'Massey Ferguson 4275 n.04 (placa RTA9K07)', DATE '2026-02-10', 'Adubacao foliar (boro e zinco) - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato) - falha no bico do pulverizador', 4.60, 'outro'
UNION ALL SELECT 34, 'Pulverizacao', 'Massey Ferguson 4275 n.04 (placa RTA9K07)', DATE '2026-02-11', 'Reaplicacao da aplicacao de 10/02/2026 (outro) - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)', 5.10, NULL
UNION ALL SELECT 35, 'Pulverizacao', 'Massey Ferguson 275 n.01 (placa QDE4F82)', DATE '2026-02-12', 'Fungicida ferrugem (Melyra) - Sede (todos os talhoes)', 1.20, 'chuva'
UNION ALL SELECT 36, 'Pulverizacao', 'Valtra A750 n.02 (placa PXK7H19)', DATE '2026-02-16', 'Fungicida ferrugem (Melyra) - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)', 16.80, NULL
UNION ALL SELECT 37, 'Pulverizacao', 'DJI Agras T40 (serie 3WHDX00C)', DATE '2026-02-17', 'Adubacao foliar (boro e zinco) - Corujas (Ladeirinha, Bananeira Roxa, Caixa Dagua, Peao, Carlinho, Jose Candido)', 1.10, 'chuva'
UNION ALL SELECT 38, 'Pulverizacao', 'Massey Ferguson 275 n.01 (placa QDE4F82)', DATE '2026-02-17', 'Reaplicacao da aplicacao de 12/02/2026 (chuva) - Sede (todos os talhoes)', 4.70, NULL
UNION ALL SELECT 39, 'Pulverizacao', 'Massey Ferguson 4275 n.04 (placa RTA9K07)', DATE '2026-02-18', 'Fungicida ferrugem (Melyra) - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)', 1.60, 'chuva'
UNION ALL SELECT 40, 'Pulverizacao', 'DJI Agras T40 (serie 3WHDX00C)', DATE '2026-02-21', 'Reaplicacao da aplicacao de 17/02/2026 (chuva) - Corujas (Ladeirinha, Bananeira Roxa, Caixa Dagua, Peao, Carlinho, Jose Candido)', NULL, NULL
UNION ALL SELECT 41, 'Pulverizacao', 'Massey Ferguson 4275 n.04 (placa RTA9K07)', DATE '2026-02-21', 'Reaplicacao da aplicacao de 18/02/2026 (chuva) - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)', 14.70, NULL
UNION ALL SELECT 42, 'Pulverizacao', 'DJI Agras T40 (serie 3WHDX00C)', DATE '2026-02-24', 'Fungicida ferrugem (Melyra) - Corujas (Serra, Ype, Mangueira)', 1.60, 'chuva'
UNION ALL SELECT 43, 'Pulverizacao', 'Drone DJI', DATE '2026-02-26', 'Fungicida ferrugem (Melyra) - Serra II (Douglas 48, 49, 50, 51 e Serra)', 12.50, 'vento'
UNION ALL SELECT 44, 'Pulverizacao', 'DJI Agras T40 (serie 3WHDX00C)', DATE '2026-03-02', 'Reaplicacao da aplicacao de 24/02/2026 (chuva) - Corujas (Serra, Ype, Mangueira)', 21.60, NULL
UNION ALL SELECT 45, 'Pulverizacao', 'Drone DJI', DATE '2026-03-03', 'Reaplicacao da aplicacao de 26/02/2026 (vento) - Serra II (Douglas 48, 49, 50, 51 e Serra)', NULL, NULL
UNION ALL SELECT 46, 'Pulverizacao', 'Massey Ferguson 275 n.01 (placa QDE4F82)', DATE '2026-03-05', 'Inseticida cigarra e mineiro (Spirit) - Sede (todos os talhoes)', 18.40, 'sol'
UNION ALL SELECT 47, 'Pulverizacao', 'Valtra A750 n.02 (placa PXK7H19)', DATE '2026-03-09', 'Inseticida cigarra e mineiro (Spirit) - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)', 31.50, NULL
UNION ALL SELECT 48, 'Pulverizacao', 'Massey Ferguson 275 n.01 (placa QDE4F82)', DATE '2026-03-09', 'Reaplicacao da aplicacao de 05/03/2026 (sol) - Sede (todos os talhoes)', NULL, NULL
UNION ALL SELECT 49, 'Adubacao', 'New Holland TL75E n.03 (placa MJB3C56)', DATE '2026-03-10', 'Adubacao NPK 3a parcela - Sede (todos os talhoes)', NULL, NULL
UNION ALL SELECT 50, 'Adubacao', 'New Holland TL75E n.03 (placa MJB3C56)', DATE '2026-03-12', 'Adubacao NPK 3a parcela - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)', 4.60, NULL
UNION ALL SELECT 51, 'Pulverizacao', 'DJI Agras T40 (serie 3WHDX00C)', DATE '2026-03-17', 'Inseticida cigarra e mineiro (Spirit) - Corujas (Ladeirinha, Bananeira Roxa, Caixa Dagua, Peao, Carlinho, Jose Candido)', 0.70, 'chuva'
UNION ALL SELECT 52, 'Adubacao', 'Drone DJI', DATE '2026-03-18', 'Adubacao NPK 3a parcela - Serra II (Douglas 48, 49, 50, 51 e Serra)', NULL, NULL
UNION ALL SELECT 53, 'Pulverizacao', 'DJI Agras T40 (serie 3WHDX00C)', DATE '2026-03-19', 'Reaplicacao da aplicacao de 17/03/2026 (chuva) - Corujas (Ladeirinha, Bananeira Roxa, Caixa Dagua, Peao, Carlinho, Jose Candido)', 9.50, NULL
UNION ALL SELECT 54, 'Pulverizacao', 'Massey Ferguson 275 n.01 (placa QDE4F82)', DATE '2026-04-07', 'Fungicida fechamento (Valpura) - Sede (todos os talhoes)', 28.30, NULL
UNION ALL SELECT 55, 'Pulverizacao', 'Massey Ferguson 4275 n.04 (placa RTA9K07)', DATE '2026-04-13', 'Fungicida fechamento (Valpura) - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)', 23.00, NULL
UNION ALL SELECT 56, 'Pulverizacao', 'Drone DJI', DATE '2026-04-21', 'Fungicida fechamento (Valpura) - Serra II (Douglas 48, 49, 50, 51 e Serra)', 20.70, NULL
UNION ALL SELECT 57, 'Pulverizacao', 'Massey Ferguson 275 n.01 (placa QDE4F82)', DATE '2026-08-11', 'Herbicida pos-colheita - Sede (todos os talhoes)', 24.30, NULL
UNION ALL SELECT 58, 'Pulverizacao', 'Valtra A750 n.02 (placa PXK7H19)', DATE '2026-08-13', 'Herbicida pos-colheita - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)', 8.70, NULL
UNION ALL SELECT 59, 'Pulverizacao', 'Bomba costal Jacto 6', DATE '2026-08-19', 'Herbicida pos-colheita - Corujas (Ladeirinha, Bananeira Roxa, Caixa Dagua, Peao, Carlinho, Jose Candido)', 26.60, NULL
UNION ALL SELECT 60, 'Pulverizacao', 'Bomba costal Jacto 7', DATE '2026-08-25', 'Herbicida pos-colheita - Serra II (Douglas 48 e 49)', 26.80, NULL
UNION ALL SELECT 61, 'Adubacao', 'New Holland TL75E n.03 (placa MJB3C56)', DATE '2026-09-14', 'Nitrato de calcio no solo - Sede (Chico1, Chico2, Pinheiro)', 11.00, NULL
UNION ALL SELECT 62, 'Adubacao', 'New Holland TL75E n.03 (placa MJB3C56)', DATE '2026-09-21', 'Calagem - Bela Vista (Caixa Dagua, Tambor, Casa)', NULL, NULL
UNION ALL SELECT 63, 'Pulverizacao', 'Massey Ferguson 275 n.01 (placa QDE4F82)', DATE '2026-09-29', 'Foliar pre-florada - Sede (todos os talhoes)', 17.60, NULL
UNION ALL SELECT 64, 'Pulverizacao', 'Valtra A750 n.02 (placa PXK7H19)', DATE '2026-10-06', 'Foliar pre-florada - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)', NULL, NULL
UNION ALL SELECT 65, 'Pulverizacao', 'Bomba costal Jacto 8', DATE '2026-10-20', 'Herbicida de manutencao - Sede (Engenho, Cafe Velho)', 34.20, NULL
UNION ALL SELECT 66, 'Pulverizacao', 'Massey Ferguson 4275 n.04 (placa RTA9K07)', DATE '2026-10-27', 'Herbicida de manutencao - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)', 2.40, 'chuva'
UNION ALL SELECT 67, 'Pulverizacao', 'Massey Ferguson 4275 n.04 (placa RTA9K07)', DATE '2026-10-30', 'Reaplicacao da aplicacao de 27/10/2026 (chuva) - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)', NULL, NULL
UNION ALL SELECT 68, 'Pulverizacao', 'Massey Ferguson 275 n.01 (placa QDE4F82)', DATE '2026-11-09', 'Fungicida programado - Sede (todos os talhoes)', NULL, NULL
UNION ALL SELECT 69, 'Pulverizacao', 'Valtra A750 n.02 (placa PXK7H19)', DATE '2026-11-10', 'Inseticida programado - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)', NULL, NULL
UNION ALL SELECT 70, 'Pulverizacao', 'Drone DJI', DATE '2026-11-12', 'Foliar programada - Serra II (Douglas 48, 49, 50, 51 e Serra)', NULL, NULL
) t
JOIN operacao o ON o.nome = t.operacao
JOIN aplicador ap ON ap.modelo = t.aplicador
WHERE NOT EXISTS (SELECT 1 FROM aplicacao x WHERE x.id_operacao = o.id_operacao AND x.id_aplicador = ap.id_aplicador
                    AND x.data_aplicacao = t.dt AND x.observacao = t.obs)
ORDER BY t.n;

INSERT INTO registro_dados_ficticios (tabela, id_registro, ref)
SELECT 'aplicacao', ap.id_aplicacao, t.n
FROM (
SELECT 1 AS n, 'Pulverizacao' AS operacao, 'Bomba costal Jacto 1' AS aplicador, DATE '2025-10-14' AS dt, 'Herbicida pre-florada - Sede (Chico1, Chico2, Pinheiro)' AS obs
UNION ALL SELECT 2, 'Pulverizacao', 'Bomba costal Jacto 2', DATE '2025-10-15', 'Herbicida pre-florada - Sede (Engenho, Cafe Velho)'
UNION ALL SELECT 3, 'Pulverizacao', 'Massey Ferguson 275 n.01 (placa QDE4F82)', DATE '2025-10-21', 'Herbicida pre-florada - Bela Vista (7 A, 7 B)'
UNION ALL SELECT 4, 'Pulverizacao', 'Valtra A750 n.02 (placa PXK7H19)', DATE '2025-10-28', 'Herbicida pre-florada - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)'
UNION ALL SELECT 5, 'Pulverizacao', 'Bomba costal Jacto 4', DATE '2025-11-03', 'Herbicida pre-florada - Corujas (Serra, Ype, Mangueira)'
UNION ALL SELECT 6, 'Pulverizacao', 'Bomba costal Jacto 5', DATE '2025-11-04', 'Herbicida pre-florada - Corujas (Ladeirinha, Bananeira Roxa, Caixa Dagua, Peao, Carlinho, Jose Candido)'
UNION ALL SELECT 7, 'Adubacao', 'New Holland TL75E n.03 (placa MJB3C56)', DATE '2025-11-06', 'Adubacao NPK 1a parcela - Sede (todos os talhoes)'
UNION ALL SELECT 8, 'Adubacao', 'New Holland TL75E n.03 (placa MJB3C56)', DATE '2025-11-10', 'Adubacao NPK 1a parcela - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)'
UNION ALL SELECT 9, 'Adubacao', 'Drone DJI', DATE '2025-11-12', 'Adubacao NPK 1a parcela - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)'
UNION ALL SELECT 10, 'Adubacao', 'DJI Agras T40 (serie 3WHDX00C)', DATE '2025-11-18', 'Adubacao NPK 1a parcela - Corujas (Serra, Ype, Mangueira)'
UNION ALL SELECT 11, 'Adubacao', 'DJI Agras T40 (serie 3WHDX00C)', DATE '2025-11-19', 'Adubacao NPK 1a parcela - Corujas (Ladeirinha, Bananeira Roxa, Caixa Dagua, Peao, Carlinho, Jose Candido)'
UNION ALL SELECT 12, 'Adubacao', 'Drone DJI', DATE '2025-11-24', 'Adubacao NPK 1a parcela - Serra II (Douglas 48, 49, 50, 51 e Serra)'
UNION ALL SELECT 13, 'Pulverizacao', 'Massey Ferguson 275 n.01 (placa QDE4F82)', DATE '2025-12-02', 'Inseticida bicho-mineiro - Sede (todos os talhoes)'
UNION ALL SELECT 14, 'Pulverizacao', 'Valtra A750 n.02 (placa PXK7H19)', DATE '2025-12-04', 'Inseticida bicho-mineiro - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)'
UNION ALL SELECT 15, 'Pulverizacao', 'Massey Ferguson 275 n.01 (placa QDE4F82)', DATE '2025-12-06', 'Reaplicacao da aplicacao de 02/12/2025 (chuva) - Sede (todos os talhoes)'
UNION ALL SELECT 16, 'Pulverizacao', 'Valtra A750 n.02 (placa PXK7H19)', DATE '2025-12-09', 'Inseticida bicho-mineiro - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)'
UNION ALL SELECT 17, 'Pulverizacao', 'DJI Agras T40 (serie 3WHDX00C)', DATE '2025-12-11', 'Inseticida bicho-mineiro - Corujas (Ladeirinha, Bananeira Roxa, Caixa Dagua, Peao, Carlinho, Jose Candido)'
UNION ALL SELECT 18, 'Pulverizacao', 'Drone DJI', DATE '2025-12-16', 'Inseticida bicho-mineiro - Serra II (Douglas 48, 49, 50, 51 e Serra)'
UNION ALL SELECT 19, 'Pulverizacao', 'Massey Ferguson 275 n.01 (placa QDE4F82)', DATE '2026-01-08', 'Fungicida ferrugem e cercospora (Orkestra) - Sede (todos os talhoes)'
UNION ALL SELECT 20, 'Adubacao', 'New Holland TL75E n.03 (placa MJB3C56)', DATE '2026-01-12', 'Adubacao NPK 2a parcela - Sede (todos os talhoes)'
UNION ALL SELECT 21, 'Pulverizacao', 'Valtra A750 n.02 (placa PXK7H19)', DATE '2026-01-13', 'Fungicida ferrugem e cercospora (Orkestra) - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)'
UNION ALL SELECT 22, 'Pulverizacao', 'Valtra A750 n.02 (placa PXK7H19)', DATE '2026-01-14', 'Fungicida ferrugem e cercospora (Orkestra) - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)'
UNION ALL SELECT 23, 'Adubacao', 'New Holland TL75E n.03 (placa MJB3C56)', DATE '2026-01-15', 'Adubacao NPK 2a parcela - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)'
UNION ALL SELECT 24, 'Adubacao', 'Drone DJI', DATE '2026-01-20', 'Adubacao NPK 2a parcela - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)'
UNION ALL SELECT 25, 'Pulverizacao', 'DJI Agras T40 (serie 3WHDX00C)', DATE '2026-01-21', 'Fungicida ferrugem e cercospora (Orkestra) - Corujas (Serra, Ype, Mangueira)'
UNION ALL SELECT 26, 'Adubacao', 'DJI Agras T40 (serie 3WHDX00C)', DATE '2026-01-22', 'Adubacao NPK 2a parcela - Corujas (Ladeirinha, Bananeira Roxa, Caixa Dagua, Peao, Carlinho, Jose Candido)'
UNION ALL SELECT 27, 'Pulverizacao', 'DJI Agras T40 (serie 3WHDX00C)', DATE '2026-01-22', 'Reaplicacao da aplicacao de 21/01/2026 (vento) - Corujas (Serra, Ype, Mangueira)'
UNION ALL SELECT 28, 'Pulverizacao', 'Drone DJI', DATE '2026-01-26', 'Fungicida ferrugem e cercospora (Orkestra) - Serra II (Douglas 48, 49, 50, 51 e Serra)'
UNION ALL SELECT 29, 'Adubacao', 'Drone DJI', DATE '2026-01-27', 'Adubacao NPK 2a parcela - Serra II (Douglas 48, 49, 50, 51 e Serra)'
UNION ALL SELECT 30, 'Pulverizacao', 'Massey Ferguson 275 n.01 (placa QDE4F82)', DATE '2026-02-04', 'Adubacao foliar (boro e zinco) - Sede (todos os talhoes)'
UNION ALL SELECT 31, 'Pulverizacao', 'Valtra A750 n.02 (placa PXK7H19)', DATE '2026-02-09', 'Adubacao foliar (boro e zinco) - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)'
UNION ALL SELECT 32, 'Pulverizacao', 'Massey Ferguson 275 n.01 (placa QDE4F82)', DATE '2026-02-09', 'Reaplicacao da aplicacao de 04/02/2026 (chuva) - Sede (todos os talhoes)'
UNION ALL SELECT 33, 'Pulverizacao', 'Massey Ferguson 4275 n.04 (placa RTA9K07)', DATE '2026-02-10', 'Adubacao foliar (boro e zinco) - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato) - falha no bico do pulverizador'
UNION ALL SELECT 34, 'Pulverizacao', 'Massey Ferguson 4275 n.04 (placa RTA9K07)', DATE '2026-02-11', 'Reaplicacao da aplicacao de 10/02/2026 (outro) - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)'
UNION ALL SELECT 35, 'Pulverizacao', 'Massey Ferguson 275 n.01 (placa QDE4F82)', DATE '2026-02-12', 'Fungicida ferrugem (Melyra) - Sede (todos os talhoes)'
UNION ALL SELECT 36, 'Pulverizacao', 'Valtra A750 n.02 (placa PXK7H19)', DATE '2026-02-16', 'Fungicida ferrugem (Melyra) - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)'
UNION ALL SELECT 37, 'Pulverizacao', 'DJI Agras T40 (serie 3WHDX00C)', DATE '2026-02-17', 'Adubacao foliar (boro e zinco) - Corujas (Ladeirinha, Bananeira Roxa, Caixa Dagua, Peao, Carlinho, Jose Candido)'
UNION ALL SELECT 38, 'Pulverizacao', 'Massey Ferguson 275 n.01 (placa QDE4F82)', DATE '2026-02-17', 'Reaplicacao da aplicacao de 12/02/2026 (chuva) - Sede (todos os talhoes)'
UNION ALL SELECT 39, 'Pulverizacao', 'Massey Ferguson 4275 n.04 (placa RTA9K07)', DATE '2026-02-18', 'Fungicida ferrugem (Melyra) - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)'
UNION ALL SELECT 40, 'Pulverizacao', 'DJI Agras T40 (serie 3WHDX00C)', DATE '2026-02-21', 'Reaplicacao da aplicacao de 17/02/2026 (chuva) - Corujas (Ladeirinha, Bananeira Roxa, Caixa Dagua, Peao, Carlinho, Jose Candido)'
UNION ALL SELECT 41, 'Pulverizacao', 'Massey Ferguson 4275 n.04 (placa RTA9K07)', DATE '2026-02-21', 'Reaplicacao da aplicacao de 18/02/2026 (chuva) - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)'
UNION ALL SELECT 42, 'Pulverizacao', 'DJI Agras T40 (serie 3WHDX00C)', DATE '2026-02-24', 'Fungicida ferrugem (Melyra) - Corujas (Serra, Ype, Mangueira)'
UNION ALL SELECT 43, 'Pulverizacao', 'Drone DJI', DATE '2026-02-26', 'Fungicida ferrugem (Melyra) - Serra II (Douglas 48, 49, 50, 51 e Serra)'
UNION ALL SELECT 44, 'Pulverizacao', 'DJI Agras T40 (serie 3WHDX00C)', DATE '2026-03-02', 'Reaplicacao da aplicacao de 24/02/2026 (chuva) - Corujas (Serra, Ype, Mangueira)'
UNION ALL SELECT 45, 'Pulverizacao', 'Drone DJI', DATE '2026-03-03', 'Reaplicacao da aplicacao de 26/02/2026 (vento) - Serra II (Douglas 48, 49, 50, 51 e Serra)'
UNION ALL SELECT 46, 'Pulverizacao', 'Massey Ferguson 275 n.01 (placa QDE4F82)', DATE '2026-03-05', 'Inseticida cigarra e mineiro (Spirit) - Sede (todos os talhoes)'
UNION ALL SELECT 47, 'Pulverizacao', 'Valtra A750 n.02 (placa PXK7H19)', DATE '2026-03-09', 'Inseticida cigarra e mineiro (Spirit) - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)'
UNION ALL SELECT 48, 'Pulverizacao', 'Massey Ferguson 275 n.01 (placa QDE4F82)', DATE '2026-03-09', 'Reaplicacao da aplicacao de 05/03/2026 (sol) - Sede (todos os talhoes)'
UNION ALL SELECT 49, 'Adubacao', 'New Holland TL75E n.03 (placa MJB3C56)', DATE '2026-03-10', 'Adubacao NPK 3a parcela - Sede (todos os talhoes)'
UNION ALL SELECT 50, 'Adubacao', 'New Holland TL75E n.03 (placa MJB3C56)', DATE '2026-03-12', 'Adubacao NPK 3a parcela - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)'
UNION ALL SELECT 51, 'Pulverizacao', 'DJI Agras T40 (serie 3WHDX00C)', DATE '2026-03-17', 'Inseticida cigarra e mineiro (Spirit) - Corujas (Ladeirinha, Bananeira Roxa, Caixa Dagua, Peao, Carlinho, Jose Candido)'
UNION ALL SELECT 52, 'Adubacao', 'Drone DJI', DATE '2026-03-18', 'Adubacao NPK 3a parcela - Serra II (Douglas 48, 49, 50, 51 e Serra)'
UNION ALL SELECT 53, 'Pulverizacao', 'DJI Agras T40 (serie 3WHDX00C)', DATE '2026-03-19', 'Reaplicacao da aplicacao de 17/03/2026 (chuva) - Corujas (Ladeirinha, Bananeira Roxa, Caixa Dagua, Peao, Carlinho, Jose Candido)'
UNION ALL SELECT 54, 'Pulverizacao', 'Massey Ferguson 275 n.01 (placa QDE4F82)', DATE '2026-04-07', 'Fungicida fechamento (Valpura) - Sede (todos os talhoes)'
UNION ALL SELECT 55, 'Pulverizacao', 'Massey Ferguson 4275 n.04 (placa RTA9K07)', DATE '2026-04-13', 'Fungicida fechamento (Valpura) - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)'
UNION ALL SELECT 56, 'Pulverizacao', 'Drone DJI', DATE '2026-04-21', 'Fungicida fechamento (Valpura) - Serra II (Douglas 48, 49, 50, 51 e Serra)'
UNION ALL SELECT 57, 'Pulverizacao', 'Massey Ferguson 275 n.01 (placa QDE4F82)', DATE '2026-08-11', 'Herbicida pos-colheita - Sede (todos os talhoes)'
UNION ALL SELECT 58, 'Pulverizacao', 'Valtra A750 n.02 (placa PXK7H19)', DATE '2026-08-13', 'Herbicida pos-colheita - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)'
UNION ALL SELECT 59, 'Pulverizacao', 'Bomba costal Jacto 6', DATE '2026-08-19', 'Herbicida pos-colheita - Corujas (Ladeirinha, Bananeira Roxa, Caixa Dagua, Peao, Carlinho, Jose Candido)'
UNION ALL SELECT 60, 'Pulverizacao', 'Bomba costal Jacto 7', DATE '2026-08-25', 'Herbicida pos-colheita - Serra II (Douglas 48 e 49)'
UNION ALL SELECT 61, 'Adubacao', 'New Holland TL75E n.03 (placa MJB3C56)', DATE '2026-09-14', 'Nitrato de calcio no solo - Sede (Chico1, Chico2, Pinheiro)'
UNION ALL SELECT 62, 'Adubacao', 'New Holland TL75E n.03 (placa MJB3C56)', DATE '2026-09-21', 'Calagem - Bela Vista (Caixa Dagua, Tambor, Casa)'
UNION ALL SELECT 63, 'Pulverizacao', 'Massey Ferguson 275 n.01 (placa QDE4F82)', DATE '2026-09-29', 'Foliar pre-florada - Sede (todos os talhoes)'
UNION ALL SELECT 64, 'Pulverizacao', 'Valtra A750 n.02 (placa PXK7H19)', DATE '2026-10-06', 'Foliar pre-florada - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)'
UNION ALL SELECT 65, 'Pulverizacao', 'Bomba costal Jacto 8', DATE '2026-10-20', 'Herbicida de manutencao - Sede (Engenho, Cafe Velho)'
UNION ALL SELECT 66, 'Pulverizacao', 'Massey Ferguson 4275 n.04 (placa RTA9K07)', DATE '2026-10-27', 'Herbicida de manutencao - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)'
UNION ALL SELECT 67, 'Pulverizacao', 'Massey Ferguson 4275 n.04 (placa RTA9K07)', DATE '2026-10-30', 'Reaplicacao da aplicacao de 27/10/2026 (chuva) - Bela Vista (Paulao, Torres, Pereira, Gariroba, Mato)'
UNION ALL SELECT 68, 'Pulverizacao', 'Massey Ferguson 275 n.01 (placa QDE4F82)', DATE '2026-11-09', 'Fungicida programado - Sede (todos os talhoes)'
UNION ALL SELECT 69, 'Pulverizacao', 'Valtra A750 n.02 (placa PXK7H19)', DATE '2026-11-10', 'Inseticida programado - Bela Vista (7 A, 7 B, Caixa Dagua, Tambor, Casa)'
UNION ALL SELECT 70, 'Pulverizacao', 'Drone DJI', DATE '2026-11-12', 'Foliar programada - Serra II (Douglas 48, 49, 50, 51 e Serra)'
) t
JOIN operacao o ON o.nome = t.operacao
JOIN aplicador a ON a.modelo = t.aplicador
JOIN aplicacao ap ON ap.id_operacao = o.id_operacao AND ap.id_aplicador = a.id_aplicador
                 AND ap.data_aplicacao = t.dt AND ap.observacao = t.obs
WHERE NOT EXISTS (SELECT 1 FROM registro_dados_ficticios r WHERE r.tabela = 'aplicacao' AND r.id_registro = ap.id_aplicacao);

INSERT INTO aplicacao_talhao (id_aplicacao, id_talhao)
SELECT r.id_registro, t.id_talhao
FROM (
SELECT 1 AS n, 'SEDE_A' AS bloco
UNION ALL SELECT 2, 'SEDE_B'
UNION ALL SELECT 3, 'BV_A1'
UNION ALL SELECT 4, 'BV_B'
UNION ALL SELECT 5, 'COR_A'
UNION ALL SELECT 6, 'COR_B'
UNION ALL SELECT 7, 'SEDE'
UNION ALL SELECT 8, 'BV_A'
UNION ALL SELECT 9, 'BV_B'
UNION ALL SELECT 10, 'COR_A'
UNION ALL SELECT 11, 'COR_B'
UNION ALL SELECT 12, 'SERRA2'
UNION ALL SELECT 13, 'SEDE'
UNION ALL SELECT 14, 'BV_A'
UNION ALL SELECT 15, 'SEDE'
UNION ALL SELECT 16, 'BV_B'
UNION ALL SELECT 17, 'COR_B'
UNION ALL SELECT 18, 'SERRA2'
UNION ALL SELECT 19, 'SEDE'
UNION ALL SELECT 20, 'SEDE'
UNION ALL SELECT 21, 'BV_A'
UNION ALL SELECT 22, 'BV_B'
UNION ALL SELECT 23, 'BV_A'
UNION ALL SELECT 24, 'BV_B'
UNION ALL SELECT 25, 'COR_A'
UNION ALL SELECT 26, 'COR_B'
UNION ALL SELECT 27, 'COR_A'
UNION ALL SELECT 28, 'SERRA2'
UNION ALL SELECT 29, 'SERRA2'
UNION ALL SELECT 30, 'SEDE'
UNION ALL SELECT 31, 'BV_A'
UNION ALL SELECT 32, 'SEDE'
UNION ALL SELECT 33, 'BV_B'
UNION ALL SELECT 34, 'BV_B'
UNION ALL SELECT 35, 'SEDE'
UNION ALL SELECT 36, 'BV_A'
UNION ALL SELECT 37, 'COR_B'
UNION ALL SELECT 38, 'SEDE'
UNION ALL SELECT 39, 'BV_B'
UNION ALL SELECT 40, 'COR_B'
UNION ALL SELECT 41, 'BV_B'
UNION ALL SELECT 42, 'COR_A'
UNION ALL SELECT 43, 'SERRA2'
UNION ALL SELECT 44, 'COR_A'
UNION ALL SELECT 45, 'SERRA2'
UNION ALL SELECT 46, 'SEDE'
UNION ALL SELECT 47, 'BV_A'
UNION ALL SELECT 48, 'SEDE'
UNION ALL SELECT 49, 'SEDE'
UNION ALL SELECT 50, 'BV_A'
UNION ALL SELECT 51, 'COR_B'
UNION ALL SELECT 52, 'SERRA2'
UNION ALL SELECT 53, 'COR_B'
UNION ALL SELECT 54, 'SEDE'
UNION ALL SELECT 55, 'BV_B'
UNION ALL SELECT 56, 'SERRA2'
UNION ALL SELECT 57, 'SEDE'
UNION ALL SELECT 58, 'BV_A'
UNION ALL SELECT 59, 'COR_B'
UNION ALL SELECT 60, 'SER_1'
UNION ALL SELECT 61, 'SEDE_A'
UNION ALL SELECT 62, 'BV_A2'
UNION ALL SELECT 63, 'SEDE'
UNION ALL SELECT 64, 'BV_A'
UNION ALL SELECT 65, 'SEDE_B'
UNION ALL SELECT 66, 'BV_B'
UNION ALL SELECT 67, 'BV_B'
UNION ALL SELECT 68, 'SEDE'
UNION ALL SELECT 69, 'BV_A'
UNION ALL SELECT 70, 'SERRA2'
) m
JOIN (
SELECT 'SEDE' AS bloco, 'Sede' AS area, 'Chico1' AS talhao
UNION ALL SELECT 'SEDE', 'Sede', 'Chico2'
UNION ALL SELECT 'SEDE', 'Sede', 'Pinheiro'
UNION ALL SELECT 'SEDE', 'Sede', 'Engenho'
UNION ALL SELECT 'SEDE', 'Sede', 'Cafe Velho'
UNION ALL SELECT 'SEDE_A', 'Sede', 'Chico1'
UNION ALL SELECT 'SEDE_A', 'Sede', 'Chico2'
UNION ALL SELECT 'SEDE_A', 'Sede', 'Pinheiro'
UNION ALL SELECT 'SEDE_B', 'Sede', 'Engenho'
UNION ALL SELECT 'SEDE_B', 'Sede', 'Cafe Velho'
UNION ALL SELECT 'BV_A', 'Bela Vista', '7 A (Cima)'
UNION ALL SELECT 'BV_A', 'Bela Vista', '7 B (Baixo)'
UNION ALL SELECT 'BV_A', 'Bela Vista', 'Caixa D''agua'
UNION ALL SELECT 'BV_A', 'Bela Vista', 'Tambor'
UNION ALL SELECT 'BV_A', 'Bela Vista', 'Casa'
UNION ALL SELECT 'BV_A1', 'Bela Vista', '7 A (Cima)'
UNION ALL SELECT 'BV_A1', 'Bela Vista', '7 B (Baixo)'
UNION ALL SELECT 'BV_A2', 'Bela Vista', 'Caixa D''agua'
UNION ALL SELECT 'BV_A2', 'Bela Vista', 'Tambor'
UNION ALL SELECT 'BV_A2', 'Bela Vista', 'Casa'
UNION ALL SELECT 'BV_B', 'Bela Vista', 'Paulao'
UNION ALL SELECT 'BV_B', 'Bela Vista', 'Torres'
UNION ALL SELECT 'BV_B', 'Bela Vista', 'Pereira'
UNION ALL SELECT 'BV_B', 'Bela Vista', 'Gariroba'
UNION ALL SELECT 'BV_B', 'Bela Vista', 'Mato'
UNION ALL SELECT 'COR_A', 'Corujas', 'Serra'
UNION ALL SELECT 'COR_A', 'Corujas', 'Ype'
UNION ALL SELECT 'COR_A', 'Corujas', 'Mangueira'
UNION ALL SELECT 'COR_B', 'Corujas', 'Ladeirinha'
UNION ALL SELECT 'COR_B', 'Corujas', 'Bananeira Roxa'
UNION ALL SELECT 'COR_B', 'Corujas', 'Caixa D''agua'
UNION ALL SELECT 'COR_B', 'Corujas', 'Peao'
UNION ALL SELECT 'COR_B', 'Corujas', 'Carlinho'
UNION ALL SELECT 'COR_B', 'Corujas', 'Jose Candido'
UNION ALL SELECT 'SERRA2', 'Serra II', 'Douglas 48'
UNION ALL SELECT 'SERRA2', 'Serra II', 'Douglas 49'
UNION ALL SELECT 'SERRA2', 'Serra II', 'Douglas 50'
UNION ALL SELECT 'SERRA2', 'Serra II', 'Douglas 51'
UNION ALL SELECT 'SERRA2', 'Serra II', 'Douglas Serra'
UNION ALL SELECT 'SER_1', 'Serra II', 'Douglas 48'
UNION ALL SELECT 'SER_1', 'Serra II', 'Douglas 49'
) b ON b.bloco = m.bloco
JOIN registro_dados_ficticios r ON r.tabela = 'aplicacao' AND r.ref = m.n
JOIN area ar ON ar.nome = b.area
JOIN talhao t ON t.id_area = ar.id_area AND t.nome = b.talhao
WHERE NOT EXISTS (SELECT 1 FROM aplicacao_talhao x WHERE x.id_aplicacao = r.id_registro AND x.id_talhao = t.id_talhao);

INSERT INTO aplicacao_insumo (id_aplicacao, id_insumo, dose_prevista, dose_realizada, unidade_dose)
SELECT r.id_registro, i.id_insumo, v.prevista, v.realizada, v.unidade
FROM (
SELECT 1 AS n, 'Roundup Original' AS insumo, 2.500 AS prevista, 2.479 AS realizada, 'L/ha' AS unidade
UNION ALL SELECT 1, 'Pledge', 0.150, 0.150, 'kg/ha'
UNION ALL SELECT 2, 'Roundup Original', 2.500, 2.568, 'L/ha'
UNION ALL SELECT 2, 'Pledge', 0.150, 0.153, 'kg/ha'
UNION ALL SELECT 3, 'Roundup Original', 2.500, 2.592, 'L/ha'
UNION ALL SELECT 3, 'Pledge', 0.150, 0.156, 'kg/ha'
UNION ALL SELECT 4, 'Roundup Original', 2.500, 2.551, 'L/ha'
UNION ALL SELECT 4, 'Pledge', 0.150, 0.153, 'kg/ha'
UNION ALL SELECT 5, 'Roundup Original', 2.500, 2.609, 'L/ha'
UNION ALL SELECT 5, 'Pledge', 0.150, 0.156, 'kg/ha'
UNION ALL SELECT 6, 'Roundup Original', 2.500, 2.876, 'L/ha'
UNION ALL SELECT 6, 'Pledge', 0.150, 0.173, 'kg/ha'
UNION ALL SELECT 7, 'NPK 20-05-20', 340.0, 338.1, 'kg/ha'
UNION ALL SELECT 8, 'NPK 20-05-20', 340.0, 344.6, 'kg/ha'
UNION ALL SELECT 9, 'NPK 20-05-20', 340.0, 326.9, 'kg/ha'
UNION ALL SELECT 10, 'NPK 20-05-20', 340.0, 341.5, 'kg/ha'
UNION ALL SELECT 11, 'NPK 20-05-20', 340.0, 346.8, 'kg/ha'
UNION ALL SELECT 12, 'NPK 20-05-20', 340.0, 343.0, 'kg/ha'
UNION ALL SELECT 13, 'Curbix SC200', 1.200, 1.272, 'L/ha'
UNION ALL SELECT 14, 'Curbix SC200', 1.200, 1.230, 'L/ha'
UNION ALL SELECT 15, 'Curbix SC200', 1.200, 1.240, 'L/ha'
UNION ALL SELECT 16, 'Curbix SC200', 1.200, 1.185, 'L/ha'
UNION ALL SELECT 17, 'Curbix SC200', 1.200, 1.260, 'L/ha'
UNION ALL SELECT 18, 'Curbix SC200', 1.200, 1.183, 'L/ha'
UNION ALL SELECT 19, 'Orkestra SC', 0.400, 0.387, 'L/ha'
UNION ALL SELECT 19, 'Supreme Mineral N1', 0.250, 0.237, 'L/ha'
UNION ALL SELECT 20, 'NPK 20-05-20', 300.0, 307.3, 'kg/ha'
UNION ALL SELECT 21, 'Orkestra SC', 0.400, 0.397, 'L/ha'
UNION ALL SELECT 21, 'Supreme Mineral N1', 0.250, 0.247, 'L/ha'
UNION ALL SELECT 22, 'Orkestra SC', 0.400, 0.455, 'L/ha'
UNION ALL SELECT 22, 'Supreme Mineral N1', 0.250, 0.289, 'L/ha'
UNION ALL SELECT 23, 'NPK 20-05-20', 300.0, 319.4, 'kg/ha'
UNION ALL SELECT 24, 'NPK 20-05-20', 300.0, 288.0, 'kg/ha'
UNION ALL SELECT 25, 'Orkestra SC', 0.400, 0.400, 'L/ha'
UNION ALL SELECT 25, 'Supreme Mineral N1', 0.250, 0.250, 'L/ha'
UNION ALL SELECT 26, 'NPK 20-05-20', 300.0, 296.1, 'kg/ha'
UNION ALL SELECT 27, 'Orkestra SC', 0.400, 0.406, 'L/ha'
UNION ALL SELECT 27, 'Supreme Mineral N1', 0.250, 0.250, 'L/ha'
UNION ALL SELECT 28, 'Orkestra SC', 0.400, 0.406, 'L/ha'
UNION ALL SELECT 28, 'Supreme Mineral N1', 0.250, 0.257, 'L/ha'
UNION ALL SELECT 29, 'NPK 20-05-20', 300.0, 297.7, 'kg/ha'
UNION ALL SELECT 30, 'Boro Super', 1.500, 1.683, 'L/ha'
UNION ALL SELECT 30, 'Maxi Zinc', 1.500, 1.702, 'L/ha'
UNION ALL SELECT 31, 'Boro Super', 1.500, 1.513, 'L/ha'
UNION ALL SELECT 31, 'Maxi Zinc', 1.500, 1.505, 'L/ha'
UNION ALL SELECT 32, 'Boro Super', 1.500, 1.508, 'L/ha'
UNION ALL SELECT 32, 'Maxi Zinc', 1.500, 1.503, 'L/ha'
UNION ALL SELECT 33, 'Boro Super', 1.500, 1.595, 'L/ha'
UNION ALL SELECT 33, 'Maxi Zinc', 1.500, 1.605, 'L/ha'
UNION ALL SELECT 34, 'Boro Super', 1.500, 1.465, 'L/ha'
UNION ALL SELECT 34, 'Maxi Zinc', 1.500, 1.463, 'L/ha'
UNION ALL SELECT 35, 'Melyra', 0.800, 0.876, 'L/ha'
UNION ALL SELECT 35, 'Supreme Mineral N1', 0.250, 0.275, 'L/ha'
UNION ALL SELECT 36, 'Melyra', 0.800, 0.821, 'L/ha'
UNION ALL SELECT 36, 'Supreme Mineral N1', 0.250, 0.256, 'L/ha'
UNION ALL SELECT 37, 'Boro Super', 1.500, 1.516, 'L/ha'
UNION ALL SELECT 37, 'Maxi Zinc', 1.500, 1.486, 'L/ha'
UNION ALL SELECT 38, 'Melyra', 0.800, 0.852, 'L/ha'
UNION ALL SELECT 38, 'Supreme Mineral N1', 0.250, 0.259, 'L/ha'
UNION ALL SELECT 39, 'Melyra', 0.800, 0.845, 'L/ha'
UNION ALL SELECT 39, 'Supreme Mineral N1', 0.250, 0.269, 'L/ha'
UNION ALL SELECT 40, 'Boro Super', 1.500, 1.504, 'L/ha'
UNION ALL SELECT 40, 'Maxi Zinc', 1.500, 1.518, 'L/ha'
UNION ALL SELECT 41, 'Melyra', 0.800, 0.864, 'L/ha'
UNION ALL SELECT 41, 'Supreme Mineral N1', 0.250, 0.279, 'L/ha'
UNION ALL SELECT 42, 'Melyra', 0.800, 0.779, 'L/ha'
UNION ALL SELECT 42, 'Supreme Mineral N1', 0.250, 0.246, 'L/ha'
UNION ALL SELECT 43, 'Melyra', 0.800, 0.838, 'L/ha'
UNION ALL SELECT 43, 'Supreme Mineral N1', 0.250, 0.258, 'L/ha'
UNION ALL SELECT 44, 'Melyra', 0.800, 0.805, 'L/ha'
UNION ALL SELECT 44, 'Supreme Mineral N1', 0.250, 0.251, 'L/ha'
UNION ALL SELECT 45, 'Melyra', 0.800, 0.789, 'L/ha'
UNION ALL SELECT 45, 'Supreme Mineral N1', 0.250, 0.248, 'L/ha'
UNION ALL SELECT 46, 'Spirit', 0.800, 0.806, 'L/ha'
UNION ALL SELECT 47, 'Spirit', 0.800, 0.785, 'L/ha'
UNION ALL SELECT 48, 'Spirit', 0.800, 0.823, 'L/ha'
UNION ALL SELECT 49, 'NPK 20-05-20', 260.0, 266.7, 'kg/ha'
UNION ALL SELECT 50, 'NPK 20-05-20', 260.0, 278.2, 'kg/ha'
UNION ALL SELECT 51, 'Spirit', 0.800, 0.779, 'L/ha'
UNION ALL SELECT 52, 'NPK 20-05-20', 260.0, 260.3, 'kg/ha'
UNION ALL SELECT 53, 'Spirit', 0.800, 0.778, 'L/ha'
UNION ALL SELECT 54, 'Valpura EC', 1.000, 1.034, 'L/ha'
UNION ALL SELECT 54, 'Supreme Mineral N1', 0.250, 0.252, 'L/ha'
UNION ALL SELECT 55, 'Valpura EC', 1.000, 1.008, 'L/ha'
UNION ALL SELECT 55, 'Supreme Mineral N1', 0.250, 0.252, 'L/ha'
UNION ALL SELECT 56, 'Valpura EC', 1.000, 0.984, 'L/ha'
UNION ALL SELECT 56, 'Supreme Mineral N1', 0.250, 0.244, 'L/ha'
UNION ALL SELECT 57, 'Alion SC500', 0.400, 0.421, 'L/ha'
UNION ALL SELECT 57, 'Roundup Original', 2.500, 2.610, 'L/ha'
UNION ALL SELECT 58, 'Alion SC500', 0.400, 0.414, 'L/ha'
UNION ALL SELECT 58, 'Roundup Original', 2.500, 2.668, 'L/ha'
UNION ALL SELECT 59, 'Alion SC500', 0.400, 0.445, 'L/ha'
UNION ALL SELECT 59, 'Roundup Original', 2.500, 2.727, 'L/ha'
UNION ALL SELECT 60, 'Alion SC500', 0.400, 0.465, 'L/ha'
UNION ALL SELECT 60, 'Roundup Original', 2.500, 2.921, 'L/ha'
UNION ALL SELECT 61, 'YaraLiva Nitrabo', 120.0, 127.1, 'kg/ha'
UNION ALL SELECT 62, 'Calcario dolomitico', 1500.0, 1442.6, 'kg/ha'
UNION ALL SELECT 63, 'Boro Super', 1.500, 1.623, 'L/ha'
UNION ALL SELECT 63, 'Ferriflo NG', 1.000, 1.068, 'L/ha'
UNION ALL SELECT 63, 'Blend Mg-Zn-B', 2.000, 2.163, 'L/ha'
UNION ALL SELECT 64, 'Boro Super', 1.500, 1.562, 'L/ha'
UNION ALL SELECT 64, 'Ferriflo NG', 1.000, 1.033, 'L/ha'
UNION ALL SELECT 64, 'Blend Mg-Zn-B', 2.000, 2.061, 'L/ha'
UNION ALL SELECT 65, 'Glufosinate Ammonium 200 G/L SL', 3.000, 3.060, 'L/ha'
UNION ALL SELECT 66, 'Glufosinate Ammonium 200 G/L SL', 3.000, 2.919, 'L/ha'
UNION ALL SELECT 67, 'Glufosinate Ammonium 200 G/L SL', 3.000, 3.053, 'L/ha'
UNION ALL SELECT 68, 'Orkestra SC', 0.400, NULL, 'L/ha'
UNION ALL SELECT 68, 'Supreme Mineral N1', 0.250, NULL, 'L/ha'
UNION ALL SELECT 69, 'Spirit', 0.800, NULL, 'L/ha'
UNION ALL SELECT 70, 'Boro Super', 1.500, NULL, 'L/ha'
UNION ALL SELECT 70, 'Maxi Zinc', 1.500, NULL, 'L/ha'
) v
JOIN registro_dados_ficticios r ON r.tabela = 'aplicacao' AND r.ref = v.n
JOIN insumo i ON i.nome = v.insumo
WHERE NOT EXISTS (SELECT 1 FROM aplicacao_insumo x WHERE x.id_aplicacao = r.id_registro AND x.id_insumo = i.id_insumo);

-- =====================  PARTE C - CONFERENCIA (ainda dentro da transacao)  =====================
-- Conta o que ficou gravado (guarda os numeros em @cf1..@cf15) e compara com o que este script devia criar.
SELECT
  (SELECT COUNT(*) FROM (
SELECT 'Bela Vista' AS area, '7 A (Cima)' AS nome
UNION ALL SELECT 'Bela Vista', '7 B (Baixo)'
UNION ALL SELECT 'Bela Vista', 'Caixa D''agua'
UNION ALL SELECT 'Bela Vista', 'Tambor'
UNION ALL SELECT 'Bela Vista', 'Casa'
UNION ALL SELECT 'Bela Vista', 'Paulao'
UNION ALL SELECT 'Bela Vista', 'Torres'
UNION ALL SELECT 'Bela Vista', 'Pereira'
UNION ALL SELECT 'Bela Vista', 'Gariroba'
UNION ALL SELECT 'Bela Vista', 'Mato'
UNION ALL SELECT 'Corujas', 'Serra'
UNION ALL SELECT 'Corujas', 'Ype'
UNION ALL SELECT 'Corujas', 'Mangueira'
UNION ALL SELECT 'Corujas', 'Ladeirinha'
UNION ALL SELECT 'Corujas', 'Bananeira Roxa'
UNION ALL SELECT 'Corujas', 'Caixa D''agua'
UNION ALL SELECT 'Corujas', 'Peao'
UNION ALL SELECT 'Corujas', 'Carlinho'
UNION ALL SELECT 'Corujas', 'Jose Candido'
UNION ALL SELECT 'Serra II', 'Douglas 48'
UNION ALL SELECT 'Serra II', 'Douglas 49'
UNION ALL SELECT 'Serra II', 'Douglas 50'
UNION ALL SELECT 'Serra II', 'Douglas 51'
UNION ALL SELECT 'Serra II', 'Douglas Serra'
) v JOIN area a ON a.nome = v.area JOIN talhao t ON t.id_area = a.id_area AND t.nome = v.nome),
  (SELECT COUNT(*) FROM aplicador x JOIN registro_dados_ficticios r ON r.tabela = 'aplicador' AND r.id_registro = x.id_aplicador),
  (SELECT COUNT(*) FROM insumo x JOIN registro_dados_ficticios r ON r.tabela = 'insumo' AND r.id_registro = x.id_insumo),
  (SELECT COUNT(*) FROM compra x JOIN registro_dados_ficticios r ON r.tabela = 'compra' AND r.id_registro = x.id_compra),
  (SELECT COUNT(*) FROM item_compra x JOIN registro_dados_ficticios r ON r.tabela = 'compra' AND r.id_registro = x.id_compra),
  (SELECT COUNT(*) FROM aplicacao x JOIN registro_dados_ficticios r ON r.tabela = 'aplicacao' AND r.id_registro = x.id_aplicacao),
  (SELECT COUNT(*) FROM aplicacao_talhao x JOIN registro_dados_ficticios r ON r.tabela = 'aplicacao' AND r.id_registro = x.id_aplicacao),
  (SELECT COUNT(*) FROM aplicacao_insumo x JOIN registro_dados_ficticios r ON r.tabela = 'aplicacao' AND r.id_registro = x.id_aplicacao),
  (SELECT (SELECT COUNT(*) FROM aplicacao WHERE observacao LIKE '[SIMULADO #%') + (SELECT COUNT(*) FROM compra WHERE numero_nota LIKE 'SIM-%') + (SELECT COUNT(*) FROM insumo WHERE marca = 'SIMULADO' OR nome LIKE '%(simulado)')),
  (SELECT COUNT(*) FROM (
SELECT 'Adubacao' AS nome
UNION ALL SELECT 'Pulverizacao'
) v JOIN operacao o ON o.nome = v.nome),
  (SELECT COUNT(*) FROM (
SELECT 'Sede' AS nome
UNION ALL SELECT 'Bela Vista'
UNION ALL SELECT 'Corujas'
UNION ALL SELECT 'Serra II'
) v JOIN area a ON a.nome = v.nome),
  (SELECT COUNT(*) FROM (
SELECT 'Chico1' AS nome
UNION ALL SELECT 'Chico2'
UNION ALL SELECT 'Pinheiro'
UNION ALL SELECT 'Engenho'
UNION ALL SELECT 'Cafe Velho'
) v JOIN area a ON a.nome = 'Sede' JOIN talhao t ON t.id_area = a.id_area AND t.nome = v.nome),
  (SELECT COUNT(*) FROM (
SELECT 'Bomba costal Jacto 1' AS nome
UNION ALL SELECT 'Bomba costal Jacto 2'
UNION ALL SELECT 'Bomba costal Jacto 4'
UNION ALL SELECT 'Bomba costal Jacto 5'
UNION ALL SELECT 'Bomba costal Jacto 6'
UNION ALL SELECT 'Bomba costal Jacto 7'
UNION ALL SELECT 'Bomba costal Jacto 8'
UNION ALL SELECT 'Drone DJI'
) v JOIN aplicador x ON x.modelo = v.nome),
  (SELECT COUNT(*) FROM (
SELECT 'Alion SC500' AS nome
UNION ALL SELECT 'Blend Mg-Zn-B'
UNION ALL SELECT 'Boro Super'
UNION ALL SELECT 'Curbix SC200'
UNION ALL SELECT 'Ferriflo NG'
UNION ALL SELECT 'Glufosinate Ammonium 200 G/L SL'
UNION ALL SELECT 'Maxi Zinc'
UNION ALL SELECT 'Melyra'
UNION ALL SELECT 'Orkestra SC'
UNION ALL SELECT 'Pledge'
UNION ALL SELECT 'Roundup Original'
UNION ALL SELECT 'Spirit'
UNION ALL SELECT 'Supreme Mineral N1'
UNION ALL SELECT 'Valpura EC'
UNION ALL SELECT 'YaraLiva Nitrabo'
) v JOIN insumo x ON x.nome = v.nome),
  (SELECT COUNT(*) FROM aplicacao a WHERE NOT EXISTS (SELECT 1 FROM aplicacao_talhao x WHERE x.id_aplicacao = a.id_aplicacao) OR NOT EXISTS (SELECT 1 FROM aplicacao_insumo y WHERE y.id_aplicacao = a.id_aplicacao))
  INTO @cf1, @cf2, @cf3, @cf4, @cf5, @cf6, @cf7, @cf8, @cf9, @cf10, @cf11, @cf12, @cf13, @cf14, @cf15
FROM DUAL;
-- Resultado da conferencia: todas as linhas OK. (A linha 'aplicacoes sem talhao ou insumo' so avisa: ATENCAO.)
SELECT item, encontrado, esperado, status FROM (
SELECT 1 AS o, 'talhoes dos mapas presentes' AS item, @cf1 AS encontrado, 24 AS esperado, IF(@cf1 = 24, 'OK', 'DIFERENTE') AS status
UNION ALL SELECT 2, 'aplicadores ficticios', @cf2, 5, IF(@cf2 = 5, 'OK', 'DIFERENTE')
UNION ALL SELECT 3, 'insumos ficticios', @cf3, 2, IF(@cf3 = 2, 'OK', 'DIFERENTE')
UNION ALL SELECT 4, 'compras ficticias', @cf4, 10, IF(@cf4 = 10, 'OK', 'DIFERENTE')
UNION ALL SELECT 5, 'itens dessas compras', @cf5, 26, IF(@cf5 = 26, 'OK', 'DIFERENTE')
UNION ALL SELECT 6, 'aplicacoes ficticias', @cf6, 70, IF(@cf6 = 70, 'OK', 'DIFERENTE')
UNION ALL SELECT 7, 'talhoes dessas aplicacoes', @cf7, 329, IF(@cf7 = 329, 'OK', 'DIFERENTE')
UNION ALL SELECT 8, 'insumos dessas aplicacoes', @cf8, 111, IF(@cf8 = 111, 'OK', 'DIFERENTE')
UNION ALL SELECT 9, 'etiquetas da versao antiga que sobraram', @cf9, 0, IF(@cf9 = 0, 'OK', 'DIFERENTE')
UNION ALL SELECT 10, 'operacoes usadas (Adubacao e Pulverizacao)', @cf10, 2, IF(@cf10 = 2, 'OK', 'DIFERENTE')
UNION ALL SELECT 11, 'areas da base presentes', @cf11, 4, IF(@cf11 = 4, 'OK', 'DIFERENTE')
UNION ALL SELECT 12, 'talhoes da Sede presentes', @cf12, 5, IF(@cf12 = 5, 'OK', 'DIFERENTE')
UNION ALL SELECT 13, 'aplicadores da base usados (drone e bombas)', @cf13, 8, IF(@cf13 = 8, 'OK', 'DIFERENTE')
UNION ALL SELECT 14, 'insumos reais usados', @cf14, 15, IF(@cf14 = 15, 'OK', 'DIFERENTE')
UNION ALL SELECT 15, 'aplicacoes sem talhao ou insumo (banco todo)', @cf15, 0, IF(@cf15 = 0, 'OK', 'ATENCAO')
) g ORDER BY o;

-- Decide: tudo OK = COMMIT; qualquer DIFERENTE = ROLLBACK (nada fica gravado pela metade).
SET @ok := IF(@cf1 = 24 AND @cf2 = 5 AND @cf3 = 2 AND @cf4 = 10 AND @cf5 = 26 AND @cf6 = 70 AND @cf7 = 329 AND @cf8 = 111 AND @cf9 = 0 AND @cf10 = 2 AND @cf11 = 4 AND @cf12 = 5 AND @cf13 = 8 AND @cf14 = 15, 1, 0);
SET @sql := IF(@ok = 1, 'COMMIT', 'ROLLBACK');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SELECT IF(@ok = 1, 'CARGA COMPLETA: tudo foi gravado.', 'CARGA INCOMPLETA: NADA foi gravado (ROLLBACK automatico). Veja as linhas DIFERENTE da conferencia e mande para mim.') AS resultado,
       DATABASE() AS banco, (SELECT COUNT(*) FROM aplicacao) AS aplicacoes_no_banco_agora;

-- Hectares por area (soma dos talhoes):
SELECT ar.nome AS area, COUNT(t.id_talhao) AS talhoes, SUM(t.hectares) AS hectares
FROM area ar LEFT JOIN talhao t ON t.id_area = ar.id_area GROUP BY ar.id_area, ar.nome ORDER BY ar.id_area;

-- NUMEROS PARA DIGITAR NO TERMINAL, calculados no SEU banco (id da operacao, do aplicador, dos
-- talhoes e dos insumos de cada um dos 10 exemplos). Todas as linhas OK. Se a lista do programa
-- mostrar outro numero para o mesmo nome, vale o desta tabela.
SELECT exemplo, id_operacao AS `id da operacao`, id_aplicador AS `id do aplicador`, ids_talhoes AS `ids dos talhoes`,
       ids_insumos AS `ids dos insumos (na ordem)`,
       IF(id_operacao NOT LIKE '%,%' AND id_aplicador NOT LIKE '%,%'
          AND LENGTH(ids_talhoes) - LENGTH(REPLACE(ids_talhoes, ',', '')) + 1 = n_talhoes
          AND LENGTH(ids_insumos) - LENGTH(REPLACE(ids_insumos, ',', '')) + 1 = n_insumos, 'OK', 'FALTA') AS status
FROM (
SELECT 1 AS exemplo, (SELECT GROUP_CONCAT(id_operacao) FROM operacao WHERE nome = 'Pulverizacao') AS id_operacao, (SELECT GROUP_CONCAT(id_aplicador) FROM aplicador WHERE modelo IN ('Drone DJI', 'DJI')) AS id_aplicador, (SELECT GROUP_CONCAT(t.id_talhao ORDER BY t.id_talhao) FROM talhao t JOIN area a ON a.id_area = t.id_area WHERE (a.nome, t.nome) IN (('Sede', 'Chico1'), ('Sede', 'Chico2'))) AS ids_talhoes, (SELECT GROUP_CONCAT(i.id_insumo ORDER BY FIELD(i.nome, 'Orkestra SC')) FROM insumo i WHERE i.nome IN ('Orkestra SC')) AS ids_insumos, 2 AS n_talhoes, 1 AS n_insumos
UNION ALL SELECT 2, (SELECT GROUP_CONCAT(id_operacao) FROM operacao WHERE nome = 'Pulverizacao'), (SELECT GROUP_CONCAT(id_aplicador) FROM aplicador WHERE modelo IN ('Massey Ferguson 275 n.01 (placa QDE4F82)')), (SELECT GROUP_CONCAT(t.id_talhao ORDER BY t.id_talhao) FROM talhao t JOIN area a ON a.id_area = t.id_area WHERE (a.nome, t.nome) IN (('Sede', 'Engenho'))), (SELECT GROUP_CONCAT(i.id_insumo ORDER BY FIELD(i.nome, 'Roundup Original')) FROM insumo i WHERE i.nome IN ('Roundup Original')), 1, 1
UNION ALL SELECT 3, (SELECT GROUP_CONCAT(id_operacao) FROM operacao WHERE nome = 'Pulverizacao'), (SELECT GROUP_CONCAT(id_aplicador) FROM aplicador WHERE modelo IN ('Bomba costal Jacto 3')), (SELECT GROUP_CONCAT(t.id_talhao ORDER BY t.id_talhao) FROM talhao t JOIN area a ON a.id_area = t.id_area WHERE (a.nome, t.nome) IN (('Corujas', 'Caixa D''agua'))), (SELECT GROUP_CONCAT(i.id_insumo ORDER BY FIELD(i.nome, 'Glufosinate Ammonium 200 G/L SL')) FROM insumo i WHERE i.nome IN ('Glufosinate Ammonium 200 G/L SL')), 1, 1
UNION ALL SELECT 4, (SELECT GROUP_CONCAT(id_operacao) FROM operacao WHERE nome = 'Pulverizacao'), (SELECT GROUP_CONCAT(id_aplicador) FROM aplicador WHERE modelo IN ('Drone DJI', 'DJI')), (SELECT GROUP_CONCAT(t.id_talhao ORDER BY t.id_talhao) FROM talhao t JOIN area a ON a.id_area = t.id_area WHERE (a.nome, t.nome) IN (('Bela Vista', 'Paulao'))), (SELECT GROUP_CONCAT(i.id_insumo ORDER BY FIELD(i.nome, 'Melyra', 'Supreme Mineral N1')) FROM insumo i WHERE i.nome IN ('Melyra', 'Supreme Mineral N1')), 1, 2
UNION ALL SELECT 5, (SELECT GROUP_CONCAT(id_operacao) FROM operacao WHERE nome = 'Pulverizacao'), (SELECT GROUP_CONCAT(id_aplicador) FROM aplicador WHERE modelo IN ('DJI Agras T40 (serie 3WHDX00C)')), (SELECT GROUP_CONCAT(t.id_talhao ORDER BY t.id_talhao) FROM talhao t JOIN area a ON a.id_area = t.id_area WHERE (a.nome, t.nome) IN (('Serra II', 'Douglas 50'))), (SELECT GROUP_CONCAT(i.id_insumo ORDER BY FIELD(i.nome, 'Spirit')) FROM insumo i WHERE i.nome IN ('Spirit')), 1, 1
UNION ALL SELECT 6, (SELECT GROUP_CONCAT(id_operacao) FROM operacao WHERE nome = 'Pulverizacao'), (SELECT GROUP_CONCAT(id_aplicador) FROM aplicador WHERE modelo IN ('Valtra A750 n.02 (placa PXK7H19)')), (SELECT GROUP_CONCAT(t.id_talhao ORDER BY t.id_talhao) FROM talhao t JOIN area a ON a.id_area = t.id_area WHERE (a.nome, t.nome) IN (('Bela Vista', '7 A (Cima)'), ('Bela Vista', '7 B (Baixo)'))), (SELECT GROUP_CONCAT(i.id_insumo ORDER BY FIELD(i.nome, 'Orkestra SC', 'Supreme Mineral N1', 'Boro Super')) FROM insumo i WHERE i.nome IN ('Orkestra SC', 'Supreme Mineral N1', 'Boro Super')), 2, 3
UNION ALL SELECT 7, (SELECT GROUP_CONCAT(id_operacao) FROM operacao WHERE nome = 'Adubacao'), (SELECT GROUP_CONCAT(id_aplicador) FROM aplicador WHERE modelo IN ('New Holland TL75E n.03 (placa MJB3C56)')), (SELECT GROUP_CONCAT(t.id_talhao ORDER BY t.id_talhao) FROM talhao t JOIN area a ON a.id_area = t.id_area WHERE (a.nome, t.nome) IN (('Sede', 'Chico1'), ('Sede', 'Chico2'), ('Sede', 'Pinheiro'))), (SELECT GROUP_CONCAT(i.id_insumo ORDER BY FIELD(i.nome, 'YaraLiva Nitrabo')) FROM insumo i WHERE i.nome IN ('YaraLiva Nitrabo')), 3, 1
UNION ALL SELECT 8, (SELECT GROUP_CONCAT(id_operacao) FROM operacao WHERE nome = 'Pulverizacao'), (SELECT GROUP_CONCAT(id_aplicador) FROM aplicador WHERE modelo IN ('Drone DJI', 'DJI')), (SELECT GROUP_CONCAT(t.id_talhao ORDER BY t.id_talhao) FROM talhao t JOIN area a ON a.id_area = t.id_area WHERE (a.nome, t.nome) IN (('Bela Vista', 'Torres'), ('Bela Vista', 'Pereira'))), (SELECT GROUP_CONCAT(i.id_insumo ORDER BY FIELD(i.nome, 'Valpura EC')) FROM insumo i WHERE i.nome IN ('Valpura EC')), 2, 1
UNION ALL SELECT 9, (SELECT GROUP_CONCAT(id_operacao) FROM operacao WHERE nome = 'Pulverizacao'), (SELECT GROUP_CONCAT(id_aplicador) FROM aplicador WHERE modelo IN ('Massey Ferguson 4275 n.04 (placa RTA9K07)')), (SELECT GROUP_CONCAT(t.id_talhao ORDER BY t.id_talhao) FROM talhao t JOIN area a ON a.id_area = t.id_area WHERE (a.nome, t.nome) IN (('Corujas', 'Ladeirinha'))), (SELECT GROUP_CONCAT(i.id_insumo ORDER BY FIELD(i.nome, 'Orkestra SC')) FROM insumo i WHERE i.nome IN ('Orkestra SC')), 1, 1
UNION ALL SELECT 10, (SELECT GROUP_CONCAT(id_operacao) FROM operacao WHERE nome = 'Pulverizacao'), (SELECT GROUP_CONCAT(id_aplicador) FROM aplicador WHERE modelo IN ('Drone DJI', 'DJI')), (SELECT GROUP_CONCAT(t.id_talhao ORDER BY t.id_talhao) FROM talhao t JOIN area a ON a.id_area = t.id_area WHERE (a.nome, t.nome) IN (('Bela Vista', 'Paulao'))), (SELECT GROUP_CONCAT(i.id_insumo ORDER BY FIELD(i.nome, 'Melyra', 'Supreme Mineral N1')) FROM insumo i WHERE i.nome IN ('Melyra', 'Supreme Mineral N1')), 1, 2
) x
ORDER BY exemplo;
