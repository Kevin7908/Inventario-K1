import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/features/clientes/esquema_datos/tabla_cliente.dart';
import 'package:inventario_k1/backend/features/cotizaciones/esquema_datos/tabla_cotizacion.dart';
import 'package:inventario_k1/backend/features/motos/esquema_datos/tabla_moto.dart';

class TablaReserva extends Table {
  @override
  String get tableName => 'reservas';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get numero => text().unique()();
  IntColumn get clienteId =>
      integer().references(TablaCliente, #id, onDelete: KeyAction.restrict)();
  IntColumn get motoId =>
      integer().nullable().references(TablaMoto, #id, onDelete: KeyAction.setNull)();
  IntColumn get cotizacionId =>
      integer().nullable().references(TablaCotizacion, #id, onDelete: KeyAction.setNull)();
  TextColumn get estado =>
      text().withDefault(const Constant('ACTIVA'))();
  IntColumn get totalReserva => integer()();
  IntColumn get pagadoAcumulado =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get creadoEn =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get fechaLimite => text().nullable()();
  DateTimeColumn get actualizadoEn =>
      dateTime().withDefault(currentDateAndTime)();
}
