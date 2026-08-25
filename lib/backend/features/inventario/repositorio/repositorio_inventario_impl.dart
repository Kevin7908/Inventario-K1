import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../mapper/movimiento_mapper.dart';
import '../modelo/movimiento_inventario.dart';
import 'repositorio_inventario.dart';
import '../../../share/dominio/sesion_actual.dart';

class RepositorioInventarioImpl with FirmaDeSesion implements RepositorioInventario {
  RepositorioInventarioImpl(this._db, this.sesion);

  /// Quién firma lo que este repositorio escribe. La inyecta Riverpod
  /// desde `sesionActualProvider`: es una dependencia del constructor, no
  /// un registro global que se consulte por dentro.
  @override
  final SesionActual? sesion;

  final AppDb _db;

  $TablaMovimientoInventarioTable get _tabla => _db.tablaMovimientoInventario;

  @override
  Future<void> registrar(SolicitudMovimiento solicitud) =>
      registrarVarios([solicitud]);

  @override
  Future<void> registrarVarios(List<SolicitudMovimiento> solicitudes) {
    if (solicitudes.isEmpty) return Future.value();

    return _db.transaction(() async {
      for (final solicitud in solicitudes) {
        await _db
            .into(_tabla)
            .insert(MovimientoMapper.solicitudACompanion(solicitud, autorId));

        // El caché se ajusta con un `UPDATE` relativo y no leyendo-sumando-
        // escribiendo: así es atómico y no hay ciclo que se pueda entrelazar.
        await _db.customUpdate(
          'UPDATE productos SET stock_actual = stock_actual + ?, '
          'actualizado_en = ? WHERE id = ?',
          variables: [
            Variable.withReal(solicitud.cantidad),
            Variable.withDateTime(DateTime.now()),
            Variable.withInt(solicitud.productoId),
          ],
          updates: {_db.tablaProducto},
        );
      }
    });
  }

  @override
  Stream<List<MovimientoInventario>> observarPorProducto(int productoId) {
    return (_db.select(_tabla)
          ..where((m) => m.productoId.equals(productoId))
          ..orderBy([(m) => OrderingTerm.desc(m.creadoEn)]))
        .watch()
        .map((filas) => filas.map(MovimientoMapper.filaAModelo).toList());
  }

  @override
  Future<double> stockReconstruido(int productoId) async {
    final suma = _tabla.cantidad.sum();
    final fila = await (_db.selectOnly(_tabla)
          ..addColumns([suma])
          ..where(_tabla.productoId.equals(productoId)))
        .getSingleOrNull();
    return fila?.read(suma) ?? 0;
  }

  @override
  Future<Map<int, double>> descuadres() async {
    // Un solo `GROUP BY` contra el catálogo entero. El `LEFT JOIN` incluye a
    // los productos sin ningún movimiento: si uno de esos tiene stock, también
    // está descuadrado.
    final filas = await _db.customSelect(
      '''
      SELECT p.id AS id,
             p.stock_actual - COALESCE(SUM(m.cantidad), 0) AS diferencia
      FROM productos p
      LEFT JOIN movimientos_inventario m ON m.producto_id = p.id
      GROUP BY p.id
      HAVING ABS(diferencia) > 0.0001
      ''',
      readsFrom: {_db.tablaProducto, _tabla},
    ).get();

    return {
      for (final fila in filas)
        fila.read<int>('id'): fila.read<double>('diferencia'),
    };
  }
}
