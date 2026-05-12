import 'package:drift/drift.dart';

import '../../clientes/esquema_datos/tabla_cliente.dart';


class TablaMoto extends Table {
  @override
  String get tableName => 'motos';

  IntColumn get id => integer().autoIncrement()();

  /// FK hacia clientes
  IntColumn get clienteId =>
      integer().references(TablaCliente, #id, onUpdate: KeyAction.cascade)();

  TextColumn get placa => text().nullable().unique()();
  TextColumn get marca => text()();
  TextColumn get modelo => text()();
  IntColumn get anio => integer().nullable()();
  IntColumn get cilindraje => integer().nullable()(); // cc
  TextColumn get color => text().nullable()();
  TextColumn get vin => text().nullable().unique()(); // Número de chasis
  TextColumn get numeroMotor => text().nullable()();
  IntColumn get kilometrajeInicial => integer().withDefault(const Constant(0))();
  TextColumn get notas => text().nullable()();
  IntColumn get activo => integer().withDefault(const Constant(1))();
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn => dateTime().withDefault(currentDateAndTime)();
}