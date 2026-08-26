import 'package:equatable/equatable.dart';

import '../enum/enum_ventas.dart';

class VentaResumen extends Equatable {
  const VentaResumen({
    required this.id,
    required this.numeroFactura,
    required this.tipo,
    required this.clienteNombre,
    this.ordenId,
    this.numeroOrden,
    required this.total,
    required this.iva,
    required this.descuento,
    required this.estadoPago,
    required this.metodoPago,
    this.creadoEn,
    this.cajero = '',
  });

  final int id;
  final String numeroFactura;
  final TipoVenta tipo;
  final String clienteNombre;
  final int? ordenId;
  final String? numeroOrden;
  /// Los tres, en pesos enteros (ver `TablaVentas`).
  final int total;
  final int iva;
  final int descuento;
  final EstadoPago estadoPago;
  final MetodoPago metodoPago;
  final DateTime? creadoEn;

  /// Quién la registró, del `JOIN` con `usuarios` y `personas`. Cadena vacía
  /// solo si la consulta no lo pidió: la columna `usuario_id` es `NOT NULL`.
  final String cajero;

  @override
  List<Object?> get props => [
        id,
        numeroFactura,
        tipo,
        clienteNombre,
        ordenId,
        numeroOrden,
        total,
        iva,
        descuento,
        estadoPago,
        metodoPago,
        creadoEn,
        cajero,
      ];
}
