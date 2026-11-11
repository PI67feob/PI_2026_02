-- ============================================================
-- tudo_em_um.sql  -  recria o banco caderno_fazenda DO ZERO
-- Ordem: criar_banco -> 01 -> 02 -> 03 -> triggers
-- (o 04 do drone fica de fora: so rodar depois de conferir com o log)
--
-- ATENCAO: o primeiro passo faz DROP DATABASE e APAGA o banco inteiro.
-- Rode UMA vez, no MySQL 8.0.16 ou maior. Para rodar de novo, comece
-- do inicio (nao repita so uma parte: da erro 1062).
-- No Workbench: abra este arquivo e clique no raio SEM selecionar
-- nenhuma linha (executa o arquivo todo).
-- O 01 e RECONSTRUIDO (provisorio); veja o cabecalho dele.
-- ============================================================

-- >>>>>>>>>> PASSO: scripts_separados/criar_banco.sql <<<<<<<<<<
-- ============================================================
-- Banco da fazenda de cafe: criacao das tabelas (modelo fisico)
-- SGBD: MySQL 8 (a partir da 8.0.16, para os CHECK valerem)
-- Origem: docs/modelagem/der_completo.md (modelo logico)
-- Autor: Diogo Bordin | Data: 17/10/2026
--
-- Como usar no MySQL Workbench:
--   File > New Query Tab, colar este arquivo e executar tudo
--   (raio sem cursor ou Ctrl+Shift+Enter).
--
-- ATENCAO: o DROP DATABASE abaixo apaga o banco inteiro se ele ja
-- existir. Serve para recriar do zero durante o desenvolvimento.
-- Tire essa linha quando o banco tiver dados que importam.
-- ============================================================

DROP DATABASE IF EXISTS caderno_fazenda;

CREATE DATABASE caderno_fazenda
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE caderno_fazenda;

-- ------------------------------------------------------------
-- AREA: agrupa os talhoes (ex.: sede)
-- ------------------------------------------------------------
CREATE TABLE area (
    id_area    INT          NOT NULL AUTO_INCREMENT,
    nome       VARCHAR(100) NOT NULL,
    descricao  VARCHAR(255) NULL,

    CONSTRAINT pk_area PRIMARY KEY (id_area)
);

-- ------------------------------------------------------------
-- TALHAO: area (1) -> talhao (N). Nome unico so dentro da area.
-- ------------------------------------------------------------
CREATE TABLE talhao (
    id_talhao    INT           NOT NULL AUTO_INCREMENT,
    id_area      INT           NOT NULL,
    nome         VARCHAR(100)  NOT NULL,
    hectares     DECIMAL(10,2) NOT NULL,
    localizacao  VARCHAR(255)  NULL,

    CONSTRAINT pk_talhao PRIMARY KEY (id_talhao),
    CONSTRAINT uk_talhao_area_nome UNIQUE (id_area, nome),
    CONSTRAINT fk_talhao_area
        FOREIGN KEY (id_area) REFERENCES area (id_area),
    CONSTRAINT ck_talhao_hectares CHECK (hectares > 0)
);

-- ------------------------------------------------------------
-- OPERACAO: tipo de trabalho (pulverizacao, adubacao etc.)
-- ------------------------------------------------------------
CREATE TABLE operacao (
    id_operacao  INT          NOT NULL AUTO_INCREMENT,
    nome         VARCHAR(100) NOT NULL,
    descricao    VARCHAR(255) NULL,

    CONSTRAINT pk_operacao PRIMARY KEY (id_operacao),
    CONSTRAINT uk_operacao_nome UNIQUE (nome)
);

-- ------------------------------------------------------------
-- APLICADOR: trator, drone ou bomba costal.
-- Capacidade e o MAXIMO (em litros e em kg).
-- ------------------------------------------------------------
CREATE TABLE aplicador (
    id_aplicador           INT           NOT NULL AUTO_INCREMENT,
    modelo                 VARCHAR(100)  NOT NULL,
    tipo                   ENUM('trator', 'drone', 'bomba costal') NOT NULL,
    capacidade_max_litros  DECIMAL(10,2) NULL,
    capacidade_max_kg      DECIMAL(10,2) NULL,

    CONSTRAINT pk_aplicador PRIMARY KEY (id_aplicador),
    CONSTRAINT ck_aplicador_litros
        CHECK (capacidade_max_litros IS NULL OR capacidade_max_litros > 0),
    CONSTRAINT ck_aplicador_kg
        CHECK (capacidade_max_kg IS NULL OR capacidade_max_kg > 0)
);

