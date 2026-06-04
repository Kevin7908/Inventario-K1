import 'package:drift/drift.dart';

import '../../../clientes/esquema_datos/tabla_cliente.dart';
import '../../../motos/esquema_datos/tabla_moto.dart';

class TablaOrdenesServicio extends Table {
  @override
  String get tableName => 'ordenes_servicio';

  IntColumn get id => integer().autoIncrement()();

  // FK motos(id)
  IntColumn get motoId => integer()
      .named('moto_id')
      .references(TablaMoto, #id)();

  // FK clientes(id)
  IntColumn get clienteId => integer()
      .named('cliente_id')
      .references(TablaCliente, #id)();

  IntColumn get kilometrajeEntrada =>
      integer().named('kilometraje_entrada')();

  // Lo que reporta el cliente
  TextColumn get diagnostico => text().nullable()();

  // Notas del mecánico al recibir
  TextColumn get observaciones => text().nullable()();

  // Almacenado como TEXT: 'ABIERTA' | 'LISTA' | 'ENTREGADA' | 'ANULADA'
  TextColumn get estado =>
      text().withDefault(const Constant('ABIERTA'))();

  DateTimeColumn get fechaIngreso =>
      dateTime().nullable().named('fecha_ingreso')();

  DateTimeColumn get fechaSalida =>
      dateTime().nullable().named('fecha_salida')();

  DateTimeColumn get actualizadoEn =>
      dateTime().nullable().named('actualizado_en')();
}
