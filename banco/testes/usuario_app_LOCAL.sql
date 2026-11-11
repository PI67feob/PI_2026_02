-- ============================================================
-- testes/usuario_app_LOCAL.sql   (SO PARA TESTE NO SEU COMPUTADOR)
-- Cria o usuario agrogestor_app para o teste da PI-018 (coluna usuario).
-- Se o roles.sql do Bruno ja cria esse usuario, use o dele e ignore este arquivo.
--
-- REGRAS
--   * NUNCA salve a senha neste arquivo, nem coloque no Git ou no chat.
--   * Troque <SENHA_QUE_VOCE_ESCOLHER> so na aba, rode, e feche a aba SEM salvar.
--   * Nao conceda DROP nem TRIGGER: a tarefa PI-018 depende disso.
-- ============================================================
CREATE USER IF NOT EXISTS 'agrogestor_app'@'localhost' IDENTIFIED BY '<SENHA_QUE_VOCE_ESCOLHER>';
GRANT SELECT, INSERT, UPDATE, DELETE ON caderno_fazenda.* TO 'agrogestor_app'@'localhost';

-- Conferir o que o usuario recebeu:
-- SHOW GRANTS FOR 'agrogestor_app'@'localhost';
