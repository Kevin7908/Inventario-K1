import 'package:equatable/equatable.dart';

import '../enum/enum_deudor.dart';

class DeudorResumen extends Equatable {
  const DeudorResumen({
    required this.id,
    required this.numero,
    required this.clienteId,
    required this.nombreCliente,
    this.ventaId,
    required this.concepto,
    required this.montoTotal,
    required this.montoPagado,
    required this.estado,
    this.fechaVencimiento,
    this.notas,
    required this.creadoEn,
  });

  final int id;
  final String numero;
  final int clienteId;
  final String nombreCliente;
  final int? ventaId;
  final String concepto;
  final int montoTotal;
  final int montoPagado;
  final EstadoDeudor estado;
  final String? fechaVencimiento;
  final String? notas;
  final DateTime creadoEn;

  int get saldo => (montoTotal - montoPagado).clamp(0, montoTotal);

  double get porcentajePagado =>
      montoTotal > 0 ? (montoPagado / montoTotal).clamp(0.0, 1.0) : 0.0;

  bool get estaVencida {
    if (fechaVencimiento == null) return false;
    if (estado == EstadoDeudor.pagada || estado == EstadoDeudor.incobrable) return false;
    return fechaVencimiento!.compareTo(
          DateTime.now().toIso8601String().substring(0, 10),
        ) <
        0;
  }

  @override
  List<Object?> get props => [
        id,
        numero,
        clienteId,
        nombreCliente,
        ventaId,
        concepto,
        montoTotal,
        montoPagado,
        estado,
        fechaVencimiento,
        notas,
        creadoEn,
      ];
}
