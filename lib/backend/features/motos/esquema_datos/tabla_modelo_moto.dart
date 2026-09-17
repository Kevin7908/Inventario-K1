import 'package:drift/drift.dart';

import 'tabla_marca_moto.dart';

/// Un modelo concreto dentro de una marca: «FZ 2.0» de Yamaha, «Boxer CT100»
/// de Bajaj.
///
/// **El cilindraje vive aquí y no en `motos`** porque es del modelo, no del
/// ejemplar: todas las Boxer CT100 son de 100 cc. Que estuviera en cada moto
/// era el mismo dato repetido una vez por cliente (§1.1), con la puerta
/// abierta a que dos motos idénticas dijeran cosas distintas.
///
/// El nombre es único **dentro de la marca**, no en toda la tabla: «Discover»
/// puede existir en dos marcas sin que una estorbe a la otra.
@TableIndex(name: 'idx_modelos_moto_marca', columns: {#marcaId})
@TableIndex(name: 'idx_modelos_moto_activo', columns: {#activo})
class TablaModeloMoto extends Table {
  @override
  String get tableName => 'modelos_moto';

  IntColumn get id => integer().autoIncrement()();

  /// `restrict`: una marca con modelos no se borra. La baja es lógica (§1.4).
  IntColumn get marcaId => integer()
      .references(TablaMarcaMoto, #id, onDelete: KeyAction.restrict)();

  TextColumn get nombre => text()();

  /// Cilindraje en cc. Nullable porque hay modelos que el taller da de alta
  /// sabiendo solo el nombre —el dato aparece cuando llega la primera moto—.
  IntColumn get cilindraje => integer().nullable()();

  BoolColumn get activo => boolean().withDefault(const Constant(true))();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        'CHECK (length(trim(nombre)) > 0)',
        'CHECK (cilindraje IS NULL OR cilindraje > 0)',
      ];

  /// El mismo modelo no se repite dentro de una marca.
  @override
  List<Set<Column>> get uniqueKeys => [
        {marcaId, nombre},
      ];
}
