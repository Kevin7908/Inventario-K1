import '../modelo/movimiento_inventario.dart';

/// El **único** camino por el que cambia `productos.stock_actual`.
///
/// Cualquier `UPDATE productos SET stock_actual = ...` fuera de aquí es un bug:
/// deja el caché y el libro mayor descuadrados y borra la trazabilidad de lo
/// que se vendió. Si hace falta mover stock desde un módulo nuevo, se agrega
/// un [TipoMovimiento], no un `UPDATE`.
abstract class RepositorioInventario {
  /// Aplica un movimiento: escribe el renglón y ajusta el caché de stock en la
  /// misma transacción.
  Future<void> registrar(SolicitudMovimiento solicitud);

  /// Igual que [registrar] pero con varios movimientos en **una sola**
  /// transacción. Es lo que usa una venta: o se descuentan todas las líneas o
  /// no se descuenta ninguna.
  ///
  /// Puede llamarse dentro de otra transacción —Drift la propaga por zona—, y
  /// es lo normal: la venta abre la suya y esto se suma.
  Future<void> registrarVarios(List<SolicitudMovimiento> solicitudes);

  /// El historial de un producto, del más reciente al más antiguo.
  Stream<List<MovimientoInventario>> observarPorProducto(int productoId);

  /// El stock reconstruido desde el libro mayor: `SUM(cantidad)`.
  ///
  /// Es la verdad de la que `productos.stock_actual` es caché. Si los dos no
  /// coinciden, alguien escribió el stock por fuera de este repositorio.
  Future<double> stockReconstruido(int productoId);

  /// Los productos cuyo caché de stock no cuadra con su libro mayor, indexados
  /// por id y con la diferencia (`caché − libro`).
  ///
  /// Vacío es lo esperado. Existe para que un test pueda afirmarlo después de
  /// una tanda de operaciones, que es lo que hace legítimo tener el caché.
  Future<Map<int, double>> descuadres();
}
