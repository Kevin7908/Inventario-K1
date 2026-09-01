/// Una línea de lo fiado: qué se llevó el cliente, cuánto y a qué precio
/// salió.
///
/// El precio y la descripción son los del día en que se fió, copiados del
/// catálogo: la deuda es un documento cerrado y no se revaloriza si mañana
/// sube el repuesto o le cambian el nombre.
///
/// **[productoId] falta en lo que no es una pieza.** Una orden cerrada a
/// crédito trae también su mano de obra y sus cargos sueltos, que se cobran
/// igual y no tienen catálogo detrás. Por eso el que siempre está es
/// [descripcion], y `esProducto` es lo que distingue una línea de la otra.
class DeudorItem {
  const DeudorItem({
    required this.id,
    required this.deudorId,
    this.productoId,
    required this.descripcion,
    this.sku,
    this.imagenUrl,
    required this.cantidad,
    required this.precioUnitario,
  });

  final int id;
  final int deudorId;

  /// El producto, cuando la línea es una pieza del catálogo.
  final int? productoId;

  /// Qué es la línea, congelado al fiar.
  final String descripcion;

  /// El SKU del producto. `null` en la mano de obra y en los cargos.
  final String? sku;
  final String? imagenUrl;
  final double cantidad;
  final int precioUnitario;

  /// Si detrás de la línea hay una pieza del inventario. Lo que decide es la
  /// FK, no el texto: una tarea puede llamarse igual que un repuesto.
  bool get esProducto => productoId != null;

  int get subtotal => (cantidad * precioUnitario).round();
}

/// Lo que hace falta para anotar una línea, antes de que la base le ponga id.
class ItemDeudaDraft {
  const ItemDeudaDraft({
    required this.productoId,
    required this.cantidad,
    required this.precioUnitario,
  });

  final int productoId;
  final double cantidad;
  final int precioUnitario;

  int get subtotal => (cantidad * precioUnitario).round();
}
