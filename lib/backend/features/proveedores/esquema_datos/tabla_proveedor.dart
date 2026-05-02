import 'package:drift/drift.dart';

class TablaProveedor extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text()();
  TextColumn get nitCedula => text().nullable()();
  TextColumn get contacto => text().nullable()();
  TextColumn get telefono => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get direccion => text().nullable()();
  TextColumn get ciudad => text().nullable()();
  TextColumn get notas => text().nullable()();
  BoolColumn get activo => boolean().withDefault(const Constant(true))();
  TextColumn get colorHex => text().withDefault(const Constant('#3B82F6'))();
  TextColumn get icono => text().withDefault(const Constant('store'))();
  DateTimeColumn get creadoEn => dateTime().nullable()();
  DateTimeColumn get actualizadoEn => dateTime().nullable()();

  @override
  String get tableName => 'proveedores';
}
