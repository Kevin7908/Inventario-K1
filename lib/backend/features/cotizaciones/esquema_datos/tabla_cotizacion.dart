import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/features/clientes/esquema_datos/tabla_cliente.dart';
import 'package:inventario_k1/backend/features/motos/esquema_datos/tabla_moto.dart';

class TablaCotizacion extends Table {
  @override
  String get tableName => 'cotizaciones';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get numero => text().unique()();
  IntColumn get clienteId => integer()
      .nullable()
      .references(TablaCliente, #id, onDelete: KeyAction.setNull)();
  IntColumn get motoId => integer()
      .nullable()
      .references(TablaMoto, #id, onDelete: KeyAction.setNull)();
  IntColumn get subtotal => integer().withDefault(const Constant(0))();
  IntColumn get iva => integer().withDefault(const Constant(0))();
  IntColumn get total => integer().withDefault(const Constant(0))();
  TextColumn get vigenciaHasta => text()();
  TextColumn get notas => text().nullable()();
  DateTimeColumn get creadoEn =>
      dateTime().withDefault(currentDateAndTime)();
}
