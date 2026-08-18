import '../../../share/dominio/metodo_pago.dart';

/// Una entrega de dinero contra una reserva.
class ReservaAbono {
  const ReservaAbono({
    required this.id,
    required this.reservaId,
    required this.monto,
    required this.metodoPago,
    this.referenciaPago,
    required this.fechaPago,
  });

  final int id;
  final int reservaId;
  final int monto;
  final MetodoPago metodoPago;
  /// Número de transacción o últimos dígitos de la tarjeta: lo que permita
  /// reconocer el pago en el extracto.
  final String? referenciaPago;
  final DateTime fechaPago;
}
