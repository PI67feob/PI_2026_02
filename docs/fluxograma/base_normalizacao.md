# Base escolhida para a normalizacao


## Bases escolhidas

Existem duas bases, uma para cada tipo de produto:

| Tipo de produto | Funcao                | Base de saida |
| --------------- | --------------------- | ------------- |
| Liquido         | `normalizarDose`      | **L/ha**      |
| Solido          | `normalizarDoseMassa` | **kg/ha**     |

As bases foram escolhidas porque a area da aplicacao e expressa em hectares
e as funcoes de calculo por area podem usar diretamente uma dose normalizada.

Cada funcao trata **um unico tipo de grandeza**:

- `normalizarDose` so trata **VOLUME** e devolve L/ha.
- `normalizarDoseMassa` so trata **MASSA** e devolve kg/ha.

## Por que nao converter massa em volume

Para transformar kg em L (ou o contrario) e preciso saber a densidade do
produto, isto e, quantos kg cabem em 1 L. A fazenda nao tem esse dado.
Em vez de chutar um valor, as duas funcoes recusam a conversao e lancam
`DensidadeNecessariaException`.

## Fluxo de `normalizarDose` (produto liquido, saida em L/ha)

```text
                       Inicio
                         |
                         v
         Recebe dose + unidade + taxa (L/ha)
                         |
                         v
         dose < 0 ou taxa <= 0 ? --sim--> CaldaException
                         |
                        nao
                         v
              Qual e a unidade?
                         |
    +----------+---------+----------+-------------------+----------+
    |          |                    |                   |          |
  L/ha       mL/ha              L/1000L        kg/ha, g/ha,      outra
    |          |                    |          kg/1000L, g/1000L   |
    v          v                    v                   v          v
 mantem    dose / 1000     dose * (taxa / 1000)   Densidade-   Unidade-
 a dose         |                   |             Necessaria-  Desconhecida-
    |           |                   |             Exception    Exception
    +-----------+-------------------+
                |
                v
              L/ha
```

## Fluxo de `normalizarDoseMassa` (produto solido, saida em kg/ha)

```text
                       Inicio
                         |
                         v
                Recebe dose + unidade
                         |
                         v
              dose < 0 ? --sim--> CaldaException
                         |
                        nao
                         v
              Qual e a unidade?
                         |
         +---------------+------------------+-----------+
         |               |                  |           |
       kg/ha           g/ha        L/ha, mL/ha, L/1000L  outra
         |               |                  |           |
         v               v                  v           v
     mantem a      dose / 1000        Densidade-    Unidade-
       dose              |            Necessaria-   Desconhecida-
         |               |            Exception     Exception
         +---------------+
                 |
                 v
               kg/ha
```

## Exemplos

Produto liquido (`normalizarDose`):

- `2 L/ha` permanece `2 L/ha`.
- `500 mL/ha` vira `0,5 L/ha`.
- `1 L/1000 L` com taxa `40 L/ha` vira `0,04 L/ha`.
- `2 kg/ha` lanca `DensidadeNecessariaException` (e massa, nao volume).

Produto solido (`normalizarDoseMassa`):

- `2 kg/ha` permanece `2 kg/ha`.
- `500 g/ha` vira `0,5 kg/ha`.
- `1 L/ha` lanca `DensidadeNecessariaException` (e volume, nao massa).

## Regras gerais

- A taxa de aplicacao sempre entra por parametro, evitando valores fixos
  dentro da funcao. O valor `40 L/ha` usado nos exemplos e so um exemplo.
- Dose negativa lanca `CaldaException` nas duas funcoes.
- Unidade que nao existe (por exemplo `banana`) lanca
  `UnidadeDesconhecidaException`.

## Pendencia

- Dose de produto solido por 1000 L de calda (`g/1000L` ou `kg/1000L`) ainda
  nao e tratada. Precisa ser conferida na lista do agronomo. Ate la,
  `normalizarDoseMassa` lanca `UnidadeDesconhecidaException` para essas
  unidades.
