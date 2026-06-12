import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/features/productos/esquema_datos/tabla_producto.dart';
import 'package:inventario_k1/backend/features/reservas/esquema_datos/tabla_reserva.dart';

class TablaReservaItem extends Table {
  @override
  String get tableName => 'reserva_items';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get reservaId =>
      integer().references(TablaReserva, #id, onDelete: KeyAction.cascade)();
  IntColumn get productoId =>
      integer().references(TablaProducto, #id, onDelete: KeyAction.restrict)();
  RealColumn get cantidad => real()();
  IntColumn get precioUnitario => integer()();
}
