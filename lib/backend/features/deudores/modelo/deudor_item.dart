/// Una línea de lo fiado: qué producto se llevó el cliente, cuánto y a qué
/// precio salió.
///
/// El precio es el del día en que se fió, copiado del catálogo: la deuda es un
/// documento cerrado y no se revaloriza si mañana sube el repuesto.
class DeudorItem {
  const DeudorItem({
    required this.id,
    required this.deudorId,
    required this.productoId,
    required this.nombreProducto,
    required this.sku,
    this.imagenUrl,
    required this.cantidad,
    required this.precioUnitario,
  });

  final int id;
  final int deudorId;
  final int productoId;
  final String nombreProducto;
  final String sku;
  final String? imagenUrl;
  final double cantidad;
  final int precioUnitario;

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
