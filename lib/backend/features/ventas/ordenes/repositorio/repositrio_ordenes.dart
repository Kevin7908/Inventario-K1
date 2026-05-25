import '../enum/enum_ordenes.dart';
import '../modelo/orden_detalle.dart';
import '../modelo/orden_resumen.dart';

abstract interface class RepositorioOrdenes {
  // Stream reactivo de la lista de órdenes (JOIN con motos y clientes).
  Stream<List<OrdenResumen>> observarTodas();

  // Future puntual para restaurar estado tras error.
  Future<List<OrdenResumen>> obtenerTodas();

  // Detalle completo: cabecera + tareas + repuestos.
  Future<OrdenDetalle> obtenerDetalle(int id);

  // Crea una nueva orden en estado ABIERTA.
  Future<OrdenResumen> agregar({
    required int motoId,
    required int clienteId,
    required int kilometrajeEntrada,
    String? diagnostico,
    String? observaciones,
  });

  // Actualiza estado, kilometraje, moto y/o diagnóstico.
  Future<OrdenResumen> actualizar({
    required int id,
    required EstadoOrden estado,
    required int kilometrajeEntrada,
    int? motoId,
    int? clienteId,
    String? diagnostico,
    String? observaciones,
  });

  // Elimina la orden y en cascada sus tareas y repuestos.
  Future<void> eliminar(int id);

  // Tareas 

  Future<void> agregarTarea({
    required int ordenId,
    required int servicioId,
    required int tecnicoId,
    required double precioPactado,
    String? notas,
  });

  Future<void> marcarTareaCompletada(int tareaId, {required bool completado});

  Future<void> actualizarTarea(
    int tareaId, {
    int? servicioId,
    int? tecnicoId,
    double? precioPactado,
    String? notas,
    bool? completado,
  });

  Future<void> eliminarTarea(int tareaId);

  // Repuestos

  Future<void> agregarRepuesto({
    required int ordenId,
    required int productoId,
    required double cantidad,
    required double precioUnitario,
  });

  // Elimina y re-inserta para que los triggers de stock actúen correctamente.
  Future<void> actualizarRepuesto(
    int repuestoId, {
    double? cantidad,
    double? precioUnitario,
  });

  Future<void> eliminarRepuesto(int repuestoId);
}