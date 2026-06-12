class ReservaItem {
  const ReservaItem({
    required this.id,
    required this.reservaId,
    required this.productoId,
    required this.nombreProducto,
    required this.sku,
    this.imagenUrl,
    required this.cantidad,
    required this.precioUnitario,
  });

  final int id;
  final int reservaId;
  final int productoId;
  final String nombreProducto;
  final String sku;
  final String? imagenUrl;
  final double cantidad;
  final int precioUnitario;

  int get subtotal => (cantidad * precioUnitario).round();
}
