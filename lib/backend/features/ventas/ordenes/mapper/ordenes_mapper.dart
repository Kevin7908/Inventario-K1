import 'package:drift/drift.dart';

import '../../../../share/database/app_db.dart';
import '../enum/enum_ordenes.dart';
import '../modelo/orden_detalle.dart';
import '../modelo/orden_repuesto.dart';
import '../modelo/orden_resumen.dart';
import '../modelo/orden_tarea.dart';

typedef FilaOrden = TablaOrdenesServicioData;

// Convierte resultados de queries (Map<String,dynamic>) a modelos de dominio.
abstract final class OrdenMapper {
  // Resumen (Lista principal)

  static OrdenResumen resumenDesdeMap(Map<String, dynamic> row) {
    return OrdenResumen(
      id: row['id'] as int,
      numeroOrden: _formatearNumero(row['id'] as int),
      // COALESCE en SQL o ?? en Dart para evitar strings como "null null null"
      motoDescripcion:
          '${row['marca'] ?? ''} ${row['modelo'] ?? ''} ${row['anio'] ?? ''}'
              .trim(),
      clienteNombre: row['cliente_nombre'] as String? ?? 'Sin Cliente',
      kilometrajeEntrada: row['kilometraje_entrada'] as int? ?? 0,
      diagnostico: row['diagnostico'] as String?,
      // Convertimos el String de la BD al Enum
      estado: EstadoOrden.desdeTexto(row['estado'] as String? ?? 'ABIERTA'),
      fechaIngreso: _parseFecha(row['fecha_ingreso']) ?? DateTime.now(),
    );
  }

  static List<OrdenResumen> resumenesDesdeMapas(
    List<Map<String, dynamic>> rows,
  ) => rows.map(resumenDesdeMap).toList(growable: false);

  // OrdenDetalle (Vista detallada)
  static OrdenDetalle detalleDesdeMapas({
    required Map<String, dynamic> ordenRow,
    required List<Map<String, dynamic>> tareasRows,
    required List<Map<String, dynamic>> repuestosRows,
  }) {
    return OrdenDetalle(
      id: ordenRow['id'] as int,
      numeroOrden: _formatearNumero(ordenRow['id'] as int),
      motoId: ordenRow['moto_id'] as int? ?? 0,
      motoDescripcion:
          '${ordenRow['marca'] ?? ''} ${ordenRow['modelo'] ?? ''} ${ordenRow['anio'] ?? ''}'
              .trim(),
      motoPlaca: ordenRow['placa'] as String? ?? 'SIN PLACA',
      clienteId: ordenRow['cliente_id'] as int? ?? 0,
      clienteNombre: ordenRow['cliente_nombre'] as String? ?? 'Sin Cliente',
      kilometrajeEntrada: ordenRow['kilometraje_entrada'] as int? ?? 0,
      diagnosticoCliente: ordenRow['diagnostico'] as String?,
      observacionesMecanico: ordenRow['observaciones'] as String?,
      estado: EstadoOrden.desdeTexto(
        ordenRow['estado'] as String? ?? 'ABIERTA',
      ),
      fechaIngreso: _parseFecha(ordenRow['fecha_ingreso']),
      fechaSalida: _parseFecha(ordenRow['fecha_salida']),
      // Mapeo de listas internas
      tareas: tareasRows.map(_tareaDesdeMap).toList(growable: false),
      repuestos: repuestosRows.map(_repuestoDesdeMap).toList(growable: false),
    );
  }

  // Companions (Escritura en BD)

  static TablaOrdenesServicioCompanion aCompanionNuevo({
    required int motoId,
    required int clienteId,
    required int kilometrajeEntrada,
    String? diagnostico,
    String? observaciones,
  }) => TablaOrdenesServicioCompanion.insert(
    motoId: motoId,
    clienteId: clienteId,
    kilometrajeEntrada: kilometrajeEntrada,
    diagnostico: Value(diagnostico),
    observaciones: Value(observaciones),
    estado: Value(EstadoOrden.abierta.name.toUpperCase()),
    fechaIngreso: Value(DateTime.now()),
    actualizadoEn: Value(DateTime.now()),
  );

