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
    required String fechaLimite,
    required int totalReserva,
    required List<ItemReservaDraft> items,
    int abonoInicial = 0,
    String metodoPagoInicial = 'Efectivo',
    String? referenciaInicial,
  });

  Future<void> actualizar({
    required int id,
    int? motoId,
    int? cotizacionId,
    required String fechaLimite,
    required int totalReserva,
    required List<ItemReservaDraft> items,
  });

  Future<void> registrarAbono({
    required int reservaId,
    required int monto,
    required String metodoPago,
    String? referenciaPago,
  });

  Future<void> cambiarEstado(int id, EstadoReserva nuevoEstado);

  Future<void> eliminar(int id);
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
