import 'package:drift/drift.dart';

import '../../autenticacion/esquema_datos/tabla_usuario.dart';
import '../../tecnicos/esquema_datos/tabla_tecnico.dart';
import '../../servicios/esquema_datos/tabla_servicio.dart';
import 'tabla_ordenes_servicio.dart';

/// La mano de obra de una orden: qué trabajo, quién lo hizo y cuánto cobró.
@TableIndex(name: 'idx_ordenes_tareas_orden', columns: {#ordenId})
@TableIndex(name: 'idx_ordenes_tareas_tecnico', columns: {#tecnicoId})
// Cubre el WHERE usuarioId = ? de «qué anotó esta cuenta».
@TableIndex(name: 'idx_ordenes_tareas_usuario', columns: {#usuarioId})
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

  /// Quién anotó **esta línea**, que no siempre es quien abrió el documento:
  /// el editor guarda solo y el trabajo del taller puede pasar de un turno a otro
  /// (`REGLAS_BD.md` §7.0).
  ///
  /// `NOT NULL` y sin valor por defecto **a propósito**: así el
  /// `Companion.insert` que genera Drift lo exige como parámetro, y un método
  /// de escritura nuevo que se olvide del autor no compila. La garantía la da
  /// el compilador, no la disciplina.
  ///
  /// `restrict`: la cuenta que anotó algo no se borra mientras eso exista.
  IntColumn get usuarioId => integer()
      .references(TablaUsuario, #id, onDelete: KeyAction.restrict)();

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
