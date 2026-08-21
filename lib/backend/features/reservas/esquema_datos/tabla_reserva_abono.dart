import 'package:drift/drift.dart';

import '../../../share/dominio/metodo_pago.dart';
import 'tabla_reserva.dart';

/// Cada entrega de dinero contra una reserva.
///
/// Es la fuente de verdad de `reservas.pagado_acumulado`, que solo es su suma
/// cacheada. Como el libro mayor del inventario, esta tabla se escribe y no se
/// corrige: devolver un abono es registrar otro, no editar el de ayer.
@TableIndex(name: 'idx_reserva_abonos_reserva_fecha',
    columns: {#reservaId, #fechaPago})
class TablaReservaAbono extends Table {
  @override
  String get tableName => 'reserva_abonos';

  IntColumn get id => integer().autoIncrement()();

  /// `cascade`: un abono no existe sin su reserva.
  IntColumn get reservaId => integer()
      .references(TablaReserva, #id, onDelete: KeyAction.cascade)();

  /// En pesos enteros. **Positivo es un abono; negativo es una devolución.**
  ///
  /// La devolución aparece cuando se quita mercancía de una reserva ya abonada
  /// y el total cae por debajo de lo entregado: hay que regresarle plata al
  /// cliente, y eso se registra como un movimiento más y no editando el abono
  /// de ayer. Cero no: un movimiento de dinero que no mueve dinero no existe.
  IntColumn get monto => integer()();

  /// Uno de [MetodoPago], sin `CREDITO`: quien abona está entregando dinero.
  TextColumn get metodoPago => text()();

  /// Número de transacción, últimos dígitos de la tarjeta… lo que permita
  /// reconocer el pago en el extracto.
  TextColumn get referenciaPago => text().nullable()();

  DateTimeColumn get fechaPago => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        'CHECK (monto <> 0)',
        'CHECK (metodo_pago IN (${MetodoPago.listaSqlAbonos}))',
      ];
}
