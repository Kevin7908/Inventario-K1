import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/features/ventas/ordenes/esquema_datos/tabla_ordenes_servicio.dart';
import 'package:inventario_k1/backend/features/ventas/servicios/esquema_datos/tabla_servicio.dart';

import '../../../tecnicos/esquema_datos/tabla_tecnico.dart';

class TablaOrdenesTarea extends Table {
  @override
  String get tableName => 'ordenes_tareas';

  IntColumn get id => integer().autoIncrement()();

  // FK ordenes_servicio(id) ON DELETE CASCADE
  IntColumn get ordenId => integer()
      .named('orden_id')
      .references(TablaOrdenesServicio, #id, onDelete: KeyAction.cascade)();

  // FK servicios(id)
  IntColumn get servicioId => integer()
      .named('servicio_id')
      .references(TablaServicio, #id)();

  // FK tecnicos(id)
  IntColumn get tecnicoId => integer()
      .named('tecnico_id')
      .references(TablaTecnico, #id)();

  // Precio que cobró el técnico esta vez
  RealColumn get precioPactado =>
      real().named('precio_pactado').withDefault(const Constant(0.0))();

  // Notas específicas de esta tarea
  TextColumn get notas => text().nullable()();

  // 1 = completado, 0 = pendiente
  BoolColumn get completado =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get creadoEn =>
      dateTime().nullable().named('creado_en')();
}
