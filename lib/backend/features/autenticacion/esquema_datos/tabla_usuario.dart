import 'package:drift/drift.dart';

class TablaUsuario extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text().withLength(min: 2, max: 100)();

  TextColumn get usuario => text().withLength(min: 3, max: 50).unique()();

  TextColumn get email => text().withLength(min: 5, max: 150).unique()();
  TextColumn get passwordHash => text()();
  BoolColumn get esAdmin => boolean().withDefault(const Constant(false))();
  BoolColumn get estaActivo => boolean().withDefault(const Constant(true))();
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
}
