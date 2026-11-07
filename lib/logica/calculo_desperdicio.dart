/// Excecao para erros das funcoes de calculo de desperdicio.
///
/// E lancada quando uma dose ou quantidade e negativa, quando a dose
/// prevista nao permite calcular o percentual (zero ou negativa) ou quando
/// o fator de compra e invalido.
class DesperdicioException implements Exception {
  final String message;

  DesperdicioException(this.message);

  @override
  String toString() => 'DesperdicioException: $message';
}

/// Fator padrao de compra: a fazenda compra 5% a menos do que o calculo
/// indica, ou seja, 95% da quantidade calculada.
const double fatorCompraPadrao = 0.95;

/// Funcao 1 - calcula o desvio entre a dose realizada e a dose prevista.
///
/// Importante: [dosePrevista] e [doseRealizada] precisam estar na MESMA
/// unidade base, que e L/ha para produto liquido ou kg/ha para produto
/// solido. Se a dose veio em outra unidade (por exemplo mL/ha ou g/ha),
/// converta antes com `normalizarDose` (liquido) ou `normalizarDoseMassa`
/// (solido). Esta funcao nao converte nada e nao sabe qual unidade foi usada.
///
/// Entrada:
/// - [dosePrevista]: dose que o calculo indicava, na unidade base.
/// - [doseRealizada]: dose que foi realmente aplicada, na mesma unidade.
///
/// Saida:
/// - Retorna [doseRealizada] menos [dosePrevista], na mesma unidade.
/// - Resultado positivo: aplicou MAIS do que o previsto.
/// - Resultado zero: aplicou exatamente o previsto.
/// - Resultado negativo: aplicou MENOS do que o previsto. O valor negativo
///   e devolvido como esta, sem ajuste.
///
/// Erros:
/// - Lanca [DesperdicioException] se [dosePrevista] ou [doseRealizada]
///   forem negativas.
double desvioDose(double dosePrevista, double doseRealizada) {
  if (dosePrevista < 0) {
    throw DesperdicioException('A dose prevista nao pode ser negativa.');
  }

  if (doseRealizada < 0) {
    throw DesperdicioException('A dose realizada nao pode ser negativa.');
  }

  return doseRealizada - dosePrevista;
}

/// Funcao 2 - calcula o percentual de desperdicio.
///
/// Importante: [dosePrevista] e [doseRealizada] precisam estar na MESMA
/// unidade base (L/ha para liquido ou kg/ha para solido), como em
/// [desvioDose]. Converta antes com `normalizarDose` ou
/// `normalizarDoseMassa` quando necessario.
///
/// Formula: desvio / previsto * 100, onde desvio = realizado - previsto.
///
/// Decisao para realizado MENOR que o previsto:
/// - Aplicar menos do que o necessario nao e desperdicio. Por isso, quando
///   o realizado e menor que o previsto, o percentual de desperdicio
///   devolvido e 0 (nunca um valor negativo).
/// - O desvio negativo continua disponivel em [desvioDose], que o devolve
///   como esta.
///
/// Entrada:
/// - [dosePrevista]: dose que o calculo indicava, na unidade base. Deve ser
///   maior que zero.
/// - [doseRealizada]: dose realmente aplicada, na mesma unidade.
///
/// Saida:
/// - Retorna o percentual de desperdicio, em %, sempre maior ou igual a zero.
/// - Exemplo: previsto 10 e realizado 12 devolve 20 (20% de desperdicio).
///
/// Erros:
/// - Lanca [DesperdicioException] se [dosePrevista] for zero ou negativa,
///   porque a divisao pelo previsto nao tem sentido.
/// - Lanca [DesperdicioException] se [doseRealizada] for negativa.
double percentualDesperdicio(double dosePrevista, double doseRealizada) {
  if (dosePrevista <= 0) {
    throw DesperdicioException(
      'A dose prevista deve ser maior que zero para calcular o percentual.',
    );
  }

  final desvio = desvioDose(dosePrevista, doseRealizada);

  if (desvio < 0) {
    return 0;
  }

  return (desvio / dosePrevista) * 100;
}

/// Funcao 3 - calcula a quantidade a comprar.
///
/// A fazenda compra 5% a menos do que o calculo indica. O fator de compra
/// entra por parametro, com o valor padrao [fatorCompraPadrao] (0,95), para
/// que a regra nao fique escondida dentro da conta.
///
/// Entrada:
/// - [quantidadeCalculada]: quantidade que o calculo indicou, em qualquer
///   unidade (L, kg etc.).
/// - [fator]: fator de compra, maior que zero. Padrao: [fatorCompraPadrao].
///
/// Saida:
/// - Retorna [quantidadeCalculada] multiplicada por [fator], na mesma
///   unidade da quantidade calculada.
/// - Exemplo: 100 com o fator padrao devolve 95.
///
/// Erros:
/// - Lanca [DesperdicioException] se [quantidadeCalculada] for negativa.
/// - Lanca [DesperdicioException] se [fator] for menor ou igual a zero.
double quantidadeAComprar(
  double quantidadeCalculada, {
  double fator = fatorCompraPadrao,
}) {
  if (quantidadeCalculada < 0) {
    throw DesperdicioException('A quantidade calculada nao pode ser negativa.');
  }

  if (fator <= 0) {
    throw DesperdicioException('O fator de compra deve ser maior que zero.');
  }

  return quantidadeCalculada * fator;
}
