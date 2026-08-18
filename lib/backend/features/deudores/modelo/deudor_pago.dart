import '../../../share/dominio/metodo_pago.dart';
import 'package:equatable/equatable.dart';

class DeudorPago extends Equatable {
  const DeudorPago({
    required this.id,
    required this.deudorId,
    required this.monto,
    required this.metodoPago,
    this.notas,
    required this.fechaPago,
  });

  final int id;
  final int deudorId;
  final int monto;
  final MetodoPago metodoPago;
  final String? notas;
  final DateTime fechaPago;

  @override
  List<Object?> get props => [id, deudorId, monto, metodoPago, notas, fechaPago];
}
