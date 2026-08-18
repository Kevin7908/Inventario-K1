import '../../../share/dominio/metodo_pago.dart';
import '../enum/enum_reserva.dart';
import '../modelo/reserva_detalle.dart';
import '../modelo/reserva_resumen.dart';

abstract class RepositorioReservas {
  Stream<List<ReservaResumen>> observarTodas();

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
