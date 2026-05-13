import 'package:drift/drift.dart';

import '../../especializacion/esquema_datos/tabla_especializacion.dart';

class TablaTecnico extends Table {

  IntColumn get id => integer().autoIncrement()();
  TextColumn get cedula => text().nullable().unique()();
  TextColumn get nombres => text()();
  TextColumn get apellidos => text().nullable()();
  TextColumn get telefono => text().nullable()();
  TextColumn get email => text().nullable()();
  IntColumn get especializacionId =>
      integer().nullable().references(TablaEspecializacion, #id)();
  RealColumn get salarioBase => real().nullable()();
  BoolColumn get activo =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get creadoEn =>
      dateTime().withDefault(currentDateAndTime)();
}
