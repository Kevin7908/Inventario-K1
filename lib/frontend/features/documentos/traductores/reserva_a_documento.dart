import '../../../../backend/features/reservas/modelo/reserva_abono.dart';
import '../../../../backend/features/reservas/modelo/reserva_detalle.dart';
import '../../../../backend/features/reservas/modelo/reserva_item.dart';
import '../../../../core/formato.dart';
import '../../../../core/iva_app.dart';
import '../modelo/bloque_lineas.dart';
import '../modelo/documento_imprimible.dart';
import '../modelo/movimiento_documento.dart';
import '../modelo/negocio_impreso.dart';

/// Traduce una reserva a papel.
///
/// Lo que el cliente se lleva de una reserva no es una factura: es el
/// comprobante de **cuánto ha abonado, cuándo y de a cuánto, y cuánto le
/// falta**. Por eso este traductor llena `movimientos` y `saldoPendiente`,
/// que en una venta de mostrador casi nunca se usan.
///
/// Decisiones que se toman aquí:
///
/// - **Los abonos van en orden cronológico**, del más viejo al más nuevo, que
///   es como se lee una cuenta. El repositorio ya los trae así por su índice
///   `idx_reserva_abonos_reserva_fecha`, pero se ordena igual: depender del
///   orden de una consulta ajena es lo que rompe el día que alguien le cambia
///   el `ORDER BY`.
/// - **Una devolución se imprime como lo que es.** El monto de un abono puede
///   ser negativo —quitar mercancía de una reserva ya pagada obliga a devolver
///   plata—, y ocultarlo dejaría una columna cuya suma no cuadra con el saldo.
/// - **El IVA se calcula, no se lee.** Una reserva no guarda su IVA como lo
///   hace una factura, así que se extrae del total con `ivaIncluidoEn` —los
///   precios lo llevan dentro— y se omite si la tasa es cero.
/// - **El saldo se imprime aunque esté en cero**: en una reserva, «Saldo
///   pendiente $0» es justamente la buena noticia que el cliente vino a
///   confirmar. Es lo contrario que en una factura, donde solo estorba.
///
/// Parámetros:
/// - [reserva]: la reserva con sus líneas y sus abonos.
/// - [negocio]: el encabezado, de `negocioImpresoProvider`.
/// - [atendidoPor]: quién la atiende.
///
/// Ejemplo:
/// ```dart
/// final doc = documentoDeReserva(reserva: detalle, negocio: negocio);
/// ```
DocumentoImprimible documentoDeReserva({
  required ReservaDetalle reserva,
  required NegocioImpreso negocio,
  String? atendidoPor,
}) {
  final resumen = reserva.resumen;
  final abonos = [...reserva.abonos]
    ..sort((a, b) => a.fechaPago.compareTo(b.fechaPago));

  return DocumentoImprimible(
    negocio: negocio,
    titulo: 'Reserva',
    numero: resumen.numero,
    fecha: resumen.creadoEn,
    cliente: resumen.nombreCliente,
    documentoCliente: _moto(resumen.nombreMoto, resumen.placaMoto),
    atendidoPor: atendidoPor,
    bloques: [
      BloqueLineas(lineas: reserva.items.map(_linea).toList()),
    ],
    subtotal: resumen.totalReserva,
    iva: hayIva ? ivaIncluidoEn(resumen.totalReserva) : null,
    total: resumen.totalReserva,
    movimientos: abonos.map(_movimiento).toList(),
    saldoPendiente: resumen.saldo,
    nota: resumen.fechaLimite != null
        ? 'Reserva vigente hasta el ${formatearFecha(resumen.fechaLimite!)}.'
        : null,
  );
}

/// La moto va donde el documento del cliente porque es lo que identifica la
/// reserva en el mostrador: «la Boxer de placa KMN12C», no la cédula.
String? _moto(String? nombre, String? placa) {
  final partes = [
    if ((nombre ?? '').isNotEmpty) nombre!,
    if ((placa ?? '').isNotEmpty) placa!,
  ];
  return partes.isEmpty ? null : partes.join(' · ');
}

LineaDocumento _linea(ReservaItem item) => LineaDocumento(
      descripcion: item.nombreProducto,
      referencia: item.sku,
      cantidad: item.cantidad,
      precioUnitario: item.precioUnitario,
      subtotal: (item.cantidad * item.precioUnitario).round(),
    );

MovimientoDocumento _movimiento(ReservaAbono abono) => MovimientoDocumento(
      fecha: abono.fechaPago,
      concepto: abono.metodoPago.etiqueta,
      referencia: abono.referenciaPago,
      monto: abono.monto,
    );
