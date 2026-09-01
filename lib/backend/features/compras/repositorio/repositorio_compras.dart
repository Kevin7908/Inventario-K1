import '../../../../core/resultado.dart';
import '../enum/enum_compras.dart';
import '../modelo/compra_item.dart';
import '../modelo/compra_resumen.dart';
import '../resultado/resultado_compra.dart';

/// Criterios del listado, traducidos a un `WHERE` por el repositorio.
///
/// Value object con igualdad estructural: reabrir el stream con el mismo
/// filtro no cuenta como cambio y no dispara una consulta de más.
final class FiltroCompras {
  const FiltroCompras({
    this.busqueda = '',
    this.proveedorId,
    this.estado,
    this.desde,
    this.hasta,
  });

  /// Texto libre contra el número del taller, el del proveedor y su nombre.
  final String busqueda;

  final int? proveedorId;

  /// `null` = registradas y anuladas.
  final EstadoCompra? estado;

  /// Rango por [CompraResumen.fecha], inclusivo por los dos lados.
  final DateTime? desde;
  final DateTime? hasta;

  bool get hayFiltro =>
      proveedorId != null ||
      estado != null ||
      desde != null ||
      hasta != null ||
      busqueda.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is FiltroCompras &&
      other.busqueda == busqueda &&
      other.proveedorId == proveedorId &&
      other.estado == estado &&
      other.desde == desde &&
      other.hasta == hasta;

  @override
  int get hashCode => Object.hash(busqueda, proveedorId, estado, desde, hasta);
}

/// Un tramo del listado más el total real.
///
/// [total] cuenta **todas** las compras que cumplen el filtro, no las de la
/// página: es lo que necesita el paginador para saber cuántas hay.
final class PaginaCompras {
  const PaginaCompras({required this.items, required this.total});

  final List<CompraResumen> items;
  final int total;

  static const vacia = PaginaCompras(items: [], total: 0);
}

/// Los cuatro números que encabezan la pantalla, del mes en curso.
///
/// [invertidoMes] es plata; los otros tres son conteos. Salen de una sola
/// pasada con `COUNT`/`SUM` filtrados (§5): la pantalla los quiere sobre el
/// mes entero aunque la búsqueda esté recortando la tabla.
typedef ResumenCompras = ({
  int comprasMes,
  int invertidoMes,
  int proveedoresMes,
  int anuladas,
});

/// Cuánto se le ha comprado a un proveedor, para su ficha.
typedef ResumenProveedorCompras = ({
  int comprasMes,
  int invertidoMes,
  int invertidoTotal,
  DateTime? ultimaCompra,
});

/// Las remisiones del proveedor: qué entró al taller, de quién y a cuánto.
///
/// Es el otro lado de `RepositorioVentas`, y se escribe igual: la cabecera,
/// sus líneas y las entradas de inventario, todo en una transacción. Antes de
/// que existiera, dar entrada preguntaba producto y cantidad, así que la app
/// no podía decir a cómo se compró nada ni cuánto se le lleva gastado a un
/// proveedor.
abstract class RepositorioCompras {
  /// Una página del listado, de la más reciente a la más antigua. El `WHERE`,
  /// el `COUNT` y el `LIMIT` los resuelve SQLite (§5).
  ///
  /// [pagina] es de base cero.
  Stream<PaginaCompras> observarPagina({
    required FiltroCompras filtro,
    required int pagina,
    required int tamano,
  });

  /// Los contadores de la cabecera, sobre el mes en curso.
  Stream<ResumenCompras> observarResumen();

  /// La remisión con sus líneas.
  Future<CompraDetalle> obtenerDetalle(int id);

  /// Registra la remisión entera: cabecera, líneas, entradas de inventario y
  /// el costo de cada producto.
  ///
  /// **Es una sola operación de negocio, así que es un solo método** (§6). Si
  /// se compusiera desde la vista —cabecera, luego líneas, luego entradas—,
  /// un fallo a mitad dejaría mercancía en el stock sin documento, o un
  /// consecutivo quemado sin nada dentro.
  ///
  /// El total **no se recibe**: se calcula de las líneas que quedaron
  /// guardadas. Si la vista y la base no coincidieran, la que manda es la
  /// base.
  ///
  /// Cada línea deja además el costo en `productos.precio_compra`, para que el
  /// margen que muestra la app se calcule contra lo que de verdad se pagó la
  /// última vez y no contra un número que alguien tecleó una vez.
  ///
  /// Rechaza la remisión repetida —mismo proveedor y mismo número de
  /// factura—, que es el error de captura que duplicaría el inventario.
  Future<ResultadoCompra> registrar({
    required int proveedorId,
    required List<LineaCompraNueva> lineas,
    DateTime? fecha,
    String? numeroFactura,
    String? notas,
  });

  /// Anula la remisión y **saca del inventario lo que había entrado**.
  ///
  /// No la borra: es un documento que explica movimientos y quemó un
  /// consecutivo. Queda en `ANULADA`, con su número, y una guarda de la base
  /// rechaza cualquier `DELETE` sobre `compras`.
  ///
  /// Falla si a algún producto ya no le queda stock suficiente: si la
  /// mercancía mal recibida ya se vendió, deshacer la compra dejaría el
  /// inventario en negativo. Ahí el camino es un ajuste, no una anulación.
  Future<Resultado> anular(int id);

  /// Lo último que se compró de un producto, para su ficha.
  ///
  /// De aquí sale «última compra hace 12 días, a $6.500»: se lee de
  /// `compra_detalles` y no de `productos.precio_compra`, porque ese es un
  /// solo número que se pisa con cada compra. Ignora las anuladas.
  Stream<UltimaCompra?> observarUltimaCompra(int productoId);

  /// Cuánto se le lleva comprado a un proveedor. Responde la pregunta que el
  /// taller hace todos los meses.
  Stream<ResumenProveedorCompras> observarResumenProveedor(int proveedorId);

  /// Las compras cuyo `total` no cuadra con la suma de sus líneas, indexadas
  /// por id y con la diferencia (`caché − suma`).
  ///
  /// Vacío es lo esperado. Existe por lo mismo que las otras cuatro: un caché
  /// solo está justificado si algo puede afirmar que coincide (§7).
  Future<Map<int, int>> descuadres();
}
