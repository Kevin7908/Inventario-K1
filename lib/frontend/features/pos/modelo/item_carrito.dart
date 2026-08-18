import '../../../../backend/features/productos/modelo/producto.dart';

/// Una línea del carrito del punto de venta.
///
/// El precio se congela al agregar el producto ([precioUnitario]) en vez de
/// leerse del catálogo en cada cálculo: si alguien edita el precio de venta
/// mientras hay una venta a medio armar, lo que el cliente ya vio en pantalla
/// no debe cambiarle debajo.
///
/// Los importes son enteros —pesos sin decimales, §6 de las reglas—, así que
/// el redondeo ocurre una sola vez, al construir la línea.
final class ItemCarrito {
  const ItemCarrito({
    required this.producto,
    required this.cantidad,
    required this.precioUnitario,
  });

  ItemCarrito.deProducto(Producto producto)
      : this(
          producto: producto,
          cantidad: 1,
          precioUnitario: producto.precioVenta.round(),
        );

  final Producto producto;
  final int cantidad;
  final int precioUnitario;

  int get subtotal => precioUnitario * cantidad;

  /// Cuántas unidades hay en bodega. Es el tope del carrito: el mostrador no
  /// puede vender lo que no está.
  int get disponible => producto.stockActual.floor();

  ItemCarrito copyWith({int? cantidad}) => ItemCarrito(
        producto: producto,
        cantidad: cantidad ?? this.cantidad,
        precioUnitario: precioUnitario,
      );
}
