import 'package:drift/drift.dart';

class TablaServicio extends Table {
  @override
  String get tableName => 'servicios';

  IntColumn get id => integer().autoIncrement()();

  TextColumn get nombre => text().withLength(min: 2, max: 120).unique()();

  TextColumn get descripcion => text().nullable()();

  /// Lo que se suele cobrar por este trabajo, en pesos enteros.
  ///
  /// Es **sugerido**, no fijo: precarga el campo al cotizar y al abrir una
  /// tarea de orden, y desde ahí se puede ajustar. Lo que de verdad se cobró
  /// queda en `cotizacion_items.precio_unitario` o en
  /// `ordenes_tareas.precio_pactado`, según el documento; aquí no se
  /// sobrescribe. `0` = todavía no hay referencia y el campo llega vacío.
  IntColumn get precioSugerido =>
      integer().named('precio_sugerido').withDefault(const Constant(0))();

  BoolColumn get activo => boolean().withDefault(const Constant(true))();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => ['CHECK (precio_sugerido >= 0)'];
}