-- ------------------------------------------------------------
-- INSUMO: nome, marca e tipo. SEM unidade de medida
-- (a unidade fica em item_compra).
-- ------------------------------------------------------------
CREATE TABLE insumo (
    id_insumo  INT          NOT NULL AUTO_INCREMENT,
    nome       VARCHAR(150) NOT NULL,
    marca      VARCHAR(100) NULL,
    tipo       VARCHAR(80)  NOT NULL,

    CONSTRAINT pk_insumo PRIMARY KEY (id_insumo)
);

-- ------------------------------------------------------------
-- APLICACAO: um aplicador por aplicacao (pendencia dos dois
-- equipamentos em aberto, ver der_completo.md).
-- ------------------------------------------------------------
CREATE TABLE aplicacao (
    id_aplicacao    INT          NOT NULL AUTO_INCREMENT,
    id_operacao     INT          NOT NULL,
    id_aplicador    INT          NOT NULL,
    data_aplicacao  DATE         NOT NULL,
    observacao      VARCHAR(255) NULL,

    CONSTRAINT pk_aplicacao PRIMARY KEY (id_aplicacao),
    CONSTRAINT fk_aplicacao_operacao
        FOREIGN KEY (id_operacao) REFERENCES operacao (id_operacao),
    CONSTRAINT fk_aplicacao_aplicador
        FOREIGN KEY (id_aplicador) REFERENCES aplicador (id_aplicador)
);

-- ------------------------------------------------------------
-- APLICACAO_TALHAO: N:N entre aplicacao e talhao.
-- A regra "toda aplicacao tem ao menos um talhao" fica na
-- aplicacao, o banco so garante as chaves estrangeiras.
-- ------------------------------------------------------------
CREATE TABLE aplicacao_talhao (
    id_aplicacao  INT NOT NULL,
    id_talhao     INT NOT NULL,

    CONSTRAINT pk_aplicacao_talhao PRIMARY KEY (id_aplicacao, id_talhao),
    CONSTRAINT fk_aptalhao_aplicacao
        FOREIGN KEY (id_aplicacao) REFERENCES aplicacao (id_aplicacao)
        ON DELETE CASCADE,
    CONSTRAINT fk_aptalhao_talhao
        FOREIGN KEY (id_talhao) REFERENCES talhao (id_talhao)
);

-- ------------------------------------------------------------
-- APLICACAO_INSUMO: N:N entre aplicacao e insumo, com a dose.
-- Unidade da dose: L/ha (liquido) ou kg/ha (solido).
-- dose_realizada pode ficar vazia ate a aplicacao ser feita.
-- ------------------------------------------------------------
CREATE TABLE aplicacao_insumo (
    id_aplicacao    INT           NOT NULL,
    id_insumo       INT           NOT NULL,
    dose_prevista   DECIMAL(10,3) NOT NULL,
    dose_realizada  DECIMAL(10,3) NULL,
    unidade_dose    ENUM('L/ha', 'kg/ha') NOT NULL,

    CONSTRAINT pk_aplicacao_insumo PRIMARY KEY (id_aplicacao, id_insumo),
    CONSTRAINT fk_apinsumo_aplicacao
        FOREIGN KEY (id_aplicacao) REFERENCES aplicacao (id_aplicacao)
        ON DELETE CASCADE,
    CONSTRAINT fk_apinsumo_insumo
        FOREIGN KEY (id_insumo) REFERENCES insumo (id_insumo),
    CONSTRAINT ck_apinsumo_prevista CHECK (dose_prevista >= 0),
    CONSTRAINT ck_apinsumo_realizada
        CHECK (dose_realizada IS NULL OR dose_realizada >= 0)
);

-- ------------------------------------------------------------
-- COMPRA: cabecalho da compra de insumos
-- ------------------------------------------------------------
CREATE TABLE compra (
    id_compra    INT         NOT NULL AUTO_INCREMENT,
    data_compra  DATE        NOT NULL,
    numero_nota  VARCHAR(50) NULL,

    CONSTRAINT pk_compra PRIMARY KEY (id_compra)
);

