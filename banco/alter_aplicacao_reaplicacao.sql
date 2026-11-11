-- Colunas novas em `aplicacao` para guardar a chuva e o imprevisto que obriga
-- a reaplicar. O Power BI agrupa por `motivo_reaplicacao`.
--
-- Rode ANTES de usar a versão nova do programa com --mysql. Linhas antigas
-- ficam com NULL nas duas colunas (nada pede reaplicação).
--
--   horas_ate_chuva     horas entre o fim da aplicação e a chuva (NULL = não
--                       informada)
--   motivo_reaplicacao  'chuva', 'sol', 'vento' ou 'outro' (NULL = nada pede
--                       para refazer a aplicação)

USE caderno_fazenda;

ALTER TABLE aplicacao
  ADD COLUMN horas_ate_chuva DECIMAL(6,2) NULL,
  ADD COLUMN motivo_reaplicacao VARCHAR(20) NULL,
  ADD CONSTRAINT chk_aplicacao_horas_chuva
    CHECK (horas_ate_chuva IS NULL OR horas_ate_chuva >= 0),
  ADD CONSTRAINT chk_aplicacao_motivo_reaplicacao
    CHECK (motivo_reaplicacao IS NULL
           OR motivo_reaplicacao IN ('chuva', 'sol', 'vento', 'outro'));

-- Conferência:
-- DESCRIBE aplicacao;
-- SELECT motivo_reaplicacao, COUNT(*) FROM aplicacao GROUP BY motivo_reaplicacao;
--
-- Se os triggers de auditoria de `aplicacao` listam as colunas uma a uma, vale
-- incluir as duas novas neles.
