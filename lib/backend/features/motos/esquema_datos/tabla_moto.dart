import 'package:drift/drift.dart';

import '../../clientes/esquema_datos/tabla_cliente.dart';

/// La moto de un cliente.
///
/// `placa` es única: dos motos no pueden compartirla, y en un taller
/// confundirlas es confundir el trabajo. Es nullable porque hay motos sin
/// papeles al día, y SQLite admite varios NULL bajo un `UNIQUE`.
///
/// **Sin número de chasis ni kilometraje inicial.** El chasis no se usaba para
/// nada que la placa no resolviera, y el kilometraje de una moto cambia cada
/// vez que entra al taller: guardar el «inicial» era una foto de un dato vivo
/// que nadie volvía a mirar. Si algún día hace falta seguirlo, va en la orden
/// de servicio —que es donde se toma— y no en la ficha de la moto.
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

  TextColumn get numeroMotor => text().nullable()();
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
      ];
}
