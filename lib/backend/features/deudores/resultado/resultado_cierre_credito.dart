import '../../../../core/resultado.dart';

/// Cómo terminó el intento de cerrar una orden a crédito.
///
/// Es un tipo sellado y no un [Resultado] a secas porque la vista necesita el
/// **número y el id de la deuda** para llevar hasta ella: cerrar a crédito
/// termina en otra pantalla, y sin esos dos datos habría que ir a buscarla.
/// Con `Exito()` no habría de dónde sacarlos (§8 de `REGLAS_BD.md`).
sealed class ResultadoCierreCredito {
  const ResultadoCierreCredito();
}

/// La deuda quedó abierta con las líneas de la orden dentro, y la orden pasó
/// a `ENTREGADA`. **El inventario no se movió**: los repuestos salieron del
/// estante cuando se anotaron en la orden.
final class DeudaAbierta extends ResultadoCierreCredito {
  const DeudaAbierta({required this.deudorId, required this.numero});

  final int deudorId;

  /// El consecutivo visible de la deuda, `DEU-014`.
  final String numero;
}

/// No se cerró, y por qué. [motivo] deja distinguir el permiso que falta de
/// la orden que ya estaba fiada.
final class CierreRechazado extends ResultadoCierreCredito {
  const CierreRechazado(this.motivo, this.mensaje);

  final MotivoFallo motivo;
  final String mensaje;
}
