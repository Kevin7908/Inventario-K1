import 'package:drift/drift.dart';

import '../../../clientes/esquema_datos/tabla_cliente.dart';
import '../../ordenes/esquema_datos/tabla_ordenes_servicio.dart';

class TablaVentas extends Table {
  @override
  String get tableName => 'ventas';

  IntColumn get id => integer().autoIncrement()();

  TextColumn get numeroFactura =>
      text().named('numero_factura').unique()();

  // 'SERVICIO' | 'MOSTRADOR'
  TextColumn get tipo =>
      text().withDefault(const Constant('SERVICIO'))();

  // NULL para ventas mostrador
  IntColumn get ordenId =>
      integer().nullable().named('orden_id').references(TablaOrdenesServicio, #id)();

  IntColumn get clienteId =>
      integer().nullable().named('cliente_id').references(TablaCliente, #id)();

  RealColumn get subtotal =>
      real().withDefault(const Constant(0.0))();

  RealColumn get iva =>
      real().withDefault(const Constant(0.0))();

  RealColumn get descuento =>
      real().withDefault(const Constant(0.0))();

  RealColumn get total =>
      real().withDefault(const Constant(0.0))();

  RealColumn get totalPagado =>
      real().named('total_pagado').withDefault(const Constant(0.0))();

  // 'EFECTIVO' | 'TARJETA' | 'TRANSFERENCIA' | 'CREDITO'
  TextColumn get metodoPago =>
      text().named('metodo_pago').withDefault(const Constant('EFECTIVO'))();

  // 'PAGADO' | 'PENDIENTE' | 'ANULADA'
  TextColumn get estadoPago =>
      text().named('estado_pago').withDefault(const Constant('PENDIENTE'))();

  DateTimeColumn get creadoEn =>
      dateTime().nullable().named('creado_en')();

  DateTimeColumn get actualizadoEn =>
      dateTime().nullable().named('actualizado_en')();
}
