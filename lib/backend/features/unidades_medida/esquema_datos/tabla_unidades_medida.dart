import 'package:drift/drift.dart';

/// En qué se mide un producto: unidad, litro, metro…
///
/// Lleva `activo` por el mismo motivo que las categorías: los productos la
/// referencian, así que se da de baja en vez de borrarse.
@TableIndex(name: 'idx_unidades_activo', columns: {#activo})
class TablaUnidadesMedida extends Table {
  @override
  String get tableName => 'unidades_medida';

  IntColumn get id => integer().autoIncrement()();

  /// Nombre completo, del estilo «Kilogramo».
  TextColumn get nombre => text().withLength(min: 1, max: 100).unique()();

  /// Abreviatura, del estilo «kg».
  TextColumn get abreviatura => text().withLength(min: 1, max: 20)();

  /// `peso` | `volumen` | `longitud` | `unidad`.
  TextColumn get tipo => text().withDefault(const Constant('unidad'))();

  TextColumn get descripcion => text().nullable()();

  BoolColumn get activo => boolean().withDefault(const Constant(true))();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        'CHECK (length(trim(nombre)) > 0)',
        'CHECK (length(trim(abreviatura)) > 0)',
      ];
}