-- ------------------------------------------------------------
-- ITEM_COMPRA: quantidade, unidade de medida e preco unitario
-- (opcional). A mesma compra pode ter duas linhas do mesmo
-- insumo, por isso nao ha UNIQUE em (id_compra, id_insumo).
-- ------------------------------------------------------------
CREATE TABLE item_compra (
    id_item_compra  INT           NOT NULL AUTO_INCREMENT,
    id_compra       INT           NOT NULL,
    id_insumo       INT           NOT NULL,
    quantidade      DECIMAL(12,3) NOT NULL,
    unidade_medida  ENUM('litro', 'galão', 'kg', 'grama', 'tonelada', 'unidade') NOT NULL,
    preco_unitario  DECIMAL(12,2) NULL,

    CONSTRAINT pk_item_compra PRIMARY KEY (id_item_compra),
    CONSTRAINT fk_itemcompra_compra
        FOREIGN KEY (id_compra) REFERENCES compra (id_compra)
        ON DELETE CASCADE,
    CONSTRAINT fk_itemcompra_insumo
        FOREIGN KEY (id_insumo) REFERENCES insumo (id_insumo),
    CONSTRAINT ck_itemcompra_quantidade CHECK (quantidade > 0),
    CONSTRAINT ck_itemcompra_preco
        CHECK (preco_unitario IS NULL OR preco_unitario >= 0)
);

-- ------------------------------------------------------------
-- HISTORICO_ALTERACOES: tabela tecnica de auditoria (nao e
-- entidade do negocio, sem chave estrangeira). Os triggers de
-- auditoria vao preencher esta tabela.
-- ------------------------------------------------------------
CREATE TABLE historico_alteracoes (
    id_historico     BIGINT       NOT NULL AUTO_INCREMENT,
    tabela_afetada   VARCHAR(64)  NOT NULL,
    chave_registro   VARCHAR(100) NOT NULL,
    acao             ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    dados_anteriores JSON         NULL,
    dados_novos      JSON         NULL,
    usuario          VARCHAR(100) NOT NULL,
    data_hora        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_historico_alteracoes PRIMARY KEY (id_historico)
);


-- >>>>>>>>>> PASSO: scripts_separados/seeds/01_base_RECONSTRUIDO.sql <<<<<<<<<<
-- ============================================================
-- seeds/01_base_RECONSTRUIDO.sql   (PROVISORIO)
-- O 01_base.sql oficial do Bruno nunca chegou ao Diogo. Este arquivo foi
-- montado para o banco poder ser recriado do zero. QUANDO O BRUNO MANDAR
-- O DELE, compare e troque.
--
-- De onde vem cada dado:
--   * nomes dos 43 insumos e dos 11 aplicadores: dados de teste do codigo
--     Dart da equipe (historico de 02/09). Drone 70 L e bomba costal 20 L
--     tambem vem dessa fonte.
--   * 5 talhoes e hectares (soma 19,95 ha): descricao do Bruno.
-- SEM FONTE (conferir com o Bruno e o Joao):
--   * insumo.tipo: 'Insumo' e so um valor provisorio (a coluna e obrigatoria).
--   * capacidade em kg dos aplicadores (70 e 20): igual aos litros.
--   * insumo.marca: vazia, nenhuma fonte tem.
-- Os ids dos insumos (1 a 43, nesta ordem) sao usados pelo 03_compras.sql.
-- Rodar UMA vez, em banco vazio, depois do criar_banco.sql.
-- ============================================================
USE caderno_fazenda;

INSERT INTO area (id_area, nome) VALUES (1, 'Sede');

INSERT INTO talhao (id_area,nome,hectares) VALUES
  (1,'Chico1',2.80),
  (1,'Chico2',3.80),
  (1,'Pinheiro',2.05),
  (1,'Engenho',4.90),
  (1,'Cafe Velho',6.40);
INSERT INTO aplicador (id_aplicador,modelo,tipo,capacidade_max_litros,capacidade_max_kg) VALUES
  (1,'Drone DJI','drone',70,70),
  (2,'Bomba costal Jacto 1','bomba costal',20,20),
  (3,'Bomba costal Jacto 2','bomba costal',20,20),
  (4,'Bomba costal Jacto 3','bomba costal',20,20),
  (5,'Bomba costal Jacto 4','bomba costal',20,20),
  (6,'Bomba costal Jacto 5','bomba costal',20,20),
  (7,'Bomba costal Jacto 6','bomba costal',20,20),
  (8,'Bomba costal Jacto 7','bomba costal',20,20),
  (9,'Bomba costal Jacto 8','bomba costal',20,20),
  (10,'Bomba costal Jacto 9','bomba costal',20,20),
  (11,'Bomba costal Jacto 10','bomba costal',20,20);
