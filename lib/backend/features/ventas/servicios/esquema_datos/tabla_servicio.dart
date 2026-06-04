import 'package:drift/drift.dart';

class TablaServicio extends Table {
  @override
  String get tableName => 'servicios';

  IntColumn get id => integer().autoIncrement()();

  TextColumn get nombre => text().withLength(min: 2, max: 120).unique()();

  TextColumn get descripcion => text().nullable()();

  BoolColumn get activo => boolean().withDefault(const Constant(true))();

  TextColumn get creadoEn => text().nullable().named('creado_en')();
}
