import '../modelo/linea_venta_mostrador.dart';
import '../modelo/venta_detalle.dart';
import '../modelo/venta_resumen.dart';
import '../enum/enum_ventas.dart';

/// Las ventas de mostrador del punto de venta.
///
/// **Qué queda de facturación.** El módulo de Facturación se borró el
/// 21/08/2026 con sus dos pantallas y todo lo que servía para armar una
/// factura a mano —crear la cabecera vacía, agregar líneas de a una, cobrar
/// en dos pasos, facturar una orden de servicio—. Lo que sobrevive es lo
/// único que sigue teniendo quien lo llame: el POS, que cobra el carrito
/// entero de un golpe.
///
/// Las tablas `ventas` y `venta_detalles` **no** se tocaron: son documentos
/// contables, las referencian `deudores.venta_id` y
/// `movimientos_inventario.venta_id`, y el consecutivo `FAC-` sigue saliendo
/// de `consecutivos`.
/// Una página del historial: las ventas visibles y el total real.
final class PaginaVentas {
  const PaginaVentas({
    required this.items,
    required this.total,
    this.sumaNeta = 0,
  });

  final List<VentaResumen> items;

  /// Cuántas ventas cumplen el filtro en total, no solo en esta página.
  final int total;

  /// Cuánto suman **todas** las que cumplen el filtro, no solo las visibles.
  ///
  /// Sale de un `SUM` en la misma consulta que el `COUNT`, no de recorrer
  /// [items]: la lista está paginada, y sumar quince filas para hablar de un
  /// mes es decir un número equivocado con toda seguridad.
  ///
  /// Va el **neto** y sin las anuladas: lo que se devolvió salió de la caja,
  /// y una anulada nunca entró. Es la cifra con la que se cuadra el cajón.
  final int sumaNeta;

  static const vacia = PaginaVentas(items: [], total: 0);
}

/// Criterios que se aplican **en SQL**, no recorriendo la lista.
final class FiltroVentas {
  const FiltroVentas({
    this.tipo,
    this.estado,
    this.usuarioId,
    this.desde,
    this.hasta,
    this.busqueda = '',
  });

  /// Mostrador o facturada desde una orden de servicio.
  final TipoVenta? tipo;

  final EstadoPago? estado;

  /// Solo lo que vendió esta cuenta.
  final int? usuarioId;

  /// Rango de fechas, inclusivo por los dos lados.
  final DateTime? desde;
  final DateTime? hasta;

  /// Texto libre contra el número de factura, el cliente y el cajero.
  final String busqueda;

  bool get hayFiltro =>
      tipo != null ||
      estado != null ||
      usuarioId != null ||
      desde != null ||
      hasta != null ||
      busqueda.trim().isNotEmpty;
}

abstract interface class RepositorioVentas {
  /// Historial de ventas, de la más nueva a la más vieja.
  Stream<List<VentaResumen>> observarTodas();

  /// Una página del historial, de la más reciente a la más antigua.
  ///
  /// Filtra, cuenta y recorta **en SQL**: el historial de un taller crece sin
  /// techo y es la última lista que puede traerse entera para filtrarla en
  /// memoria (`REGLAS_BD.md` §5).
  Stream<PaginaVentas> observarPagina({
    required FiltroVentas filtro,
    required int pagina,
    required int tamano,
  });

  /// Una venta con sus líneas.
  Future<VentaDetalle> obtenerDetalle(int id);

  /// Registra de una sola vez una venta de mostrador ya cobrada: cabecera,
  /// líneas, salidas de inventario y el pago completo.
  ///
  /// **Es una sola operación de negocio, así que es un solo método** (§6 de
  /// las reglas de base de datos). Componerla desde el notifier con una
  /// cabecera + N líneas + el cobro dejaba la venta a medias en cuanto una de
  /// las llamadas fallaba: quedaba una venta con su consecutivo quemado, sin
  /// líneas y sin cobrar, imposible de distinguir de una legítima. Aquí o
  /// pasa entera o no pasa nada.
  ///
  /// El total **no se recibe**: se calcula de las líneas que quedaron
  /// guardadas y ese es el que se marca como pagado. Si la vista y la base no
  /// coincidieran, la que manda es la base.
  ///
  /// Toda venta de mostrador se cobra completa: no hay pago parcial ni deuda
  /// automática. Fiar se hace desde Cuentas por cobrar.
  ///
  /// [descuento] en pesos exige `POS_DESCUENTO`, y solo cuando es mayor que
  /// cero: rebajar el total es la plata del taller, pero cobrar a precio de
  /// lista lo puede hacer cualquiera que venda.
  ///
  /// Lanza si [lineas] está vacía o si a algún producto no le alcanza el
  /// stock.
  Future<VentaResumen> registrarVentaMostrador({
    required List<LineaVentaMostrador> lineas,
    required MetodoPago metodoPago,
    int? clienteId,
    int iva,
    int descuento,
  });

  /// Anula la venta y devuelve el stock que había salido.
  ///
  /// **No la borra**: es un documento contable, y borrarla dejaría huecos en
  /// el consecutivo y salidas de inventario sin documento que las explique.
  /// Queda en `ANULADA`, con su número. La base lo refuerza: hay una guarda
  /// que rechaza cualquier `DELETE` sobre `ventas`.
  ///
  /// Lanza si la venta no existe o si ya estaba anulada.
  Future<void> anular(int id);
}
