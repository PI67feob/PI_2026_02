import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';

/// Tira os espaços das pontas de [valor] e recusa texto nulo ou vazio.
///
/// Lança [DadoInvalidoException] com o nome do [campo] quando não sobra nada.
String textoObrigatorio(String? valor, String campo) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    throw DadoInvalidoException(campo, 'não pode ser vazio');
  }
  return texto;
}

/// Tira os espaços das pontas de [valor]; devolve null se não sobrar nada.
String? textoOpcional(String? valor) {
  final texto = valor?.trim();
  if (texto == null || texto.isEmpty) {
    return null;
  }
  return texto;
}

/// Aceita null (valor ainda não informado) ou um número finito maior que zero.
///
/// Lança [DadoInvalidoException] com o nome do [campo] para zero, negativo,
/// infinito ou NaN.
double? positivoOuNulo(double? valor, String campo) {
  if (valor == null) {
    return null;
  }
  if (!valor.isFinite || valor <= 0) {
    throw DadoInvalidoException(campo, 'deve ser maior que zero');
  }
  return valor;
}
