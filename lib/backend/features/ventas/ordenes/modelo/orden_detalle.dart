import 'package:equatable/equatable.dart';
import 'package:inventario_k1/backend/features/ventas/ordenes/modelo/orden_repuesto.dart';
import 'package:inventario_k1/backend/features/ventas/ordenes/modelo/orden_tarea.dart';

import '../enum/enum_ordenes.dart';

class OrdenDetalle extends Equatable {
  const OrdenDetalle({
    required this.id,
    required this.numeroOrden,
    required this.motoId,
    required this.motoDescripcion,
    required this.motoPlaca,
    required this.clienteId,
    required this.clienteNombre,
    required this.kilometrajeEntrada,
    required this.diagnosticoCliente,
    required this.observacionesMecanico,
    required this.estado,
    required this.fechaIngreso,
    required this.fechaSalida,
    required this.tareas,
    required this.repuestos,
  });

  final int id;
  final String numeroOrden;
  final int motoId;
  final String motoDescripcion;
  final String motoPlaca;
  final int clienteId;
  final String clienteNombre;
  final int kilometrajeEntrada;
  final String? diagnosticoCliente;
  final String? observacionesMecanico;
  final EstadoOrden estado;
  final DateTime? fechaIngreso;  
  final DateTime? fechaSalida;    
  final List<OrdenTarea> tareas;
  final List<OrdenRepuesto> repuestos;

  /// Los tres, en pesos enteros: se suman importes que ya lo son.
  int get subtotalManoObra =>
      tareas.fold(0, (s, t) => s + t.precioPactado);

  int get subtotalRepuestos =>
      repuestos.fold(0, (s, r) => s + r.subtotal);

  int get totalEstimado => subtotalManoObra + subtotalRepuestos;

  @override
  List<Object?> get props => [
        id,
        numeroOrden,
        motoId,
        motoDescripcion,
        motoPlaca,
        clienteId,
        clienteNombre,
        kilometrajeEntrada,
        diagnosticoCliente,
        observacionesMecanico,
        estado,
        fechaIngreso,
        fechaSalida,
        tareas,
        repuestos,
      ];

  @override
  String toString() =>
      'OrdenDetalle(id: $id, orden: $numeroOrden, total: $totalEstimado)';
}