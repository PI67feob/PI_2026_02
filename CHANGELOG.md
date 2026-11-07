## Não lançado

### Adicionado

- POO: `Entidade` (base com id), `Aplicacao`, `AplicacaoInsumo`, `UnidadeDose` e a
  função `criarAplicador`.
- Exceções `DadoInvalidoException` e `RegistroNaoEncontradoException`.
- Lógica: `alertas_operacionais.dart` (chuva, capacidade e sobredose),
  `normalizacao_dose.dart` (líquido ou sólido) e `totais_desperdicio.dart`.
- Camada de dados: interfaces de repositório, implementação provisória em memória e
  `ConfiguracaoBanco` (lê as variáveis de ambiente). A pasta `lib/repositories/mysql/`
  fica reservada para a PI-023.
- Serviços: `AplicacaoService` (registrar aplicação e resumo de desperdício),
  `TalhaoService` e `ParametrosOperacionais`.
- Demonstração no terminal em `bin/main.dart`, sem banco de dados.
- `banco/RESERVADO_PARA_SQL.md`: onde o SQL entra e o mapa entre tabelas e classes.
- `docs/fluxograma/fluxo_dados.md`: fluxograma do percurso do dado (PI-022).
- Testes para tudo o que foi adicionado.

### Alterado

- `Area`, `Talhao`, `Insumo`, `Operacao` e `Aplicador` passaram a validar os dados no
  construtor e nos setters. Campos obrigatórios agora são `required` e não aceitam
  valor vazio ou inválido.
- `.env.example`: variáveis trocadas de PostgreSQL para MySQL e **sem valores**
  (só os nomes).
- `.gitignore`: passa a ignorar `*.local.sql` (scripts SQL com senha real).
- `README.md`: reescrito para explicar o código (camadas, papel de cada classe, fluxo
  principal, como rodar e onde o SQL entra). Removidas as menções a `Funcionario`,
  `Maquinario`, estoque mínimo e `bi/dashboard.pbix`, que não existem mais.
- `docs/fluxograma/fluxograma.md`: aviso de que está desatualizado, com links para a
  versão atual.

## 1.0.0

- Initial version.
