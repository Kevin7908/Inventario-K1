import 'package:drift/drift.dart';

import '../../../share/dominio/metodo_pago.dart';
import 'tabla_deudor.dart';

/// Cada abono contra una deuda.
///
/// Es la fuente de verdad de `deudores.monto_pagado`, que solo es su suma
/// cacheada. Como el libro mayor del inventario y los abonos de reserva, se
/// escribe y no se corrige.
///
/// **Un monto negativo es una devolución.** Aparece cuando se quita una línea
/// de una deuda que ya tenía abonos y el total cae por debajo de lo entregado:
/// esa diferencia hay que regresarla, y queda escrita como un movimiento más
/// en vez de corregir los abonos viejos. Por eso el `CHECK` es `<> 0` y no
/// `> 0`, igual que en `reserva_abonos`.
// Índice compuesto: cubre WHERE deudorId = ? ORDER BY fechaPago ASC en _cargarPagos
@TableIndex(name: 'idx_pagos_deudor_fecha', columns: {#deudorId, #fechaPago})
class TablaDeudorPago extends Table {
  @override
  String get tableName => 'deudor_pagos';

  IntColumn get id => integer().autoIncrement()();

  /// `cascade`: un pago no existe sin su deuda.
  IntColumn get deudorId =>
      integer().references(TablaDeudor, #id, onDelete: KeyAction.cascade)();

  /// En pesos enteros. Siempre positivo.
  IntColumn get monto => integer()();

  /// Uno de [MetodoPago], sin `CREDITO`: quien abona entrega dinero.
  TextColumn get metodoPago => text()();

  TextColumn get notas => text().nullable()();

  DateTimeColumn get fechaPago => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        'CHECK (monto <> 0)',
        'CHECK (metodo_pago IN (${MetodoPago.listaSqlAbonos}))',
      ];
}
