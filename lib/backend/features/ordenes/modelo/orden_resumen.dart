import 'package:equatable/equatable.dart';

import '../enum/enum_ordenes.dart';

/// Una fila del listado de órdenes.
///
/// Los tres subtotales y el nombre del técnico llegan **ya resueltos por
/// SQLite**: la lista los necesita en cada fila, y calcularlos abriendo cada
/// orden sería el N+1 que prohíbe §5 de las reglas de base de datos.
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
    this.descuento = 0,
    this.subtotalManoObra = 0,
    this.subtotalRepuestos = 0,
    this.subtotalCargos = 0,
    this.tecnicoNombre,
    this.tecnicosDistintos = 0,
  });

  final int id;

  /// Consecutivo visible, `ORD-0041`. Sale de la columna `numero`, no del
  /// `id`: ver `TablaOrdenesServicio.numero`.
  final String numeroOrden;

  final String motoDescripcion;
  final String clienteNombre;
  final int kilometrajeEntrada;
  final String? diagnostico;
  final EstadoOrden estado;
  final DateTime? fechaIngreso;

  /// Rebaja aplicada, en pesos.
  final int descuento;

  /// Los tres en pesos enteros, sumados en SQL.
  final int subtotalManoObra;
  final int subtotalRepuestos;
  final int subtotalCargos;

  /// El técnico de la primera tarea. `null` si la orden todavía no tiene
  /// ninguna.
  final String? tecnicoNombre;

  /// Cuántos técnicos distintos trabajaron la orden. La columna del listado
  /// muestra el nombre cuando es uno y "Varios" cuando son más: el técnico
  /// vive por tarea, no por orden.
  final int tecnicosDistintos;

  /// Lo que suman las líneas, antes de la rebaja.
  int get subtotal => subtotalManoObra + subtotalRepuestos + subtotalCargos;

  /// Lo que se cobra. Los precios ya traen el IVA dentro (`iva_app.dart`), así
  /// que no hay nada que sumarle después.
  int get total => subtotal - descuento;

  /// Qué poner en la columna "Técnico" del listado.
  String get tecnicoParaListado => switch (tecnicosDistintos) {
        0 => 'Sin asignar',
        1 => tecnicoNombre ?? 'Sin asignar',
        _ => 'Varios',
      };

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
        descuento,
        subtotalManoObra,
        subtotalRepuestos,
        subtotalCargos,
        tecnicoNombre,
        tecnicosDistintos,
      ];

  @override
  String toString() =>
      'OrdenResumen(id: $id, orden: $numeroOrden, estado: ${estado.aTexto})';
}
