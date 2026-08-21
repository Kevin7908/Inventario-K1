import 'package:equatable/equatable.dart';

import '../enum/enum_facturas.dart';

class VentaItem extends Equatable {
  const VentaItem({
    required this.id,
    required this.ventaId,
    required this.tipoItem,
    this.productoId,
    this.servicioId,
    this.tecnicoId,
    required this.descripcion,
    required this.cantidad,
    required this.precioUnitario,
    required this.costoUnitario,
    required this.subtotal,
  });

  final int id;
  final int ventaId;
  final TipoItem tipoItem;
  final int? productoId;
  final int? servicioId;
  final int? tecnicoId;
  final String descripcion;
  final double cantidad;
  /// Los tres, en pesos enteros (ver `TablaVentaDetalles`).
  final int precioUnitario;
  final int costoUnitario;
  final int subtotal;

  @override
  List<Object?> get props => [
        id,
        ventaId,
        tipoItem,
        productoId,
        servicioId,
        tecnicoId,
        descripcion,
        cantidad,
        precioUnitario,
        costoUnitario,
        subtotal,
      ];
}
