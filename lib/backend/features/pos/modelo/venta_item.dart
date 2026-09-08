import 'package:equatable/equatable.dart';

import '../enum/enum_ventas.dart';

class VentaItem extends Equatable {
  const VentaItem({
    required this.id,
    required this.ventaId,
    required this.tipoItem,
    this.productoId,
    this.servicioId,
    this.tecnicoId,
    required this.descripcion,
    this.sku = '',
    this.unidad = '',
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

  /// El código del producto y su unidad de medida, para la factura.
  ///
  /// **No son snapshot**: se leen del catálogo al pedir el detalle, no se
  /// copian en `venta_detalles`. La descripción sí se congela —es lo que el
  /// cliente compró y no puede cambiar—, pero el SKU y la unidad son la ficha
  /// de hoy, que es lo que sirve para volver a pedir la pieza. Un producto
  /// borrado los deja vacíos y la factura sale igual.
  final String sku;
  final String unidad;

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
        sku,
        unidad,
        cantidad,
        precioUnitario,
        costoUnitario,
        subtotal,
      ];
}
