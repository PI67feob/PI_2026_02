# Justificativa da escolha do banco de dados

| | |
|---|---|
| **Autor** | Diogo Bordin |
| **Data** | 20/10/2026 |
| **Requisito** | PI-009 (issue #9): justificar a escolha entre banco relacional e não relacional |
| **Relacionado** | `der_completo.md` (modelo lógico) e `criar_banco.sql` (modelo físico) |

## 1. Decisão

O projeto usa um banco de dados **relacional**, o **MySQL 8**, modelado no **MySQL Workbench**. Este documento mostra por que a escolha vem dos dados e das necessidades do projeto, e não de preferência pessoal.

## 2. Por que um banco relacional

1. **Os dados são estruturados e conhecidos de antemão.** O controle da fazenda tem 11 tabelas com colunas fixas: área, talhão, operação, aplicador, aplicação, insumo, compra, item de compra, as duas tabelas de ligação e a de auditoria. A fazenda tem hoje 43 insumos e 11 aplicadores (1 drone e 10 bombas costais), todos com os mesmos atributos (nome, marca, tipo; modelo, tipo, capacidade). Dados assim cabem em tabelas sem esforço.
2. **Há relações N:N com dados próprios.** Uma aplicação pode atingir vários talhões, e um talhão recebe várias aplicações (`Aplicacao x Talhao`). Uma aplicação usa vários insumos, e um insumo entra em várias aplicações (`Aplicacao x Insumo`), e é nessa ligação que ficam a dose prevista, a dose realizada e a unidade da dose. Tabelas de ligação com chave composta resolvem isso diretamente.
3. **A integridade entre tabelas importa.** Um talhão não pode existir sem área: `id_area` é obrigatório e é chave estrangeira. O nome do talhão é único só dentro da área (`UNIQUE (id_area, nome)`). Uma área que ainda tem talhão não pode ser apagada. O banco também recusa valores sem sentido, como hectare negativo, quantidade comprada igual a zero ou tipo de aplicador fora da lista (trator, drone, bomba costal). Essas regras ficam no banco, e não só no código Dart, então valem para qualquer programa que gravar nele.
4. **A trilha de auditoria usa triggers.** A tabela `historico_alteracoes` guarda quem mudou o quê, e os triggers do MySQL a preenchem a cada alteração.
5. **O Power BI lê tabelas relacionadas.** Os painéis cruzam, por exemplo, insumo, aplicação e talhão. Isso é um conjunto de tabelas ligadas por chaves, que o Power BI entende como modelo relacional.
6. **O ID é gerado pelo banco.** Com `AUTO_INCREMENT`, o código Dart não precisa inventar identificadores. O banco cria o ID no `INSERT` e o objeto recebe esse valor de volta.

## 3. Por que MySQL 8 e MySQL Workbench

- **O Workbench desenha o modelo físico e gera o script.** Ele monta o diagrama EER e, pela função Forward Engineer, gera o script SQL a partir dele. Pela função Reverse Engineer, ele também gera o diagrama a partir de um banco existente. O grupo deixou de usar o BRModelo e passou a ter um só lugar para o modelo.
- **O Power BI tem conector próprio para MySQL.** Ele exige instalar o MySQL Connector/NET na máquina.
- **O MySQL Community é gratuito e roda local.** Não precisa de conta em nuvem nem de cartão.
- **O MySQL 8 a partir da 8.0.16 aplica as restrições `CHECK`.** O modelo usa `CHECK` para hectares, doses, quantidades e preços, e em versões anteriores elas eram aceitas na sintaxe mas ignoradas.

## 4. Por que não um banco não relacional

1. **O projeto precisa consultar os dados dos dois lados das relações N:N.** Para saber quanto de cada insumo foi aplicado em cada talhão, é preciso ligar `Aplicacao x Talhao` e `Aplicacao x Insumo`. Num banco de documentos, isso levaria a guardar a lista de talhões e insumos dentro de cada aplicação, e o mesmo talhão ou insumo apareceria copiado em muitos documentos. Corrigir o nome de um insumo exigiria alterar todas as cópias, com risco de ficarem diferentes.
2. **A integridade que o projeto exige é de banco relacional.** A regra "um talhão não pode ficar sem área" e a unicidade do nome do talhão dentro da área são chaves estrangeiras e chaves únicas no MySQL. Num banco não relacional, essas garantias teriam que ser reescritas no código Dart, e um programa que gravasse direto no banco poderia quebrá-las.
3. **O modelo é pequeno e estável, e a flexibilidade não faz falta.** A grande vantagem de um banco não relacional é aceitar dados sem formato fixo e escalar para volumes muito grandes. Aqui são 43 insumos e 11 aplicadores, com atributos fixos, então essa vantagem não se aplica.
4. **O consumidor dos dados é o Power BI.** Ele trabalha com tabelas e tem conector próprio para MySQL. Com um banco de documentos, seria preciso converter os dados para tabelas antes de montar os painéis.

## 5. Limitações da escolha

1. **O banco roda local em cada máquina.** Os dados não são compartilhados em tempo real entre os integrantes do grupo. Quem cadastra uma aplicação no seu computador não aparece na máquina do colega. Compartilhar exigiria um servidor único, que o projeto não tem.
2. **Mudar o schema depois de congelado custa caro.** Uma coluna nova ou renomeada obriga a alterar as classes do backend em Dart e os painéis do Power BI, além do script SQL. Por isso o modelo deve ficar fechado antes da implementação.
3. **O MySQL não dispara trigger em ação de cascata de chave estrangeira.** O `criar_banco.sql` usa `ON DELETE CASCADE` em `aplicacao_talhao`, `aplicacao_insumo` e `item_compra`. Se uma aplicação for apagada, as linhas filhas somem, e os triggers de auditoria **não registram** essas exclusões em `historico_alteracoes`. Para auditar tudo, o time pode trocar o `CASCADE` por apagar as filhas explicitamente antes, ou registrar a auditoria no código.
4. **O Power BI precisa do MySQL Connector/NET instalado em cada máquina** que for abrir os painéis. É um passo extra de configuração.
5. **As restrições `CHECK` só valem a partir da 8.0.16.** Se alguém instalar uma versão mais antiga, o banco aceita dados que o modelo diz proibir.
