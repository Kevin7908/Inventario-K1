import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/features/reservas/esquema_datos/tabla_reserva.dart';

class TablaReservaAbono extends Table {
  @override
  String get tableName => 'reserva_abonos';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get reservaId =>
      integer().references(TablaReserva, #id, onDelete: KeyAction.cascade)();
  IntColumn get monto => integer()();
  TextColumn get metodoPago => text()();
  TextColumn get referenciaPago => text().nullable()();
  DateTimeColumn get fechaPago =>
      dateTime().withDefault(currentDateAndTime)();
}
