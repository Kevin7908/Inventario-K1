import 'package:drift/drift.dart';

/// En qué se especializa un técnico: mecánica general, eléctrica…
@TableIndex(name: 'idx_especializaciones_activo', columns: {#activo})
class TablaEspecializacion extends Table {
  @override
  String get tableName => 'especializaciones';

  IntColumn get id => integer().autoIncrement()();

  TextColumn get nombre => text().unique()();

  TextColumn get descripcion => text().nullable()();

  BoolColumn get activo => boolean().withDefault(const Constant(true))();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => ['CHECK (length(trim(nombre)) > 0)'];
}