INSERT INTO insumo (id_insumo,nome,tipo) VALUES
  (1,'BioKiller','Insumo'),
  (2,'Ammoles','Insumo'),
  (3,'Acanne','Insumo'),
  (4,'Polme','Insumo'),
  (5,'Alfol Calcio','Insumo'),
  (6,'Alfol Boro','Insumo'),
  (7,'Coda Best','Insumo'),
  (8,'Coda Eros','Insumo'),
  (9,'Coda Drip','Insumo'),
  (10,'Coda Harmony','Insumo'),
  (11,'Coda Spill','Insumo'),
  (12,'Valuva','Insumo'),
  (13,'Orkestra SC','Insumo'),
  (14,'Alion SC500','Insumo'),
  (15,'Galigan','Insumo'),
  (16,'Glucare','Insumo'),
  (17,'Glufosinate Ammonium 200 G/L SL','Insumo'),
  (18,'Grasidim','Insumo'),
  (19,'Tremor','Insumo'),
  (20,'Zartan','Insumo'),
  (21,'Melyra','Insumo'),
  (22,'Opera','Insumo'),
  (23,'Valpura EC','Insumo'),
  (24,'Curbix SC200','Insumo'),
  (25,'Fastac','Insumo'),
  (26,'Nomolt','Insumo'),
  (27,'Premier Plus SC','Insumo'),
  (28,'Verango Prime SC500','Insumo'),
  (29,'Supreme Mineral N1','Insumo'),
  (30,'Reforce Ultra','Insumo'),
  (31,'YaraLiva Nitrabo','Insumo'),
  (32,'Blend Mg-Zn-B','Insumo'),
  (33,'Transfer UP','Insumo'),
  (34,'Cal Super','Insumo'),
  (35,'Boro Super','Insumo'),
  (36,'Ferriflo NG','Insumo'),
  (37,'Maxi Zinc','Insumo'),
  (38,'Pledge','Insumo'),
  (39,'Poquer','Insumo'),
  (40,'Roundup Original','Insumo'),
  (41,'Crop Best','Insumo'),
  (42,'Crop Exit S','Insumo'),
  (43,'Spirit','Insumo');


-- >>>>>>>>>> PASSO: scripts_separados/seeds/02_areas_operacoes.sql <<<<<<<<<<
-- ============================================================
-- banco/seeds/02_areas_operacoes.sql
-- Fonte: dados-produtividade.csv, dados-poda.csv, dados-aplicacoes-drone.csv
-- (acervo de auditoria). Rodar depois do 01_base.sql.
-- A area Sede (id 1) ja vem no 01_base.sql; aqui entram as outras 3.
-- Sem coordenadas, CNPJ, valores comerciais ou dados pessoais.
-- ============================================================
USE caderno_fazenda;

INSERT INTO area (id_area, nome, descricao) VALUES
  (2, 'Bela Vista', 'Area de producao de 60,00 ha (estimativa 2026); talhoes ainda nao cadastrados'),
  (3, 'Corujas',    'Area de producao de 31,98 ha (estimativa 2026); talhoes ainda nao cadastrados'),
  (4, 'Serra II',   'Area de producao de 30,60 ha (estimativa 2026); talhoes ainda nao cadastrados');

-- A Sede tem 5 talhoes que somam 19,95 ha, igual a area de producao da estimativa 2026.
UPDATE area SET descricao = 'Area de producao de 19,95 ha (estimativa 2026); soma dos 5 talhoes cadastrados'
 WHERE id_area = 1;

INSERT INTO operacao (id_operacao, nome, descricao) VALUES
  (1, 'Adubacao',     'Aplicacao de fertilizante'),
  (2, 'Pulverizacao', 'Aplicacao de defensivo ou foliar em calda');


-- >>>>>>>>>> PASSO: scripts_separados/seeds/03_compras.sql <<<<<<<<<<
-- ============================================================
-- banco/seeds/03_compras.sql
-- Fonte: indice de notas fiscais (docs/check_inicial/samuel/indice-documentos.csv),
-- notas NF-e de insumos agricolas. DADOS REAIS da fazenda.
-- Entram: data da nota, numero da nota, insumo, quantidade e unidade.
-- NAO entram (de proposito): preco, valor total, fornecedor, CNPJ.
-- Fora do script, de proposito:
--   * NF 420.755 (Opera, 150 L) e a devolucao NF 431.039: se anulam.
--   * NF 68.635 e 68.700: entregas da venda futura NF 68.606 (100 L),
--     que ja esta aqui uma vez; carregar as tres contaria o dobro.
--   * Boletos, receitas, certificados, mudas, EPI e servicos (nao sao insumo
--     de aplicacao).
-- Rodar depois do 01_base.sql (usa os ids de insumo de la).
-- ============================================================
USE caderno_fazenda;

