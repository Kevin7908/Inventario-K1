import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/features/deudores/esquema_datos/tabla_deudor.dart';

// Índice compuesto: cubre WHERE deudorId = ? ORDER BY fechaPago ASC en _cargarPagos
@TableIndex(name: 'idx_pagos_deudor_fecha', columns: {#deudorId, #fechaPago})
class TablaDeudorPago extends Table {
  @override
  String get tableName => 'deudor_pagos';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get deudorId =>
      integer().references(TablaDeudor, #id, onDelete: KeyAction.cascade)();
  IntColumn get monto => integer()();
  TextColumn get metodoPago => text()();
  TextColumn get notas => text().nullable()();
  DateTimeColumn get fechaPago => dateTime().withDefault(currentDateAndTime)();
}
