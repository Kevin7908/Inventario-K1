import 'package:drift/drift.dart';

/// Cómo se agrupan los productos del catálogo.
///
/// Lleva `activo` como todo catálogo referenciado por documentos: una
/// categoría que ya no se usa se da de baja, no se borra. Borrarla dejaría sin
/// clasificar a los productos que la usaban.
///
/// **Sin color ni ícono.** Los tuvo, y era un error de modelado: cómo se pinta
/// una categoría en una rejilla es una decisión de la vista, que ya tiene sus
/// tokens en `ColoresApp`. Guardarlo aquí obligaba a elegir un color al crear
/// cada categoría, permitía dos categorías del mismo color y dejaba el diseño
/// de la app a merced de lo que alguien hubiera tecleado en 2026.
@TableIndex(name: 'idx_categorias_activo', columns: {#activo})
class TablaCategoria extends Table {
  @override
  String get tableName => 'categorias';

  IntColumn get id => integer().autoIncrement()();

  TextColumn get nombre => text().withLength(min: 1, max: 100).unique()();

  TextColumn get descripcion => text().nullable()();

  BoolColumn get activo => boolean().withDefault(const Constant(true))();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        'CHECK (length(trim(nombre)) > 0)',
      ];
}
