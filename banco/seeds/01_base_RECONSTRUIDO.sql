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
