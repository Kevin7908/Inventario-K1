import 'package:drift/drift.dart';

// Tabla de unidades de medida en la base de datos Drift
class TablaUnidadesMedida extends Table {
  // Clave primaria autoincremental
  IntColumn get id => integer().autoIncrement()();

  // Nombre completo (ej: 'Kilogramo')
  TextColumn get nombre => text().withLength(min: 1, max: 100)();

  // Abreviatura (ej: 'kg')
  TextColumn get abreviatura => text().withLength(min: 1, max: 20)();

  // Tipo de medida: 'peso', 'volumen', 'longitud', 'unidad', etc.
  TextColumn get tipo => text().withDefault(const Constant('unidad'))();

  // Descripción opcional
  TextColumn get descripcion => text().nullable()();

  // Fecha de creación
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();

  // Fecha de última actualización
  DateTimeColumn get actualizadoEn => dateTime().withDefault(currentDateAndTime)();

  @override
  String get tableName => 'unidades_medida';
}
