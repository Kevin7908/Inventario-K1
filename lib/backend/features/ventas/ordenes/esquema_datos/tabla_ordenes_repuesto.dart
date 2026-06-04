import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/features/ventas/ordenes/esquema_datos/tabla_ordenes_servicio.dart';

import '../../../productos/esquema_datos/tabla_producto.dart';

class TablaOrdenesRepuesto extends Table {
  @override
  String get tableName => 'ordenes_repuestos';

  IntColumn get id => integer().autoIncrement()();

  // FK ordenes_servicio(id) ON DELETE CASCADE
  IntColumn get ordenId => integer()
      .named('orden_id')
      .references(TablaOrdenesServicio, #id, onDelete: KeyAction.cascade)();

  // FK productos(id)
  IntColumn get productoId => integer()
      .named('producto_id')
      .references(TablaProducto, #id)();

  RealColumn get cantidad =>
      real().withDefault(const Constant(1.0))();

  // Precio de venta capturado del maestro al momento de agregar
  RealColumn get precioUnitario =>
      real().named('precio_unitario').withDefault(const Constant(0.0))();

  DateTimeColumn get creadoEn =>
      dateTime().nullable().named('creado_en')();
}