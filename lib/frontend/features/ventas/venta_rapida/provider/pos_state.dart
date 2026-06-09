import 'package:equatable/equatable.dart';

import '../../../../../backend/features/productos/modelo/producto.dart';
import '../../../../../backend/features/ventas/facturas/enum/enum_facturas.dart';

class ItemCarrito extends Equatable {
  const ItemCarrito({
    required this.producto,
    required this.cantidad,
  });

  final Producto producto;
  final int      cantidad;

  double get subtotal => producto.precioVenta * cantidad;

  ItemCarrito copyWith({Producto? producto, int? cantidad}) => ItemCarrito(
        producto: producto ?? this.producto,
        cantidad: cantidad ?? this.cantidad,
      );

  @override
  List<Object?> get props => [producto.id, cantidad];
}

final class PosState {
  const PosState({
    this.items        = const [],
    this.clienteId,
    this.clienteNombre,
    this.metodoPago   = MetodoPago.efectivo,
    this.buscando     = '',
    this.categoriaFiltro,
    this.procesando   = false,
    this.descuento    = 0,
  });

  final List<ItemCarrito> items;
  final int?              clienteId;
  final String?           clienteNombre;
  final MetodoPago        metodoPago;
  final String            buscando;
  final String?           categoriaFiltro;
  final bool              procesando;
  final double            descuento;

  double get subtotal => items.fold(0, (s, i) => s + i.subtotal);

  int get totalUnidades => items.fold(0, (s, i) => s + i.cantidad);

  PosState copyWith({
    List<ItemCarrito>? items,
    Object?            clienteId     = _sentinel,
    Object?            clienteNombre = _sentinel,
    MetodoPago?        metodoPago,
    String?            buscando,
    Object?            categoriaFiltro = _sentinel,
    bool?              procesando,
    double?            descuento,
  }) =>
      PosState(
        items:           items           ?? this.items,
        clienteId:       clienteId == _sentinel ? this.clienteId : clienteId as int?,
        clienteNombre:   clienteNombre == _sentinel ? this.clienteNombre : clienteNombre as String?,
        metodoPago:      metodoPago      ?? this.metodoPago,
        buscando:        buscando        ?? this.buscando,
        categoriaFiltro: categoriaFiltro == _sentinel
            ? this.categoriaFiltro
            : categoriaFiltro as String?,
        procesando:      procesando      ?? this.procesando,
        descuento:       descuento       ?? this.descuento,
      );

  static const Object _sentinel = Object();
}
