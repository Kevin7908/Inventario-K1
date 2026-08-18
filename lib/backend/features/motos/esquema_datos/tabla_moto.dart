import 'package:drift/drift.dart';

import '../../clientes/esquema_datos/tabla_cliente.dart';

/// La moto de un cliente.
///
/// `placa` y `vin` son únicos: dos motos no pueden compartirlos, y en un
/// taller confundirlas es confundir el trabajo. Ambos son nullable porque hay
/// motos sin papeles al día, y SQLite admite varios NULL bajo un `UNIQUE`.
@TableIndex(name: 'idx_motos_cliente', columns: {#clienteId})
@TableIndex(name: 'idx_motos_activo', columns: {#activo})
class TablaMoto extends Table {
  @override
  String get tableName => 'motos';

  IntColumn get id => integer().autoIncrement()();

  /// `restrict`: una moto con historial de taller ata a su dueño. Antes era
  /// `NO ACTION`, que en la práctica es «falla con un error críptico».
  IntColumn get clienteId =>
      integer().references(TablaCliente, #id, onDelete: KeyAction.restrict)();

  TextColumn get placa => text().nullable().unique()();
  TextColumn get marca => text()();
  TextColumn get modelo => text()();
  IntColumn get anio => integer().nullable()();

  /// Cilindraje en cc.
  IntColumn get cilindraje => integer().nullable()();

  TextColumn get color => text().nullable()();

  /// Número de chasis.
  TextColumn get vin => text().nullable().unique()();

  TextColumn get numeroMotor => text().nullable()();
  IntColumn get kilometrajeInicial => integer().withDefault(const Constant(0))();
  TextColumn get notas => text().nullable()();

  BoolColumn get activo => boolean().withDefault(const Constant(true))();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        'CHECK (length(trim(marca)) > 0)',
        'CHECK (length(trim(modelo)) > 0)',
        // Rango generoso a propósito: hay motos clásicas en los talleres.
        'CHECK (anio IS NULL OR (anio BETWEEN 1900 AND 2200))',
        'CHECK (cilindraje IS NULL OR cilindraje > 0)',
        'CHECK (kilometraje_inicial >= 0)',
      ];
}
