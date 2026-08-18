import 'package:drift/drift.dart';

import '../../persona/esquema_datos/tabla_persona.dart';

/// El rol «cliente» de una persona.
///
/// Los datos de identidad y contacto no están aquí: viven en `personas`. Esta
/// tabla solo guarda lo que es propio de ser cliente del taller.
@TableIndex(name: 'idx_clientes_activo', columns: {#activo})
class TablaCliente extends Table {
  @override
  String get tableName => 'clientes';

  IntColumn get id => integer().autoIncrement()();

  /// `restrict`: borrar la persona no puede llevarse por delante su historial
  /// de facturas y deudas. Único porque nadie es cliente dos veces.
  IntColumn get personaId => integer()
      .unique()
      .references(TablaPersona, #id, onDelete: KeyAction.restrict)();

  DateTimeColumn get fechaNacimiento => dateTime().nullable()();
  TextColumn get notas => text().nullable()();
  BoolColumn get activo => boolean().withDefault(const Constant(true))();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn =>
      dateTime().withDefault(currentDateAndTime)();
}
