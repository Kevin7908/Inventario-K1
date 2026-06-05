import '../enum/enum_reserva.dart';

class ReservaResumen {
  const ReservaResumen({
    required this.id,
    required this.numero,
    required this.clienteId,
    required this.nombreCliente,
    this.motoId,
    this.nombreMoto,
    this.placaMoto,
    this.cotizacionId,
    required this.estado,
    required this.totalReserva,
    required this.pagadoAcumulado,
    required this.creadoEn,
    this.fechaLimite,
  });

  final int id;
  final String numero;
  final int clienteId;
  final String nombreCliente;
  final int? motoId;
  final String? nombreMoto;
  final String? placaMoto;
  final int? cotizacionId;
  final EstadoReserva estado;
  final int totalReserva;
  final int pagadoAcumulado;
  final DateTime creadoEn;
  final String? fechaLimite;

  int get saldo => (totalReserva - pagadoAcumulado).clamp(0, totalReserva);

  double get porcentajePagado =>
      totalReserva > 0 ? (pagadoAcumulado / totalReserva).clamp(0.0, 1.0) : 0.0;

  bool get estaVencida {
    if (fechaLimite == null || estado != EstadoReserva.activa) return false;
    return fechaLimite!.compareTo(DateTime.now().toIso8601String().substring(0, 10)) < 0;
  }
}
