import 'package:drift/drift.dart';

import '../../pos/esquema_datos/tabla_venta_detalles.dart';
import 'tabla_devolucion.dart';

/// Cuánto se devolvió de una línea concreta de la factura.
///
/// Apunta a `venta_detalles` y no a `productos` a propósito: lo que se devuelve
/// es *esa* línea de *esa* venta, con el precio al que se cobró. El producto,
/// la descripción congelada y el tipo de ítem se leen por `JOIN` desde ahí —no
/// se copian, que sería la duplicación que prohíbe §1.1—; el único snapshot
/// propio es [precioUnitario], porque una segunda devolución de la misma línea
/// tiene que valer lo mismo que la primera aunque el catálogo haya cambiado.
///
/// **Que la suma devuelta no pase de lo vendido no lo puede decir un `CHECK`**:
/// necesita un agregado sobre las demás filas. Lo cierra la guarda
/// `guarda_devolucion_no_excede_vendido` de `guardas_sql.dart`; el repositorio
/// valida antes para poder dar el mensaje.
@TableIndex(name: 'idx_devolucion_detalles_devolucion', columns: {#devolucionId})
// Cubre el `WHERE venta_detalle_id IN (...)` con el que se calcula cuánto
// queda por devolver de cada línea, y el `SELECT SUM` de la guarda.
@TableIndex(name: 'idx_devolucion_detalles_linea', columns: {#ventaDetalleId})
class TablaDevolucionDetalle extends Table {
  @override
  String get tableName => 'devolucion_detalles';

  IntColumn get id => integer().autoIncrement()();

  /// `cascade`: una línea no existe sin su documento.
  IntColumn get devolucionId => integer()
      .references(TablaDevolucion, #id, onDelete: KeyAction.cascade)();

  /// `restrict`: la línea de la factura que se está devolviendo no puede
  /// borrarse mientras exista este renglón que la explica.
  IntColumn get ventaDetalleId => integer()
      .references(TablaVentaDetalles, #id, onDelete: KeyAction.restrict)();

  /// `REAL` como el resto de las cantidades del esquema.
  RealColumn get cantidad => real()();

  /// El precio al que se vendió, congelado (`REGLAS_BD.md` §1.2).
  IntColumn get precioUnitario => integer()();

  @override
  List<String> get customConstraints => [
        'CHECK (cantidad > 0)',
        'CHECK (precio_unitario >= 0)',
      ];

  /// Una línea de la factura no se repite dentro de la misma devolución: si el
  /// cliente trae dos de la misma pieza, es una fila con cantidad 2. Devolver
  /// otra la semana que viene es **otra** devolución.
  @override
  List<Set<Column>> get uniqueKeys => [
        {devolucionId, ventaDetalleId},
      ];
}
