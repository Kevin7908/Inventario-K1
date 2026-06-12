import '../enum/enum_deudor.dart';
import '../modelo/deudor_detalle.dart';
import '../modelo/deudor_resumen.dart';

abstract class RepositorioDeudores {
  Stream<List<DeudorResumen>> observarTodas();

  Future<List<DeudorResumen>> obtenerTodas();

  Future<DeudorDetalle> obtenerDetalle(int id);

  Future<int> crear({
    required int clienteId,
    int? ventaId,
    required String concepto,
    required int montoTotal,
    String? fechaVencimiento,
    String? notas,
    int pagoInicial = 0,
    String metodoPagoInicial = 'Efectivo',
    String? notasPagoInicial,
  });

  Future<void> actualizar({
    required int id,
    int? ventaId,
    required String concepto,
    required int montoTotal,
    String? fechaVencimiento,
    String? notas,
    required EstadoDeudor estado,
  });

  Future<void> registrarPago({
    required int deudorId,
    required int monto,
    required String metodoPago,
    String? notas,
  });

  Future<void> eliminarPago(int pagoId, int deudorId);

  Future<void> cambiarEstado(int id, EstadoDeudor nuevoEstado);

  Future<void> eliminar(int id);
}
