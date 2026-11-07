import 'package:caderno_fazenda/exceptions/agrogestor_exception.dart';

/// Lançada quando um campo de uma entidade não é aceito pela regra de negócio
/// (por exemplo, nome vazio, tipo de aplicador desconhecido ou capacidade
/// negativa).
///
/// Mensagem: `Dado inválido: <campo> (<motivo>)`.
/// Exemplo: `Dado inválido: nome da área (não pode ser vazio)`.
class DadoInvalidoException extends AgroGestorException {
  /// Nome do campo recusado (ex.: `nome da área`).
  final String campo;

  /// Explicação de por que o valor foi recusado.
  final String motivo;

  /// Cria a exceção com o [campo] recusado e o [motivo] da recusa.
  DadoInvalidoException(this.campo, this.motivo)
    : super('Dado inválido: $campo ($motivo)');
}
