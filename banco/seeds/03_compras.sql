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
