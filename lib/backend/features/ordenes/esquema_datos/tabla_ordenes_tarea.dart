import 'package:drift/drift.dart';

import '../../../tecnicos/esquema_datos/tabla_tecnico.dart';
import '../../servicios/esquema_datos/tabla_servicio.dart';
import 'tabla_ordenes_servicio.dart';

/// La mano de obra de una orden: qué trabajo, quién lo hizo y cuánto cobró.
@TableIndex(name: 'idx_ordenes_tareas_orden', columns: {#ordenId})
@TableIndex(name: 'idx_ordenes_tareas_tecnico', columns: {#tecnicoId})
class TablaOrdenesTarea extends Table {
  @override
  String get tableName => 'ordenes_tareas';

  IntColumn get id => integer().autoIncrement()();

  /// `cascade`: una tarea no existe sin su orden.
  IntColumn get ordenId => integer()
      .references(TablaOrdenesServicio, #id, onDelete: KeyAction.cascade)();

  /// `restrict`: un servicio con trabajos hechos no se borra del catálogo.
  IntColumn get servicioId => integer()
      .references(TablaServicio, #id, onDelete: KeyAction.restrict)();

  /// `restrict`: borrar al técnico dejaría trabajos sin autor.
  IntColumn get tecnicoId => integer()
      .references(TablaTecnico, #id, onDelete: KeyAction.restrict)();

  /// Lo que cobró el técnico **esta vez**, en pesos enteros. Es un dato
  /// propio de la tarea, no una copia del catálogo: `servicios.precio_sugerido`
  /// solo precarga el campo.
  IntColumn get precioPactado => integer().withDefault(const Constant(0))();

  TextColumn get notas => text().nullable()();

  BoolColumn get completado => boolean().withDefault(const Constant(false))();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => ['CHECK (precio_pactado >= 0)'];
}
