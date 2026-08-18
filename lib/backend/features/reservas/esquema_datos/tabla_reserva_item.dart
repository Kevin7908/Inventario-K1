import 'package:drift/drift.dart';

import '../../productos/esquema_datos/tabla_producto.dart';
import 'tabla_reserva.dart';

/// Lo que se apartó: un producto y su cantidad, al precio pactado ese día.
///
/// Apartar saca el producto del inventario disponible aunque siga en la
/// bodega, así que cada línea tiene su movimiento en `movimientos_inventario`.
@TableIndex(name: 'idx_reserva_items_reserva', columns: {#reservaId})
@TableIndex(name: 'idx_reserva_items_producto', columns: {#productoId})
class TablaReservaItem extends Table {
  @override
  String get tableName => 'reserva_items';

  IntColumn get id => integer().autoIncrement()();

  /// `cascade`: una línea no existe sin su reserva.
  IntColumn get reservaId => integer()
      .references(TablaReserva, #id, onDelete: KeyAction.cascade)();

  /// `restrict`: un producto apartado no se borra del catálogo.
  IntColumn get productoId => integer()
      .references(TablaProducto, #id, onDelete: KeyAction.restrict)();

  RealColumn get cantidad => real()();

  /// Precio congelado al apartar, en pesos enteros.
  IntColumn get precioUnitario => integer()();

  @override
  List<String> get customConstraints => [
        'CHECK (cantidad > 0)',
        'CHECK (precio_unitario >= 0)',
      ];
}
