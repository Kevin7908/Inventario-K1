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
/// Antes de que existiera, dar entrada preguntaba producto y cantidad, así que
/// la app no podía decir a cómo se compró nada ni cuánto se le lleva gastado a
/// un proveedor.
///
/// **Se escribe como una orden, no como una factura**: la cabecera primero y
/// las líneas de a una, cada una con su entrada de inventario en la misma
/// transacción. Es lo que pide el gesto real —se recibe la caja y se va
/// tecleando lo que sale de ella— y lo que permite que el editor guarde solo.
/// La contrapartida es que la remisión existe desde el primer momento; por eso
/// **no se borra**: se anula.
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

  /// Abre la remisión **vacía y en borrador**, y devuelve su número.
  ///
  /// Nace con proveedor, fecha y —si lo trae— el número de factura del
  /// proveedor; las líneas se le van anotando con [agregarLinea], igual que
  /// los repuestos de una orden. Se escribe así y no de un golpe porque es
  /// como se recibe la mercancía en el mostrador: la caja se va vaciando y
  /// cada producto se cuenta y se teclea cuando sale de ella.
  ///
  /// Mientras sea borrador **no cuenta como gasto del mes ni como la última
  /// compra del producto**, aunque su mercancía ya esté en el inventario:
  /// falta que quien recibe diga que está todo, y eso es [terminar].
  ///
  /// Rechaza la remisión repetida —mismo proveedor y mismo número de
  /// factura—, que es el error de captura que duplicaría el inventario.
  Future<ResultadoCompra> crear({
    required int proveedorId,
    DateTime? fecha,
    String? numeroFactura,
    String? notas,
  });

  /// Cambia los datos de la cabecera. **El total no está aquí**: sale de las
  /// líneas.
  Future<Resultado> actualizarCabecera({
    required int id,
    int? proveedorId,
    DateTime? fecha,
    String? numeroFactura,
    String? notas,
  });

  // Líneas, una a una
  //
  // Mismo modelo que órdenes, reservas y deudas: el editor escribe por línea y
  // no reemplazando la remisión entera, porque cada línea **mete mercancía al
  // inventario** y reescribirlas todas en cada tecleo serían dos movimientos
  // por línea y por tecla.

  /// Anota un producto más y **lo mete al inventario**, con su movimiento.
  ///
  /// Si el producto ya está en la remisión se le suma a su línea en vez de
  /// abrir otra, y el costo pasa a ser el último tecleado: para quien recibe
  /// es el mismo pedido, no un error.
  ///
  /// Deja además el costo en `productos.precio_compra`, para que el margen que
  /// muestra la app se calcule contra lo que de verdad se pagó la última vez y
  /// no contra un número que alguien tecleó una vez.
  Future<Resultado> agregarLinea({
    required int compraId,
    required int productoId,
    required double cantidad,
    required int costoUnitario,
  });

  /// Cambia la cantidad o el costo de una línea, moviendo **solo la
  /// diferencia** de stock.
  ///
  /// Bajar la cantidad falla si esa mercancía ya salió del taller: no se puede
  /// «des-recibir» lo que ya se vendió.
  Future<Resultado> actualizarLinea(
    int lineaId, {
    double? cantidad,
    int? costoUnitario,
  });

  /// Quita la línea y saca del inventario lo que había metido.
  Future<Resultado> eliminarLinea(int lineaId);

  // Cierre

  /// Da la remisión por terminada: pasa de borrador a `REGISTRADA`.
  ///
  /// Es el gesto de quien recibe cuando ya contó todo lo que traía la caja. A
  /// partir de ahí la remisión **se cierra a cambios** —lo garantizan las
  /// guardas—, cuenta como gasto del mes y pasa a ser la última compra de sus
  /// productos.
  ///
  /// Rechaza la remisión **sin una sola línea**: una compra que no trajo nada
  /// no es un documento, es un cuadro que alguien abrió sin querer.
  Future<Resultado> terminar(int id);

  /// Borra el borrador **que no llegó a nada**: sin una sola línea.
  ///
  /// Es lo que hace la ficha al salir de una remisión en la que no se anotó
  /// nada, para no dejar el listado lleno de cuadros abiertos por error. Con
  /// líneas dentro rechaza: eso ya explica entradas de inventario y el camino
  /// es [anular].
  Future<Resultado> descartarVacia(int id);

  /// Anula la remisión y **saca del inventario lo que había entrado**.
  ///
  /// Vale tanto para la terminada como para el borrador que ya tiene líneas:
  /// las dos metieron mercancía. No la borra —es un documento que explica
  /// movimientos—: queda en `ANULADA`, con su número.
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
