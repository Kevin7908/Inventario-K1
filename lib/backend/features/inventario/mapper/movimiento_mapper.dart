import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
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
      notas: fila.notas,
      creadoEn: fila.creadoEn,
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
      notas: Value(s.notas),
    );
  }
}
