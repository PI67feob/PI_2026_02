import 'package:caderno_fazenda/exceptions/dado_invalido_exception.dart';

/// Imprevisto que obriga a refazer uma aplicação.
///
/// É a categoria que fica gravada no banco (coluna `motivo_reaplicacao`) e que
/// o BI usa para agrupar as reaplicações. A chuva tem regra própria: se as
/// horas até a chuva ficarem abaixo do limite da fazenda, o serviço marca
/// [chuva] sozinho. Os outros motivos não têm regra automática (a fazenda
/// ainda não definiu uma para o sol, por exemplo), então quem registra a
/// aplicação marca o motivo na mão e o sistema só guarda e avisa.
enum MotivoReaplicacao {
  /// Chuva que lavou o produto.
  chuva('chuva', 'chuva'),

  /// Sol forte ou calor que prejudicou a aplicação.
  solCalor('sol', 'sol/calor'),

  /// Vento que levou o produto para fora do alvo.
  vento('vento', 'vento'),

  /// Qualquer outro motivo; o detalhe pode ir na observação da aplicação.
  outro('outro', 'outro motivo');

  /// Texto gravado no banco (coluna `motivo_reaplicacao`).
  final String codigo;

  /// Texto mostrado ao usuário.
  final String texto;

  const MotivoReaplicacao(this.codigo, this.texto);

  /// Converte o texto do banco (`chuva`, `sol`, `vento` ou `outro`) no motivo
  /// correspondente.
  ///
  /// Lança [DadoInvalidoException] para qualquer outro texto.
  static MotivoReaplicacao deCodigo(String codigo) {
    for (final motivo in MotivoReaplicacao.values) {
      if (motivo.codigo == codigo.trim()) {
        return motivo;
      }
    }
    throw DadoInvalidoException(
      'motivo da reaplicação',
      'use chuva, sol, vento ou outro (recebido: $codigo)',
    );
  }
}
