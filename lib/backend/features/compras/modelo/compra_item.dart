/// Una línea de la remisión, ya resuelta para pintarse.
///
/// [descripcion] y [costoUnitario] son el snapshot del día en que llegó la
/// mercancía (§1.2): es lo que permite comparar contra la compra anterior y
/// ver si el proveedor subió el precio. [sku] sí viene del catálogo, porque
/// es la referencia con la que se busca hoy.
final class CompraItem {
  const CompraItem({
    required this.id,
    required this.compraId,
    required this.productoId,
    required this.descripcion,
    this.sku,
    this.imagenUrl,
    required this.cantidad,
    required this.costoUnitario,
  });

  final int id;
  final int compraId;
  final int productoId;
  final String descripcion;
  final String? sku;
  final String? imagenUrl;
  final double cantidad;

  /// Lo que de verdad se pagó por unidad, en pesos enteros.
  final int costoUnitario;

  int get subtotal => (cantidad * costoUnitario).round();
}

/// Una línea antes de que exista la compra: lo que el editor arma en memoria
/// y manda entero a `RepositorioCompras.registrar`.
///
/// Es el equivalente de `LineaVentaMostrador` del POS, y por el mismo motivo:
/// la remisión se teclea completa y se escribe de un golpe, así que no hay
/// documento al que agregarle líneas de a una.
final class LineaCompraNueva {
  const LineaCompraNueva({
    required this.productoId,
    required this.cantidad,
    required this.costoUnitario,
  });

  final int productoId;
  final double cantidad;
  final int costoUnitario;

  int get subtotal => (cantidad * costoUnitario).round();
}

/// Lo último que se le compró a alguien de un producto.
///
/// Es lo que la ficha del producto y el panel del proveedor necesitan para
/// decir «última compra hace 12 días, a $6.500»: sale de `compra_detalles`,
/// no de `productos.precio_compra`, porque ese es un solo número que se pisa
/// y aquí hace falta el historial.
final class UltimaCompra {
  const UltimaCompra({
    required this.compraId,
    required this.numero,
    required this.fecha,
    required this.costoUnitario,
    required this.cantidad,
    required this.proveedorNombre,
  });

  final int compraId;
  final String numero;
  final DateTime fecha;
  final int costoUnitario;
  final double cantidad;
  final String proveedorNombre;

  /// Cuántos días hace que llegó. La vista lo redacta; aquí solo se cuenta.
  int get diasDesde => DateTime.now().difference(fecha).inDays;
}
