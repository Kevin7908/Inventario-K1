import 'package:drift/drift.dart';

import '../../../clientes/esquema_datos/tabla_cliente.dart';
import '../../../motos/esquema_datos/tabla_moto.dart';

/// La moto mientras está en el taller.
///
/// A diferencia de la factura, la orden es un registro de trabajo: se puede
/// editar mientras está `ABIERTA`. Una vez `ENTREGADA` o `ANULADA` queda
/// cerrada, y una guarda de la base impide seguir agregándole tareas o
/// repuestos (ver `guardas_sql.dart`).
@TableIndex(name: 'idx_ordenes_moto', columns: {#motoId})
@TableIndex(name: 'idx_ordenes_cliente', columns: {#clienteId})
@TableIndex(name: 'idx_ordenes_estado', columns: {#estado})
@TableIndex(name: 'idx_ordenes_ingreso', columns: {#fechaIngreso})
class TablaOrdenesServicio extends Table {
  @override
  String get tableName => 'ordenes_servicio';

  IntColumn get id => integer().autoIncrement()();

  /// `restrict` en las dos: una moto o un cliente con historial de taller no
  /// se borran.
  IntColumn get motoId =>
      integer().references(TablaMoto, #id, onDelete: KeyAction.restrict)();

  IntColumn get clienteId =>
      integer().references(TablaCliente, #id, onDelete: KeyAction.restrict)();

  IntColumn get kilometrajeEntrada => integer()();

  /// Lo que reporta el cliente.
  TextColumn get diagnostico => text().nullable()();

  /// Notas del mecánico al recibir.
  TextColumn get observaciones => text().nullable()();

  /// 'ABIERTA' | 'LISTA' | 'ENTREGADA' | 'ANULADA'.
  TextColumn get estado => text().withDefault(const Constant('ABIERTA'))();

  DateTimeColumn get fechaIngreso =>
      dateTime().withDefault(currentDateAndTime)();

  /// Se llena al pasar a `ENTREGADA`.
  DateTimeColumn get fechaSalida => dateTime().nullable()();

  DateTimeColumn get actualizadoEn =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        "CHECK (estado IN ('ABIERTA', 'LISTA', 'ENTREGADA', 'ANULADA'))",
        'CHECK (kilometraje_entrada >= 0)',
        'CHECK (fecha_salida IS NULL OR fecha_salida >= fecha_ingreso)',
      ];
}
