import 'package:equatable/equatable.dart';

import '../enum/enum_ordenes.dart';

class OrdenResumen extends Equatable {
  const OrdenResumen({
    required this.id,
    required this.numeroOrden,
    required this.motoDescripcion,
    required this.clienteNombre,
    required this.kilometrajeEntrada,
    required this.diagnostico,
    required this.estado,
    required this.fechaIngreso,
  });

  final int id;
  final String numeroOrden;       // "#ORD-0041"
  final String motoDescripcion;   // "Honda CB500F 2022"
  final String clienteNombre;
  final int kilometrajeEntrada;
  final String? diagnostico;
  final EstadoOrden estado;
  final DateTime? fechaIngreso;  

  @override
  List<Object?> get props => [
        id,
        numeroOrden,
        motoDescripcion,
        clienteNombre,
        kilometrajeEntrada,
        diagnostico,
        estado,
        fechaIngreso,
      ];

  @override
  String toString() =>
      'OrdenResumen(id: $id, orden: $numeroOrden, estado: ${estado.aTexto})';
}