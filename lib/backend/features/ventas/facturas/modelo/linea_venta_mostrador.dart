/// Una línea del carrito lista para facturarse en el mostrador.
///
/// Es lo que el punto de venta le entrega al repositorio: solo productos, con
/// el precio ya congelado. El mostrador no vende servicios —eso pasa por una
/// orden— así que no hay `tipoItem`: siempre es `PRODUCTO`.
///
/// El precio viaja desde la vista y no se releé del catálogo a propósito: es
/// el que el cliente vio en pantalla, y una edición del precio de venta a
/// mitad de la venta no puede cambiarle el importe debajo. Al guardarse en
/// `venta_detalles` se convierte en snapshot histórico (§1.2 de las reglas de
/// base de datos).
final class LineaVentaMostrador {
  const LineaVentaMostrador({
    required this.productoId,
    required this.descripcion,
    required this.cantidad,
    required this.precioUnitario,
    this.costoUnitario = 0,
  });

  final int productoId;

  /// Nombre del producto al momento de la venta.
  final String descripcion;

  /// Puede ser fraccionaria: hay productos por litro y por metro.
  final double cantidad;

  /// Pesos enteros, igual que la columna (§2).
  final int precioUnitario;

  /// Costo de compra del momento, para el margen. Pesos enteros.
  final int costoUnitario;
}
