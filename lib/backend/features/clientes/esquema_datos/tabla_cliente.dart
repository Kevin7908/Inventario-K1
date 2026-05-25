import 'package:drift/drift.dart';

class TablaCliente extends Table {
  @override
  String get tableName => 'clientes';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get cedula => text().nullable().unique()();
  TextColumn get nombres => text()();
  TextColumn get apellidos => text().nullable()();
  TextColumn get telefono => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get direccion => text().nullable()();
  TextColumn get ciudad => text().nullable()();
  TextColumn get fechaNacimiento => text().nullable()();
  TextColumn get notas => text().nullable()();
  IntColumn get activo => integer().withDefault(const Constant(1))();
  DateTimeColumn get creadoEn =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn =>
      dateTime().withDefault(currentDateAndTime)();
}