import 'package:drift/drift.dart';

import '../../../../share/database/app_db.dart';
import '../enum/enum_facturas.dart';
import '../modelo/factura_detalle.dart';
import '../modelo/factura_resumen.dart';
import '../modelo/venta_item.dart';

abstract final class FacturasMapper {
  // ── Resumen (lista) ──────────────────────────────────────────────────────

  static FacturaResumen resumenDesdeMap(Map<String, dynamic> row) {
    final ordenId = row['orden_id'] as int?;
    return FacturaResumen(
      id: row['id'] as int,
      numeroFactura: row['numero_factura'] as String,
      tipo: TipoVenta.desdeTexto(row['tipo'] as String? ?? 'SERVICIO'),
      clienteNombre: row['cliente_nombre'] as String? ?? '— Sin cliente —',
      ordenId: ordenId,
      numeroOrden: ordenId != null
          ? '#ORD-${ordenId.toString().padLeft(4, '0')}'
          : null,
      total: (row['total'] as num? ?? 0).toDouble(),
      iva: (row['iva'] as num? ?? 0).toDouble(),
      estadoPago: EstadoPago.desdeTexto(row['estado_pago'] as String? ?? 'PENDIENTE'),
      metodoPago: MetodoPago.desdeTexto(row['metodo_pago'] as String? ?? 'EFECTIVO'),
      creadoEn: _parseFecha(row['creado_en']),
    );
  }

  static List<FacturaResumen> resumenesDesdeMapas(
    List<Map<String, dynamic>> rows,
  ) =>
      rows.map(resumenDesdeMap).toList(growable: false);

  // ── Detalle ──────────────────────────────────────────────────────────────

  static FacturaDetalle detalleDesdeMapas({
    required Map<String, dynamic> ventaRow,
    required List<Map<String, dynamic>> itemsRows,
  }) {
    final ordenId = ventaRow['orden_id'] as int?;
    return FacturaDetalle(
      id: ventaRow['id'] as int,
      numeroFactura: ventaRow['numero_factura'] as String,
      tipo: TipoVenta.desdeTexto(ventaRow['tipo'] as String? ?? 'SERVICIO'),
      ordenId: ordenId,
      numeroOrden: ordenId != null
          ? '#ORD-${ordenId.toString().padLeft(4, '0')}'
          : null,
      clienteId: ventaRow['cliente_id'] as int?,
      clienteNombre: ventaRow['cliente_nombre'] as String? ?? '— Sin cliente —',
      subtotal: (ventaRow['subtotal'] as num? ?? 0).toDouble(),
      iva: (ventaRow['iva'] as num? ?? 0).toDouble(),
      total: (ventaRow['total'] as num? ?? 0).toDouble(),
      totalPagado: (ventaRow['total_pagado'] as num? ?? 0).toDouble(),
      metodoPago: MetodoPago.desdeTexto(ventaRow['metodo_pago'] as String? ?? 'EFECTIVO'),
      estadoPago: EstadoPago.desdeTexto(ventaRow['estado_pago'] as String? ?? 'PENDIENTE'),
      creadoEn: _parseFecha(ventaRow['creado_en']),
      items: itemsRows.map(_itemDesdeMap).toList(growable: false),
    );
  }

  // ── Companions (escritura) ───────────────────────────────────────────────

  static TablaVentasCompanion companionNuevo({
    required String numeroFactura,
    required TipoVenta tipo,
    int? ordenId,
    int? clienteId,
    required MetodoPago metodoPago,
    required EstadoPago estadoPago,
    double iva = 0,
  }) =>
      TablaVentasCompanion.insert(
        numeroFactura: numeroFactura,
        tipo: Value(tipo.aTexto),
        ordenId: Value(ordenId),
        clienteId: Value(clienteId),
        metodoPago: Value(metodoPago.aTexto),
        estadoPago: Value(estadoPago.aTexto),
        iva: Value(iva),
        creadoEn: Value(DateTime.now()),
        actualizadoEn: Value(DateTime.now()),
      );

  static TablaVentaDetallesCompanion itemCompanionNuevo({
    required int ventaId,
    required TipoItem tipoItem,
    int? productoId,
    int? servicioId,
    int? tecnicoId,
    required String descripcion,
    required double cantidad,
    required double precioUnitario,
    double costoUnitario = 0,
  }) =>
      TablaVentaDetallesCompanion.insert(
        ventaId: ventaId,
        tipoItem: tipoItem.aTexto,
        productoId: Value(productoId),
        servicioId: Value(servicioId),
        tecnicoId: Value(tecnicoId),
        descripcion: descripcion,
        cantidad: Value(cantidad),
        precioUnitario: precioUnitario,
        costoUnitario: Value(costoUnitario),
        subtotal: cantidad * precioUnitario,
      );

  // ── Helpers privados ─────────────────────────────────────────────────────

  static VentaItem _itemDesdeMap(Map<String, dynamic> row) => VentaItem(
        id: row['id'] as int,
        ventaId: row['venta_id'] as int,
        tipoItem: TipoItem.desdeTexto(row['tipo_item'] as String? ?? 'PRODUCTO'),
        productoId: row['producto_id'] as int?,
        servicioId: row['servicio_id'] as int?,
        tecnicoId: row['tecnico_id'] as int?,
        descripcion: row['descripcion'] as String? ?? '',
        cantidad: (row['cantidad'] as num? ?? 1).toDouble(),
        precioUnitario: (row['precio_unitario'] as num? ?? 0).toDouble(),
        costoUnitario: (row['costo_unitario'] as num? ?? 0).toDouble(),
        subtotal: (row['subtotal'] as num? ?? 0).toDouble(),
      );

  static DateTime? _parseFecha(dynamic valor) {
    if (valor == null) return null;
    if (valor is DateTime) return valor;
    if (valor is int) return DateTime.fromMillisecondsSinceEpoch(valor);
    if (valor is String && valor.isNotEmpty) return DateTime.tryParse(valor);
    return null;
  }

  static String formatearNumero(int id) =>
      'FAC-${id.toString().padLeft(4, '0')}';
}
