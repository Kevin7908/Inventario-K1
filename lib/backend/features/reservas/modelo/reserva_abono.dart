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
  final String metodoPago;
  final String? referenciaPago;
  final DateTime fechaPago;
}
