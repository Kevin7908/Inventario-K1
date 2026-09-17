import '../modelo/movimiento_detalle.dart';
import '../modelo/movimiento_inventario.dart';


/// Una página del libro mayor: los movimientos visibles y el total real.
final class PaginaMovimientos {
  const PaginaMovimientos({required this.items, required this.total});

  final List<MovimientoDetalle> items;

  /// Cuántos movimientos cumplen el filtro en total, no solo en esta página.
  final int total;

  static const vacia = PaginaMovimientos(items: [], total: 0);
}

/// Criterios que se aplican **en SQL**, no recorriendo la lista.
final class FiltroMovimientos {
  const FiltroMovimientos({
    this.productoId,
    this.tipo,
    this.usuarioId,
    this.desde,
    this.hasta,
    this.busqueda = '',
    this.soloEntradas,
  });

  final int? productoId;
  final TipoMovimiento? tipo;

  /// Solo lo que movió esta cuenta.
  final int? usuarioId;

  /// Rango inclusivo por los dos lados.
  final DateTime? desde;
  final DateTime? hasta;

  /// Texto libre contra el nombre del producto, su SKU y las notas.
  final String busqueda;

  /// `true` solo entradas, `false` solo salidas, `null` las dos. Es el filtro
  /// que se pide a diario —«¿qué entró esta semana?»— y con el signo en la
  /// cantidad sale de un `WHERE cantidad > 0`, sin listar diez tipos.
  final bool? soloEntradas;

  bool get hayFiltro =>
      productoId != null ||
      tipo != null ||
      usuarioId != null ||
      desde != null ||
      hasta != null ||
      soloEntradas != null ||
      busqueda.trim().isNotEmpty;
}

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

  /// Da entrada a la mercancía que llega del proveedor.
  ///
  /// Es su propio método y no un [registrar] con `ENTRADA_COMPRA` a mano
  /// porque tiene **otra compuerta**: recibir mercancía no es lo mismo que
  /// corregir existencias a mano, y en un taller no las hace la misma persona.
  ///
  /// **No pide proveedor ni costo, y es a propósito.** Desde que existe el
  /// módulo de Compras hay dos caminos para lo que entra: la remisión —con
  /// proveedor, factura y costo por línea— y este, que se conservó para lo que
  /// llega sin papel. El riesgo conocido es que alguien use siempre el atajo y
  /// el costo no quede registrado en ninguna parte; se vigila mirando cuántos
  /// `ENTRADA_COMPRA` quedan sin `compra_id`.
  Future<void> registrarEntradaCompra({
    required int productoId,
    required double cantidad,
    String? notas,
  });

  /// El historial de un producto, del más reciente al más antiguo.
  ///
  /// [limite] acota la consulta en SQL: la ficha del producto muestra los
  /// últimos, no los tres mil que puede tener un aceite. Con `null` vienen
  /// todos.
  Stream<List<MovimientoInventario>> observarPorProducto(
    int productoId, {
    int? limite,
  });

  /// Una página del libro mayor completo, de la más reciente a la más
  /// antigua, con el producto y el autor ya resueltos.
  ///
  /// Filtra, cuenta y recorta **en SQL** (`REGLAS_BD.md` §5): el libro mayor
  /// crece con cada venta y no cabe en memoria.
  ///
  /// Exige `Permiso.inventarioMovimientosVer`: el kardex dice quién sacó qué
  /// del taller, y eso no lo mira cualquiera.
  Stream<PaginaMovimientos> observarPagina({
    required FiltroMovimientos filtro,
    required int pagina,
    required int tamano,
  });

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
