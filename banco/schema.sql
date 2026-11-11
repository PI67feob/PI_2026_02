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