  static TablaOrdenesServicioCompanion aCompanionActualizar({
    required int id,
    required EstadoOrden estado,
    required int kilometrajeEntrada,
    int? motoId,
    int? clienteId,
    String? diagnostico,
    String? observaciones,
    DateTime? fechaSalida,
  }) => TablaOrdenesServicioCompanion(
    id: Value(id),
    estado: Value(estado.name.toUpperCase()),
    kilometrajeEntrada: Value(kilometrajeEntrada),
    motoId: motoId != null ? Value(motoId) : const Value.absent(),
    clienteId: clienteId != null ? Value(clienteId) : const Value.absent(),
    diagnostico: Value(diagnostico),
    observaciones: Value(observaciones),
    fechaSalida: Value(fechaSalida),
    actualizadoEn: Value(DateTime.now()),
  );

  static TablaOrdenesTareaCompanion tareaCompanionNuevo({
    required int ordenId,
    required int servicioId,
    required int tecnicoId,
    required double precioPactado,
    String? notas,
  }) => TablaOrdenesTareaCompanion.insert(
    ordenId: ordenId,
    servicioId: servicioId,
    tecnicoId: tecnicoId,
    precioPactado: Value(precioPactado),
    notas: Value(notas),
    // No enviamos 'completado' porque el default de la tabla es false
    creadoEn: Value(DateTime.now()),
  );

  static TablaOrdenesRepuestoCompanion repuestoCompanionNuevo({
    required int ordenId,
    required int productoId,
    required double cantidad,
    required double precioUnitario,
  }) => TablaOrdenesRepuestoCompanion.insert(
    ordenId: ordenId,
    productoId: productoId,
    cantidad: Value(cantidad),
    precioUnitario: Value(precioUnitario),
    creadoEn: Value(DateTime.now()),
  );

  //  Helpers privados (Mapeo de filas hijas)

  static OrdenTarea _tareaDesdeMap(Map<String, dynamic> row) {
    // Manejo de booleano: SQLite devuelve 0 o 1 en Raw SQL
    final rawCompletado = row['completado'];
    final bool completado = rawCompletado is bool
        ? rawCompletado
        : (rawCompletado as num?)?.toInt() == 1;

    return OrdenTarea(
      id: row['id'] as int,
      ordenId: row['orden_id'] as int,
      servicioId: row['servicio_id'] as int? ?? 0,
      tecnicoId: row['tecnico_id'] as int? ?? 0,
      servicioNombre:
          row['servicio_nombre'] as String? ?? 'Servicio desconocido',
      tecnicoNombre: row['tecnico_nombre'] as String? ?? 'Sin asignar',
      precioPactado: (row['precio_pactado'] as num? ?? 0.0).toDouble(),
      notas: row['notas'] as String?,
      completado: completado,
      creadoEn: _parseFecha(row['creado_en']),
    );
  }

  static OrdenRepuesto _repuestoDesdeMap(Map<String, dynamic> row) =>
      OrdenRepuesto(
        id: row['id'] as int,
        ordenId: row['orden_id'] as int,
        productoId: row['producto_id'] as int? ?? 0,
        productoNombre:
            row['producto_nombre'] as String? ?? 'Producto desconocido',
        cantidad: (row['cantidad'] as num? ?? 0.0).toDouble(),
        precioUnitario: (row['precio_unitario'] as num? ?? 0.0).toDouble(),
        costoUnitario: (row['precio_compra'] as num? ?? 0.0).toDouble(),
        creadoEn: _parseFecha(row['creado_en']),
      );

  //  Utilidades

  static DateTime? _parseFecha(dynamic valor) {
    if (valor == null) return null;
    if (valor is DateTime) return valor;
    if (valor is int) return DateTime.fromMillisecondsSinceEpoch(valor);
    if (valor is String && valor.isNotEmpty) return DateTime.tryParse(valor);
    return null;
  }

  static String _formatearNumero(int id) =>
      '#ORD-${id.toString().padLeft(4, '0')}';
}
