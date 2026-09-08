import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../../../share/utils/fecha_sqlite.dart';
import '../modelo/movimiento_detalle.dart';
import '../modelo/movimiento_inventario.dart';

abstract final class MovimientoMapper {
  MovimientoMapper._();

  static MovimientoInventario filaAModelo(TablaMovimientoInventarioData fila) {
    return MovimientoInventario(
      id: fila.id,
      productoId: fila.productoId,
      tipo: TipoMovimiento.desdeCodigo(fila.tipo),
      cantidad: fila.cantidad,
      ventaId: fila.ventaId,
      ordenId: fila.ordenId,
      reservaId: fila.reservaId,
      deudorId: fila.deudorId,
      compraId: fila.compraId,
      notas: fila.notas,
      creadoEn: fila.creadoEn,
    );
  }

  /// El kardex va por `customSelect` —necesita cinco `LEFT JOIN` para
  /// resolver el documento de origen—, así que la fila llega como mapa crudo
  /// y no como `TablaMovimientoInventarioData`.
  static MovimientoDetalle detalleDesdeMapa(Map<String, dynamic> f) {
    return MovimientoDetalle(
      movimiento: MovimientoInventario(
        id: f['id'] as int,
        productoId: f['producto_id'] as int,
        tipo: TipoMovimiento.desdeCodigo(f['tipo'] as String),
        cantidad: (f['cantidad'] as num).toDouble(),
        ventaId: f['venta_id'] as int?,
        ordenId: f['orden_id'] as int?,
        reservaId: f['reserva_id'] as int?,
        deudorId: f['deudor_id'] as int?,
        compraId: f['compra_id'] as int?,
        notas: f['notas'] as String?,
        creadoEn: fechaDeSqliteObligatoria(f['creado_en']),
      ),
      productoNombre: f['producto_nombre'] as String? ?? '',
      productoSku: f['producto_sku'] as String? ?? '',
      usuario: (f['usuario'] as String? ?? '').trim(),
      numeroDocumento: f['numero_documento'] as String?,
    );
  }

  /// [usuarioId] no viene en la solicitud sino aparte: quien mueve stock es
  /// quien tiene la sesión abierta, y eso lo sabe el repositorio, no cada uno
  /// de los diez sitios que piden un movimiento.
  static TablaMovimientoInventarioCompanion solicitudACompanion(
    SolicitudMovimiento s,
    int usuarioId,
  ) {
    return TablaMovimientoInventarioCompanion.insert(
      usuarioId: usuarioId,
      productoId: s.productoId,
      tipo: s.tipo.codigo,
      cantidad: s.cantidad,
      ventaId: Value(s.ventaId),
      ordenId: Value(s.ordenId),
      reservaId: Value(s.reservaId),
      deudorId: Value(s.deudorId),
      compraId: Value(s.compraId),
      notas: Value(s.notas),
    );
  }
}
