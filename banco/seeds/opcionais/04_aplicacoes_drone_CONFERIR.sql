-- ============================================================
-- banco/seeds/04_aplicacoes_drone_CONFERIR.sql
-- OPCIONAL: NAO rodar ate conferir com o log do drone.
-- Fonte: dados-aplicacoes-drone.csv (fotos da tela do controlador, lidas a mao).
-- Confianca da leitura: media ou baixa (ver observacao de cada linha).
-- Todas usam o aplicador 1 (drone DJI). Ficam sem aplicacao_talhao e sem
-- aplicacao_insumo, porque o local da foto nao bate com nenhum talhao
-- cadastrado e os mapas nao dizem qual insumo nem a dose por hectare.
-- Ficou de fora: o mapa de fevereiro, sem data e sem numeros legiveis.
-- ============================================================
USE caderno_fazenda;

INSERT INTO aplicacao (id_operacao, id_aplicador, data_aplicacao, observacao) VALUES
  (1, 1, '2025-10-23', 'Voo de drone; local: Marli/Barracao/Portaria; 12.48 ha; 5847.73 kg; leitura de foto, confianca media; conferir com log do drone'),
  (1, 1, '2025-12-02', 'Voo de drone; local: Fazenda da Serra; 17.02 ha; 6253.81 kg; leitura de foto, confianca media; conferir com log do drone'),
  (1, 1, '2025-12-02', 'Voo de drone; local: Bela Vista; 31.43 ha; 4186.11 kg; leitura de foto, confianca media; conferir com log do drone'),
  (1, 1, '2025-12-02', 'Voo de drone; local: Bela Vista; 26.32 ha; 9381.95 kg; leitura de foto, confianca media; conferir com log do drone'),
  (2, 1, '2025-11-17', 'Voo de drone; local: Corujas; 9.70 ha; 305.81 kg; leitura de foto, confianca baixa; conferir com log do drone'),
  (1, 1, '2025-10-29', 'Voo de drone; local: nao identificado; 26.70 ha; 7449.00 kg; leitura de foto, confianca baixa; conferir com log do drone');
