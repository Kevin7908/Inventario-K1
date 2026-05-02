import 'package:drift/drift.dart';

// Tabla de categorías en la base de datos Drift
class TablaCategoria extends Table {
  // Clave primaria autoincremental
  IntColumn get id => integer().autoIncrement()();

  // Nombre de la categoría (único y requerido)
  TextColumn get nombre => text().withLength(min: 1, max: 100)();

  // Descripción opcional de la categoría
  TextColumn get descripcion => text().nullable()();

  // Color en formato hex (ej: '#3B82F6')
  TextColumn get colorHex => text().withDefault(const Constant('#3B82F6'))();

  // Ícono (nombre del ícono de Material Icons como string)
  TextColumn get icono => text().withDefault(const Constant('category'))();

  // Fecha de creación
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();

  // Fecha de última actualización
  DateTimeColumn get actualizadoEn =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  String get tableName => 'categorias';
}
