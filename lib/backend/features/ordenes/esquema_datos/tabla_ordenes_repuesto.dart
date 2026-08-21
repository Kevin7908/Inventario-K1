import 'package:drift/drift.dart';

import '../../productos/esquema_datos/tabla_producto.dart';
import 'tabla_ordenes_servicio.dart';

/// Los repuestos que se le montaron a la moto en una orden.
///
/// Agregar uno descuenta stock, y eso pasa por `RepositorioInventario` en la
/// misma transacción que la línea: no hay `UPDATE productos` suelto.
@TableIndex(name: 'idx_ordenes_repuestos_orden', columns: {#ordenId})
@TableIndex(name: 'idx_ordenes_repuestos_producto', columns: {#productoId})
class TablaOrdenesRepuesto extends Table {
  @override
  String get tableName => 'ordenes_repuestos';

  IntColumn get id => integer().autoIncrement()();

  /// `cascade`: un repuesto no existe sin su orden.
  IntColumn get ordenId => integer()
      .references(TablaOrdenesServicio, #id, onDelete: KeyAction.cascade)();

  /// `restrict`: un producto ya montado en una moto no se borra del catálogo.
  IntColumn get productoId => integer()
      .references(TablaProducto, #id, onDelete: KeyAction.restrict)();

  RealColumn get cantidad => real().withDefault(const Constant(1.0))();

  /// Precio de venta congelado al agregar el repuesto, en pesos enteros.
  IntColumn get precioUnitario => integer().withDefault(const Constant(0))();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        'CHECK (cantidad > 0)',
        'CHECK (precio_unitario >= 0)',
      ];
}
