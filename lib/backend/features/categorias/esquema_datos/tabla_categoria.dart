import 'package:drift/drift.dart';

/// Cómo se agrupan los productos del catálogo.
///
/// Lleva `activo` como todo catálogo referenciado por documentos: una
/// categoría que ya no se usa se da de baja, no se borra. Borrarla dejaría sin
/// clasificar a los productos que la usaban.
@TableIndex(name: 'idx_categorias_activo', columns: {#activo})
class TablaCategoria extends Table {
  @override
  String get tableName => 'categorias';

  IntColumn get id => integer().autoIncrement()();

  TextColumn get nombre => text().withLength(min: 1, max: 100).unique()();

  TextColumn get descripcion => text().nullable()();

  /// Color en hexadecimal, del estilo `#3B82F6`. Lo interpreta la vista: el
  /// backend no conoce `Color`.
  TextColumn get colorHex => text().withDefault(const Constant('#3B82F6'))();

  /// Nombre del ícono de Material, como texto.
  TextColumn get icono => text().withDefault(const Constant('category'))();

  BoolColumn get activo => boolean().withDefault(const Constant(true))();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        'CHECK (length(trim(nombre)) > 0)',
        // Seis dígitos hexadecimales detrás de una almohadilla.
        r"CHECK (color_hex GLOB '#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]"
            r"[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]')",
      ];
}
