import '../../../share/dominio/metodo_pago.dart';
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
    DateTime? fechaVencimiento,
    String? notas,
    int pagoInicial = 0,
    MetodoPago metodoPagoInicial = MetodoPago.efectivo,
    String? notasPagoInicial,
  });

  Future<void> actualizar({
    required int id,
    int? ventaId,
    required String concepto,
    required int montoTotal,
    DateTime? fechaVencimiento,
    String? notas,
    required EstadoDeudor estado,
  });

  Future<void> registrarPago({
    required int deudorId,
    required int monto,
    required MetodoPago metodoPago,
    String? notas,
  });

  Future<void> eliminarPago(int pagoId, int deudorId);

  Future<void> cambiarEstado(int id, EstadoDeudor nuevoEstado);

  Future<void> eliminar(int id);

  /// Las deudas cuyo `monto_pagado` no cuadra con la suma de sus pagos,
  /// indexadas por id y con la diferencia (`caché − suma`).
  ///
  /// Vacío es lo esperado. Existe por el mismo motivo que
  /// `RepositorioInventario.descuadres` y `RepositorioReservas.descuadres`: un
  /// caché solo está justificado si algo puede afirmar que coincide.
  Future<Map<int, int>> descuadres();
}
