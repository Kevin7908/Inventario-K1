import '../../../../core/resultado.dart';

/// Cómo terminó la apertura de una remisión.
///
/// Es un tipo sellado y no un [Resultado] a secas porque la vista necesita el
/// **número recién asignado** para poder decir «quedó registrada la COM-0007»
/// y abrirla: con `Exito()` no habría de dónde sacarlo (§8 de `REGLAS_BD.md`).
sealed class ResultadoCompra {
  const ResultadoCompra();
}

/// La remisión quedó abierta, en borrador y con su número. Lo que llegó se
/// anota después, línea por línea, en su ficha.
final class CompraAbierta extends ResultadoCompra {
  const CompraAbierta({required this.compraId, required this.numero});

  final int compraId;

  /// El consecutivo del taller, `COM-2026-0007`.
  final String numero;
}

/// No se abrió, y por qué. [motivo] deja distinguir la remisión repetida del
/// permiso que falta.
final class CompraRechazada extends ResultadoCompra {
  const CompraRechazada(this.motivo, this.mensaje);

  final MotivoFallo motivo;
  final String mensaje;
}