INSERT INTO compra (id_compra, data_compra, numero_nota) VALUES
  (1, '2025-04-25', '3257'),
  (2, '2025-10-03', '4591'),
  (3, '2025-12-02', '5685'),
  (4, '2026-01-05', '6060'),
  (5, '2026-01-08', '418604'),
  (6, '2026-01-14', '419201'),
  (7, '2026-02-06', '6391'),
  (8, '2026-02-10', '68606'),
  (9, '2026-03-16', '424602'),
  (10, '2026-03-17', '6671'),
  (11, '2026-03-25', '6749'),
  (12, '2026-04-08', '6855'),
  (13, '2026-04-16', '6916'),
  (14, '2026-06-15', '432029'),
  (15, '2026-07-17', '388564'),
  (16, '2026-07-20', '388650'),
  (17, '2026-07-20', '7236'),
  (18, '2026-07-30', '7292');

INSERT INTO item_compra (id_compra, id_insumo, quantidade, unidade_medida) VALUES
  (1, 14, 20, 'litro'),  -- Alion SC500
  (1, 27, 640, 'litro'),  -- Premier Plus SC
  (1, 28, 80, 'litro'),  -- Verango Prime SC500
  (2, 28, 60, 'litro'),  -- Verango Prime SC500
  (3, 32, 15, 'litro'),  -- Blend Mg-Zn-B
  (3, 24, 240, 'litro'),  -- Curbix SC200
  (4, 17, 100, 'litro'),  -- Glufosinate Ammonium 200 G/L SL
  (4, 18, 40, 'litro'),  -- Grasidim
  (4, 16, 20, 'litro'),  -- Glucare
  (4, 19, 3, 'litro'),  -- Tremor
  (4, 29, 20, 'litro'),  -- Supreme Mineral N1
  (5, 15, 20, 'litro'),  -- Galigan
  (6, 20, 200, 'grama'),  -- Zartan
  (7, 24, 240, 'litro'),  -- Curbix SC200
  (7, 23, 145, 'litro'),  -- Valpura EC
  (8, 21, 100, 'litro'),  -- Melyra
  (9, 15, 20, 'litro'),  -- Galigan
  (10, 16, 120, 'litro'),  -- Glucare
  (10, 18, 20, 'litro'),  -- Grasidim
  (10, 19, 15, 'litro'),  -- Tremor
  (10, 29, 40, 'litro'),  -- Supreme Mineral N1
  (11, 16, 100, 'litro'),  -- Glucare
  (11, 18, 40, 'litro'),  -- Grasidim
  (11, 19, 6, 'litro'),  -- Tremor
  (11, 29, 60, 'litro'),  -- Supreme Mineral N1
  (12, 16, 100, 'litro'),  -- Glucare
  (12, 18, 40, 'litro'),  -- Grasidim
  (12, 19, 4, 'litro'),  -- Tremor
  (12, 29, 40, 'litro'),  -- Supreme Mineral N1
  (13, 16, 20, 'litro'),  -- Glucare
  (13, 18, 20, 'litro'),  -- Grasidim
  (13, 19, 1, 'litro'),  -- Tremor
  (13, 29, 20, 'litro'),  -- Supreme Mineral N1
  (14, 25, 1, 'litro'),  -- Fastac
  (14, 26, 1, 'litro'),  -- Nomolt
  (15, 31, 250, 'kg'),  -- YaraLiva Nitrabo
  (16, 31, 750, 'kg'),  -- YaraLiva Nitrabo
  (17, 33, 10, 'litro'),  -- Transfer UP
  (18, 30, 5, 'litro'),  -- Reforce Ultra
  (18, 36, 5, 'litro'),  -- Ferriflo NG
  (18, 34, 10, 'litro'),  -- Cal Super
  (18, 35, 2, 'litro'),  -- Boro Super
  (18, 37, 1, 'litro');  -- Maxi Zinc


