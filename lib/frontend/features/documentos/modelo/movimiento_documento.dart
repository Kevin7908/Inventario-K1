import 'package:equatable/equatable.dart';

/// Una entrega de dinero contra el documento: un abono de reserva, un pago de
/// deuda, el cobro de una factura.
///
/// Es lo que responde «cuánto ha abonado, cuándo y de a cuánto», que es
/// justamente lo que una reserva impresa tiene que decirle al cliente. El
/// monto puede ser **negativo**: cuando se quita mercancía de una reserva ya
/// abonada hay que devolver plata, y eso se registra como un movimiento más y
/// no editando el de ayer (ver `TablaReservaAbono`).
///
/// Parámetros:
/// - [fecha]: cuándo se recibió.
/// - [concepto]: el método de pago ya traducido a etiqueta («Efectivo»,
///   «Nequi»). Llega resuelto porque este modelo no conoce el enum del
///   backend.
/// - [referencia]: número de transacción o últimos dígitos, si los hay.
/// - [monto]: en pesos enteros. Negativo es una devolución.
///
/// Ejemplo:
/// ```dart
/// MovimientoDocumento(
///   fecha: abono.fechaPago,
///   concepto: abono.metodoPago.etiqueta,
///   monto: abono.monto,
/// )
/// ```
class MovimientoDocumento extends Equatable {
  const MovimientoDocumento({
    required this.fecha,
    required this.concepto,
    this.referencia,
    required this.monto,
  });

  final DateTime fecha;
  final String concepto;
  final String? referencia;
  final int monto;

  /// `true` si este movimiento devolvió dinero en vez de recibirlo.
  bool get esDevolucion => monto < 0;

  @override
  List<Object?> get props => [fecha, concepto, referencia, monto];
}
