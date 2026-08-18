import 'package:drift/drift.dart';

import '../../productos/esquema_datos/tabla_producto.dart';
import '../../reservas/esquema_datos/tabla_reserva.dart';
import '../../ventas/facturas/esquema_datos/tabla_ventas.dart';
import '../../ventas/ordenes/esquema_datos/tabla_ordenes_servicio.dart';

/// El libro mayor del inventario: toda variación de stock deja aquí su
/// renglón.
///
/// Antes el stock se modificaba con seis `UPDATE productos SET stock_actual =
/// stock_actual ± ?` repartidos por facturas, órdenes, reservas y productos.
/// No había forma de saber quién descontó qué, ni de reconstruir el inventario
/// cuando una venta se anulaba mal. Ahora `productos.stock_actual` es un caché
/// de `SUM(cantidad)` de esta tabla y solo `RepositorioInventario` escribe las
/// dos, siempre en la misma transacción.
///
/// **[cantidad] lleva signo**: positivo entra, negativo sale. Guardar el signo
/// en la cantidad y no deducirlo del [tipo] hace que reconstruir el stock sea
/// un `SUM` y no un `CASE` de diez ramas. El [tipo] dice *por qué*, no
/// *hacia dónde*.
///
/// No se guardan `stock_anterior` ni `stock_nuevo`, que es lo que suele
/// llevar una tabla así: los dos se deducen —uno de la suma de los
/// movimientos previos, el otro de sumarle [cantidad]—, y una columna que se
/// deduce de otras de su misma fila es justo lo que la 3FN prohíbe. El
/// descuadre se detecta comparando el caché con el `SUM`, no leyendo una fila.
@TableIndex(
  name: 'idx_movimientos_producto_fecha',
  columns: {#productoId, #creadoEn},
)
@TableIndex(name: 'idx_movimientos_tipo', columns: {#tipo})
class TablaMovimientoInventario extends Table {
  @override
  String get tableName => 'movimientos_inventario';

  IntColumn get id => integer().autoIncrement()();

  /// `restrict`: borrar un producto con historial de movimientos destruiría la
  /// trazabilidad de lo que ya se vendió.
  IntColumn get productoId => integer()
      .references(TablaProducto, #id, onDelete: KeyAction.restrict)();

  /// Por qué se movió. Los valores están acotados por `CHECK`; el enum de Dart
  /// es la comodidad, no la garantía.
  TextColumn get tipo => text()();

  /// Con signo: `+` entra al inventario, `−` sale. Nunca cero.
  RealColumn get cantidad => real()();

  /// De qué documento vino el movimiento. Son tres columnas y no un par
  /// `referencia_tipo` / `referencia_id` a propósito: una FK polimórfica no la
  /// puede verificar la base, y el `CHECK` de abajo garantiza que como mucho
  /// una esté puesta. Un ajuste manual las deja las tres en NULL.
  ///
  /// `setNull` en las tres: si el documento desaparece, el movimiento sigue
  /// contando para el stock aunque pierda su origen.
  IntColumn get ventaId => integer()
      .nullable()
      .references(TablaVentas, #id, onDelete: KeyAction.setNull)();

  IntColumn get ordenId => integer()
      .nullable()
      .references(TablaOrdenesServicio, #id, onDelete: KeyAction.setNull)();

  IntColumn get reservaId => integer()
      .nullable()
      .references(TablaReserva, #id, onDelete: KeyAction.setNull)();

  TextColumn get notas => text().nullable()();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        "CHECK (tipo IN ("
            "'AJUSTE_INICIAL', 'AJUSTE_POSITIVO', 'AJUSTE_NEGATIVO', "
            "'ENTRADA_COMPRA', 'SALIDA_VENTA', 'SALIDA_SERVICIO', "
            "'SALIDA_RESERVA', 'DEVOLUCION_VENTA', 'DEVOLUCION_SERVICIO', "
            "'DEVOLUCION_RESERVA'))",
        'CHECK (cantidad <> 0)',
        'CHECK ((venta_id IS NOT NULL) + (orden_id IS NOT NULL) + '
            '(reserva_id IS NOT NULL) <= 1)',
      ];
}
