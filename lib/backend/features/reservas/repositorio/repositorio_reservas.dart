import '../../../../core/resultado.dart';
import '../../../share/dominio/metodo_pago.dart';
import '../enum/enum_reserva.dart';
import '../modelo/reserva_detalle.dart';
import '../modelo/reserva_resumen.dart';

/// Criterios del listado, traducidos a un `WHERE` por el repositorio.
///
/// Value object con igualdad estructural: reabrir el stream con el mismo
/// filtro no cuenta como cambio y no dispara una consulta de más.
final class FiltroReservas {
  const FiltroReservas({this.busqueda = '', this.estado});

  /// Texto libre. Busca en el número de la reserva y en el nombre del cliente.
  final String busqueda;

  /// `null` = todos los estados.
  final EstadoReserva? estado;

  @override
  bool operator ==(Object other) =>
      other is FiltroReservas &&
      other.busqueda == busqueda &&
      other.estado == estado;

  @override
  int get hashCode => Object.hash(busqueda, estado);
}

/// Un tramo del listado más el total real.
///
/// [total] cuenta **todas** las reservas que cumplen el filtro, no las de la
/// página: es lo que necesita el paginador para saber cuántas hay.
final class PaginaReservas {
  const PaginaReservas({required this.items, required this.total});

  final List<ReservaResumen> items;
  final int total;

  static const vacia = PaginaReservas(items: [], total: 0);
}

abstract class RepositorioReservas {
  Stream<List<ReservaResumen>> observarTodas();

  /// Una página del listado. El `WHERE`, el `COUNT` y el `LIMIT` los resuelve
  /// SQLite (§5 de `REGLAS_BD.md`): las reservas se acumulan con los meses y
  /// traerlas todas para recortar en Dart no escala.
  ///
  /// [pagina] es de base cero.
  Stream<PaginaReservas> observarPagina({
    required FiltroReservas filtro,
    required int pagina,
    required int tamano,
  });

  /// La reserva que ya salió de esa cotización, si existe.
  ///
  /// La usa el diálogo de «Reservar» para abrir la que hay en vez de crear una
  /// segunda. La `UNIQUE` de la columna es la garantía; esto es la cortesía
  /// que permite dar un mensaje decente en vez de un error de SQLite.
  Future<int?> reservaDeCotizacion(int cotizacionId);

  Future<List<ReservaResumen>> obtenerTodas();

  Future<ReservaDetalle> obtenerDetalle(int id);

  Future<int> crear({
    required int clienteId,
    int? motoId,
    int? cotizacionId,
    required DateTime? fechaLimite,
    required int totalReserva,
    required List<ItemReservaDraft> items,
    int abonoInicial = 0,
    MetodoPago metodoPagoInicial = MetodoPago.efectivo,
    String? referenciaInicial,
  });

  Future<void> actualizar({
    required int id,
    int? motoId,
    int? cotizacionId,
    required DateTime? fechaLimite,
    required int totalReserva,
    required List<ItemReservaDraft> items,
  });

  // Líneas, una a una
  //
  // El editor escribe por línea y no reemplazando la reserva entera: con
  // `actualizar` cada tecleo restauraría y volvería a descontar el stock de
  // **todas** las líneas, que son dos movimientos de inventario por línea y
  // por tecla. Es la misma razón por la que órdenes escribe así.

  /// Aparta una cantidad más de un producto. Si ya está en la reserva, se
  /// suma a su línea en vez de abrir otra.
  Future<Resultado> agregarItem({
    required int reservaId,
    required int productoId,
    required double cantidad,
    required int precioUnitario,
  });

  /// Cambia la cantidad o el precio de una línea, moviendo solo la diferencia
  /// de stock. Si el total cae por debajo de lo ya abonado, registra la
  /// devolución (ver [eliminarItem]).
  Future<Resultado> actualizarItem(
    int itemId, {
    double? cantidad,
    int? precioUnitario,
  });

  /// Quita la línea y devuelve su mercancía al inventario.
  ///
  /// Si al quitarla el total queda por debajo de lo que el cliente ya entregó,
  /// se registra un **abono negativo** por la diferencia: la plata que sobra
  /// hay que regresarla, y queda escrita como un movimiento más en vez de
  /// corregir los abonos viejos.
  Future<Resultado> eliminarItem(int itemId);

  Future<void> registrarAbono({
    required int reservaId,
    required int monto,
    required MetodoPago metodoPago,
    String? referenciaPago,
  });

  Future<void> cambiarEstado(int id, EstadoReserva nuevoEstado);

  Future<void> eliminar(int id);

  /// Las reservas cuyo `pagado_acumulado` no cuadra con la suma de sus abonos,
  /// indexadas por id y con la diferencia (`caché − suma`).
  ///
  /// Vacío es lo esperado. Existe por el mismo motivo que
  /// `RepositorioInventario.descuadres`: un caché solo está justificado si
  /// algo puede afirmar que coincide con aquello de lo que es caché.
  Future<Map<int, int>> descuadres();

  /// Las reservas cuyo `total_reserva` no cuadra con la suma de sus líneas,
  /// indexadas por id y con la diferencia (`caché − suma`).
  ///
  /// El segundo caché de la tabla necesita su propia afirmación, igual que el
  /// primero (§7 de `REGLAS_BD.md`).
  Future<Map<int, int>> descuadresTotal();
}

class ItemReservaDraft {
  const ItemReservaDraft({
    required this.productoId,
    required this.cantidad,
    required this.precioUnitario,
  });

  final int productoId;
  final double cantidad;
  final int precioUnitario;

  int get subtotal => (cantidad * precioUnitario).round();
}
