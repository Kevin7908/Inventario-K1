import 'package:drift/drift.dart';

import '../../clientes/esquema_datos/tabla_cliente.dart';
import '../../pos/esquema_datos/tabla_ventas.dart';

/// Lo que un cliente debe, con sus pagos.
///
/// `monto_pagado` es un **caché** de `SUM(deudor_pagos.monto)`. Solo lo
/// escribe `RepositorioDeudores`, que lo recalcula entero en cada pago;
/// `descuadres()` comprueba que coincida con la suma, que es lo que justifica
/// tenerlo.
///
/// `VENCIDA` es un estado guardado y a la vez calculable desde
/// `fecha_vencimiento`. Se guarda porque el usuario puede marcar una deuda
/// como vencida antes de tiempo —o dejarla activa después—, así que no es una
/// función de la fecha: es una decisión. `DeudorResumen.estaVencida` responde
/// la otra pregunta, la del calendario.
@TableIndex(name: 'idx_deudores_estado', columns: {#estado})
@TableIndex(name: 'idx_deudores_cliente', columns: {#clienteId})
@TableIndex(name: 'idx_deudores_creado', columns: {#creadoEn})
@TableIndex(name: 'idx_deudores_vencimiento', columns: {#fechaVencimiento})
class TablaDeudor extends Table {
  @override
  String get tableName => 'deudores';

  IntColumn get id => integer().autoIncrement()();

  TextColumn get numero => text().unique()();

  /// `restrict`: no se borra a quien debe.
  IntColumn get clienteId =>
      integer().references(TablaCliente, #id, onDelete: KeyAction.restrict)();

  /// La factura que originó la deuda, si la hubo. `setNull`: la deuda sigue
  /// existiendo aunque la factura desaparezca.
  IntColumn get ventaId => integer()
      .nullable()
      .references(TablaVentas, #id, onDelete: KeyAction.setNull)();

  TextColumn get concepto => text()();

  /// Los dos en pesos enteros.
  IntColumn get montoTotal => integer()();
  IntColumn get montoPagado => integer().withDefault(const Constant(0))();

  /// `ACTIVA` | `VENCIDA` | `PAGADA` | `INCOBRABLE`.
  TextColumn get estado => text().withDefault(const Constant('ACTIVA'))();

  /// Fecha sin hora, a medianoche. `null` = sin plazo pactado.
  DateTimeColumn get fechaVencimiento => dateTime().nullable()();

  TextColumn get notas => text().nullable()();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        "CHECK (estado IN ('ACTIVA', 'VENCIDA', 'PAGADA', 'INCOBRABLE'))",
        'CHECK (length(trim(numero)) > 0)',
        'CHECK (length(trim(concepto)) > 0)',
        'CHECK (monto_total > 0 AND monto_pagado >= 0)',
        // Recibir más de lo debido es siempre un error de captura.
        'CHECK (monto_pagado <= monto_total)',
      ];
}
