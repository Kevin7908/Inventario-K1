import 'package:equatable/equatable.dart';

import '../enum/enum_ventas.dart';
import 'venta_item.dart';

class VentaDetalle extends Equatable {
  const VentaDetalle({
    required this.id,
    required this.numeroFactura,
    required this.tipo,
    this.ordenId,
    this.numeroOrden,
    this.clienteId,
    required this.clienteNombre,
    this.clienteDocumento = '',
    this.clienteDireccion = '',
    this.clienteCiudad = '',
    this.clienteTelefono = '',
    this.clienteCorreo = '',
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

  /// Los datos del cliente que la factura enseña, ya resueltos desde
  /// `personas`. Vacíos en una venta de mostrador sin cliente identificado,
  /// que es el caso normal: el impreso omite los renglones que no tienen
  /// valor en vez de pintar etiquetas huérfanas.
  final String clienteDocumento;
  final String clienteDireccion;
  final String clienteCiudad;
  final String clienteTelefono;
  final String clienteCorreo;

  /// Los cinco, en pesos enteros (ver `TablaVentas`).
  final int subtotal;
  final int iva;
  final int descuento;
  final int total;
  final int totalPagado;
  final MetodoPago metodoPago;
  final EstadoPago estadoPago;
  final DateTime? creadoEn;
  final List<VentaItem> items;

  List<VentaItem> get itemsProducto =>
      items.where((i) => i.tipoItem == TipoItem.producto).toList();

  List<VentaItem> get itemsServicio =>
      items.where((i) => i.tipoItem == TipoItem.servicio).toList();

  int get saldoPendiente => total - totalPagado;

  @override
  List<Object?> get props => [
        id,
        numeroFactura,
        tipo,
        ordenId,
        numeroOrden,
        clienteId,
        clienteNombre,
        clienteDocumento,
        clienteDireccion,
        clienteCiudad,
        clienteTelefono,
        clienteCorreo,
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