-- >>>>>>>>>> PASSO: scripts_separados/triggers.sql <<<<<<<<<<
-- ============================================================
-- banco/triggers.sql
-- Triggers de auditoria e de imutabilidade do historico.
--
-- QUANDO RODAR: DEPOIS do schema (criar_banco.sql) e dos seeds. Assim a carga
-- inicial nao enche o historico_alteracoes.
--
-- O QUE CRIA (14 triggers):
--   * 12 de auditoria (AFTER INSERT / UPDATE / DELETE) em
--     aplicacao, aplicacao_insumo, aplicacao_talhao e insumo.
--     Padrao de nome: trg_<tabela>_ai, trg_<tabela>_au, trg_<tabela>_ad.
--   * 2 de imutabilidade (BEFORE UPDATE / DELETE) em
--     historico_alteracoes: trg_historico_alteracoes_bu e _bd.
--
-- REGRAS:
--   * O usuario gravado vem de USER(), e NAO de CURRENT_USER().
--     Dentro de um trigger, CURRENT_USER() devolve quem CRIOU o
--     trigger (root) e toda linha diria "root". USER() devolve quem
--     realmente se conectou.
--   * Nas tabelas de ligacao, chave_registro e o id da aplicacao.
--     O id do insumo ou do talhao fica no JSON.
--   * INSERT: dados_anteriores = NULL. DELETE: dados_novos = NULL.
--   * Sem DEFINER de proposito: o MySQL usa quem roda o script.
--     Com DEFINER, o mesmo arquivo da erro 1449 no computador de
--     quem usa outro usuario administrador.
--   * Pode rodar de novo: cada trigger e recriado (DROP IF EXISTS).
--
-- COLUNAS USADAS EM historico_alteracoes:
--   tabela_afetada, chave_registro, acao, dados_anteriores,
--   dados_novos, usuario, data_hora
--   Se o schema (criar_banco.sql) tiver outros nomes, avise antes de mudar: a
--   alteracao e nos 12 triggers.
--
-- Se mudar o nome de uma coluna ou tabela auditada, os triggers
-- quebram. Mudanca de schema passa primeiro pelo Bruno e pelo .mwb.
-- ============================================================

USE caderno_fazenda;

DELIMITER $$

-- ------------------------------------------------------------
-- AUDITORIA (12 triggers)
-- ------------------------------------------------------------

-- aplicacao

DROP TRIGGER IF EXISTS trg_aplicacao_ai$$
CREATE TRIGGER trg_aplicacao_ai
AFTER INSERT ON aplicacao
FOR EACH ROW
BEGIN
    INSERT INTO historico_alteracoes
        (tabela_afetada, chave_registro, acao, dados_anteriores, dados_novos, usuario, data_hora)
    VALUES (
        'aplicacao',
        NEW.id_aplicacao,
        'INSERT',
        NULL,
        JSON_OBJECT(
            'id_aplicacao', NEW.id_aplicacao,
            'id_operacao', NEW.id_operacao,
            'id_aplicador', NEW.id_aplicador,
            'data_aplicacao', NEW.data_aplicacao,
            'observacao', NEW.observacao
        ),
        USER(),
        NOW()
    );
END$$

DROP TRIGGER IF EXISTS trg_aplicacao_au$$
CREATE TRIGGER trg_aplicacao_au
AFTER UPDATE ON aplicacao
FOR EACH ROW
BEGIN
    INSERT INTO historico_alteracoes
        (tabela_afetada, chave_registro, acao, dados_anteriores, dados_novos, usuario, data_hora)
    VALUES (
        'aplicacao',
        NEW.id_aplicacao,
        'UPDATE',
        JSON_OBJECT(
            'id_aplicacao', OLD.id_aplicacao,
            'id_operacao', OLD.id_operacao,
            'id_aplicador', OLD.id_aplicador,
            'data_aplicacao', OLD.data_aplicacao,
            'observacao', OLD.observacao
        ),
        JSON_OBJECT(
            'id_aplicacao', NEW.id_aplicacao,
            'id_operacao', NEW.id_operacao,
            'id_aplicador', NEW.id_aplicador,
            'data_aplicacao', NEW.data_aplicacao,
            'observacao', NEW.observacao
        ),
        USER(),
        NOW()
    );
END$$

