import 'package:drift/drift.dart';

import '../../persona/esquema_datos/tabla_persona.dart';

/// La cuenta de acceso de una persona.
///
/// El nombre y el correo no están aquí: vienen de `personas`. Esta tabla solo
/// guarda lo que hace falta para entrar a la app.
class TablaUsuario extends Table {
  @override
  String get tableName => 'usuarios';

  IntColumn get id => integer().autoIncrement()();

  /// `restrict`: una cuenta borrada no puede llevarse a la persona, que puede
  /// ser además técnico o cliente.
  IntColumn get personaId => integer()
      .unique()
      .references(TablaPersona, #id, onDelete: KeyAction.restrict)();

  /// Con lo que se inicia sesión. Se guarda normalizado en minúsculas.
  TextColumn get usuario => text().withLength(min: 3, max: 50).unique()();

  TextColumn get passwordHash => text()();
  BoolColumn get esAdmin => boolean().withDefault(const Constant(false))();
  BoolColumn get estaActivo => boolean().withDefault(const Constant(true))();
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
}
