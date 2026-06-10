import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/features/clientes/esquema_datos/tabla_cliente.dart';
import 'package:inventario_k1/backend/features/ventas/facturas/esquema_datos/tabla_ventas.dart';

// Índices para búsquedas frecuentes por estado, cliente y orden cronológico
@TableIndex(name: 'idx_deudores_estado', columns: {#estado})
@TableIndex(name: 'idx_deudores_cliente', columns: {#clienteId})
@TableIndex(name: 'idx_deudores_creado', columns: {#creadoEn})
class TablaDeudor extends Table {
  @override
  String get tableName => 'deudores';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get numero => text().unique()();
  IntColumn get clienteId =>
      integer().references(TablaCliente, #id, onDelete: KeyAction.restrict)();
  IntColumn get ventaId =>
      integer().nullable().references(TablaVentas, #id, onDelete: KeyAction.setNull)();
  TextColumn get concepto => text()();
  IntColumn get montoTotal => integer()();
  IntColumn get montoPagado => integer().withDefault(const Constant(0))();
  TextColumn get estado => text().withDefault(const Constant('ACTIVA'))();
  TextColumn get fechaVencimiento => text().nullable()();
  TextColumn get notas => text().nullable()();
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn => dateTime().withDefault(currentDateAndTime)();
}
