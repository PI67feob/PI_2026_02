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
