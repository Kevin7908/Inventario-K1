import 'package:equatable/equatable.dart';

import '../enum/enum_facturas.dart';
import 'venta_item.dart';

class FacturaDetalle extends Equatable {
  const FacturaDetalle({
    required this.id,
    required this.numeroFactura,
    required this.tipo,
    this.ordenId,
    this.numeroOrden,
    this.clienteId,
    required this.clienteNombre,
    required this.subtotal,
    required this.iva,
    required this.descuento,
    required this.total,
    required this.totalPagado,
    required this.metodoPago,
    required this.estadoPago,
    this.creadoEn,
    required this.items,
  });

  final int id;
  final String numeroFactura;
  final TipoVenta tipo;
  final int? ordenId;
  final String? numeroOrden;
  final int? clienteId;
  final String clienteNombre;
  final double subtotal;
  final double iva;
  final double descuento;
  final double total;
  final double totalPagado;
  final MetodoPago metodoPago;
  final EstadoPago estadoPago;
  final DateTime? creadoEn;
  final List<VentaItem> items;

  List<VentaItem> get itemsProducto =>
      items.where((i) => i.tipoItem == TipoItem.producto).toList();

  List<VentaItem> get itemsServicio =>
      items.where((i) => i.tipoItem == TipoItem.servicio).toList();

  double get saldoPendiente => total - totalPagado;

  @override
  List<Object?> get props => [
        id,
        numeroFactura,
        tipo,
        ordenId,
        numeroOrden,
        clienteId,
        clienteNombre,
        subtotal,
        iva,
        descuento,
        total,
        totalPagado,
        metodoPago,
        estadoPago,
        creadoEn,
        items,
      ];
}
