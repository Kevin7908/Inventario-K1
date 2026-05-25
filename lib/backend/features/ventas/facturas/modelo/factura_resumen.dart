import 'package:equatable/equatable.dart';

import '../enum/enum_facturas.dart';

class FacturaResumen extends Equatable {
  const FacturaResumen({
    required this.id,
    required this.numeroFactura,
    required this.tipo,
    required this.clienteNombre,
    this.ordenId,
    this.numeroOrden,
    required this.total,
    required this.iva,
    required this.estadoPago,
    required this.metodoPago,
    this.creadoEn,
  });

  final int id;
  final String numeroFactura;
  final TipoVenta tipo;
  final String clienteNombre;
  final int? ordenId;
  final String? numeroOrden;
  final double total;
  final double iva;
  final EstadoPago estadoPago;
  final MetodoPago metodoPago;
  final DateTime? creadoEn;

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
        estadoPago,
        metodoPago,
        creadoEn,
      ];
}
