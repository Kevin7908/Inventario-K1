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
  /// Hasta cuándo se guarda la mercancía, a medianoche. `null` = sin plazo.
  final DateTime? fechaLimite;

  int get saldo => (totalReserva - pagadoAcumulado).clamp(0, totalReserva);

  double get porcentajePagado =>
      totalReserva > 0 ? (pagadoAcumulado / totalReserva).clamp(0.0, 1.0) : 0.0;

  /// Si ya no queda saldo por cobrar.
  ///
  /// **No es el estado de la reserva, es el del dinero**, y por eso se deriva
  /// en vez de guardarse: `estado` cuenta el ciclo de vida —apartada, entregada
  /// o cancelada— y esto cuenta si el cliente terminó de pagar. Son cosas
  /// distintas: se puede deber la mitad de algo que ya se entregó, y se puede
  /// tener pagado del todo algo que sigue en la bodega. El chip del listado
  /// muestra esto; el ciclo de vida lo decide quien entrega la mercancía.
  bool get pagada => totalReserva > 0 && pagadoAcumulado >= totalReserva;

  /// Solo una reserva **activa** vence: una completada o cancelada ya no
  /// espera nada.
  bool get estaVencida {
    final limite = fechaLimite;
    if (limite == null || estado != EstadoReserva.activa) return false;
    final hoy = DateTime.now();
    return limite.isBefore(DateTime(hoy.year, hoy.month, hoy.day));
  }
}