DROP TRIGGER IF EXISTS trg_aplicacao_ad$$
CREATE TRIGGER trg_aplicacao_ad
AFTER DELETE ON aplicacao
FOR EACH ROW
BEGIN
    INSERT INTO historico_alteracoes
        (tabela_afetada, chave_registro, acao, dados_anteriores, dados_novos, usuario, data_hora)
    VALUES (
        'aplicacao',
        OLD.id_aplicacao,
        'DELETE',
        JSON_OBJECT(
            'id_aplicacao', OLD.id_aplicacao,
            'id_operacao', OLD.id_operacao,
            'id_aplicador', OLD.id_aplicador,
            'data_aplicacao', OLD.data_aplicacao,
            'observacao', OLD.observacao
        ),
        NULL,
        USER(),
        NOW()
    );
END$$

-- aplicacao_insumo

DROP TRIGGER IF EXISTS trg_aplicacao_insumo_ai$$
CREATE TRIGGER trg_aplicacao_insumo_ai
AFTER INSERT ON aplicacao_insumo
FOR EACH ROW
BEGIN
    INSERT INTO historico_alteracoes
        (tabela_afetada, chave_registro, acao, dados_anteriores, dados_novos, usuario, data_hora)
    VALUES (
        'aplicacao_insumo',
        NEW.id_aplicacao,
        'INSERT',
        NULL,
        JSON_OBJECT(
            'id_aplicacao', NEW.id_aplicacao,
            'id_insumo', NEW.id_insumo,
            'dose_prevista', NEW.dose_prevista,
            'dose_realizada', NEW.dose_realizada,
            'unidade_dose', NEW.unidade_dose
        ),
        USER(),
        NOW()
    );
END$$

DROP TRIGGER IF EXISTS trg_aplicacao_insumo_au$$
CREATE TRIGGER trg_aplicacao_insumo_au
AFTER UPDATE ON aplicacao_insumo
FOR EACH ROW
BEGIN
    INSERT INTO historico_alteracoes
        (tabela_afetada, chave_registro, acao, dados_anteriores, dados_novos, usuario, data_hora)
    VALUES (
        'aplicacao_insumo',
        NEW.id_aplicacao,
        'UPDATE',
        JSON_OBJECT(
            'id_aplicacao', OLD.id_aplicacao,
            'id_insumo', OLD.id_insumo,
            'dose_prevista', OLD.dose_prevista,
            'dose_realizada', OLD.dose_realizada,
            'unidade_dose', OLD.unidade_dose
        ),
        JSON_OBJECT(
            'id_aplicacao', NEW.id_aplicacao,
            'id_insumo', NEW.id_insumo,
            'dose_prevista', NEW.dose_prevista,
            'dose_realizada', NEW.dose_realizada,
            'unidade_dose', NEW.unidade_dose
        ),
        USER(),
        NOW()
    );
END$$

DROP TRIGGER IF EXISTS trg_aplicacao_insumo_ad$$
CREATE TRIGGER trg_aplicacao_insumo_ad
AFTER DELETE ON aplicacao_insumo
FOR EACH ROW
BEGIN
    INSERT INTO historico_alteracoes
        (tabela_afetada, chave_registro, acao, dados_anteriores, dados_novos, usuario, data_hora)
    VALUES (
        'aplicacao_insumo',
        OLD.id_aplicacao,
        'DELETE',
        JSON_OBJECT(
            'id_aplicacao', OLD.id_aplicacao,
            'id_insumo', OLD.id_insumo,
            'dose_prevista', OLD.dose_prevista,
            'dose_realizada', OLD.dose_realizada,
            'unidade_dose', OLD.unidade_dose
        ),
        NULL,
        USER(),
        NOW()
    );
END$$

-- aplicacao_talhao

DROP TRIGGER IF EXISTS trg_aplicacao_talhao_ai$$
CREATE TRIGGER trg_aplicacao_talhao_ai
AFTER INSERT ON aplicacao_talhao
FOR EACH ROW
BEGIN
    INSERT INTO historico_alteracoes
        (tabela_afetada, chave_registro, acao, dados_anteriores, dados_novos, usuario, data_hora)
    VALUES (
        'aplicacao_talhao',
        NEW.id_aplicacao,
        'INSERT',
        NULL,
        JSON_OBJECT(
            'id_aplicacao', NEW.id_aplicacao,
            'id_talhao', NEW.id_talhao
        ),
        USER(),
        NOW()
    );
END$$

