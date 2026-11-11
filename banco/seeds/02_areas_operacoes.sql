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