DROP TRIGGER IF EXISTS trg_aplicacao_talhao_au$$
CREATE TRIGGER trg_aplicacao_talhao_au
AFTER UPDATE ON aplicacao_talhao
FOR EACH ROW
BEGIN
    INSERT INTO historico_alteracoes
        (tabela_afetada, chave_registro, acao, dados_anteriores, dados_novos, usuario, data_hora)
    VALUES (
        'aplicacao_talhao',
        NEW.id_aplicacao,
        'UPDATE',
        JSON_OBJECT(
            'id_aplicacao', OLD.id_aplicacao,
            'id_talhao', OLD.id_talhao
        ),
        JSON_OBJECT(
            'id_aplicacao', NEW.id_aplicacao,
            'id_talhao', NEW.id_talhao
        ),
        USER(),
        NOW()
    );
END$$

DROP TRIGGER IF EXISTS trg_aplicacao_talhao_ad$$
CREATE TRIGGER trg_aplicacao_talhao_ad
AFTER DELETE ON aplicacao_talhao
FOR EACH ROW
BEGIN
    INSERT INTO historico_alteracoes
        (tabela_afetada, chave_registro, acao, dados_anteriores, dados_novos, usuario, data_hora)
    VALUES (
        'aplicacao_talhao',
        OLD.id_aplicacao,
        'DELETE',
        JSON_OBJECT(
            'id_aplicacao', OLD.id_aplicacao,
            'id_talhao', OLD.id_talhao
        ),
        NULL,
        USER(),
        NOW()
    );
END$$

-- insumo

DROP TRIGGER IF EXISTS trg_insumo_ai$$
CREATE TRIGGER trg_insumo_ai
AFTER INSERT ON insumo
FOR EACH ROW
BEGIN
    INSERT INTO historico_alteracoes
        (tabela_afetada, chave_registro, acao, dados_anteriores, dados_novos, usuario, data_hora)
    VALUES (
        'insumo',
        NEW.id_insumo,
        'INSERT',
        NULL,
        JSON_OBJECT(
            'id_insumo', NEW.id_insumo,
            'nome', NEW.nome,
            'marca', NEW.marca,
            'tipo', NEW.tipo
        ),
        USER(),
        NOW()
    );
END$$

DROP TRIGGER IF EXISTS trg_insumo_au$$
CREATE TRIGGER trg_insumo_au
AFTER UPDATE ON insumo
FOR EACH ROW
BEGIN
    INSERT INTO historico_alteracoes
        (tabela_afetada, chave_registro, acao, dados_anteriores, dados_novos, usuario, data_hora)
    VALUES (
        'insumo',
        NEW.id_insumo,
        'UPDATE',
        JSON_OBJECT(
            'id_insumo', OLD.id_insumo,
            'nome', OLD.nome,
            'marca', OLD.marca,
            'tipo', OLD.tipo
        ),
        JSON_OBJECT(
            'id_insumo', NEW.id_insumo,
            'nome', NEW.nome,
            'marca', NEW.marca,
            'tipo', NEW.tipo
        ),
        USER(),
        NOW()
    );
END$$

DROP TRIGGER IF EXISTS trg_insumo_ad$$
CREATE TRIGGER trg_insumo_ad
AFTER DELETE ON insumo
FOR EACH ROW
BEGIN
    INSERT INTO historico_alteracoes
        (tabela_afetada, chave_registro, acao, dados_anteriores, dados_novos, usuario, data_hora)
    VALUES (
        'insumo',
        OLD.id_insumo,
        'DELETE',
        JSON_OBJECT(
            'id_insumo', OLD.id_insumo,
            'nome', OLD.nome,
            'marca', OLD.marca,
            'tipo', OLD.tipo
        ),
        NULL,
        USER(),
        NOW()
    );
END$$

-- ------------------------------------------------------------
-- IMUTABILIDADE (2 triggers): ninguem edita nem apaga o historico
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_historico_alteracoes_bu$$
CREATE TRIGGER trg_historico_alteracoes_bu
BEFORE UPDATE ON historico_alteracoes
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'historico_alteracoes é imutável: não é permitido alterar linhas';
END$$

DROP TRIGGER IF EXISTS trg_historico_alteracoes_bd$$
CREATE TRIGGER trg_historico_alteracoes_bd
BEFORE DELETE ON historico_alteracoes
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'historico_alteracoes é imutável: não é permitido apagar linhas';
END$$

DELIMITER ;


-- >>>>>>>>>> FIM. Agora rode testes/conferencia.sql <<<<<<<<<<
