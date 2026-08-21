import 'package:drift/drift.dart';

import '../../clientes/esquema_datos/tabla_cliente.dart';
import '../../cotizaciones/esquema_datos/tabla_cotizacion.dart';
import '../../motos/esquema_datos/tabla_moto.dart';

/// Mercancía apartada para un cliente, con abonos.
///
/// `pagado_acumulado` es un **caché** de `SUM(reserva_abonos.monto)`. Se
/// guarda porque la lista lo muestra sin abrir los abonos, y solo lo escribe
/// `RepositorioReservas` dentro de la misma transacción que registra el abono.
/// `RepositorioReservas.descuadres()` comprueba que caché y suma coincidan;
/// sin esa comprobación el caché no estaría justificado.
///
/// `total_reserva` es **otro caché**: la suma de `reserva_items`. Se guarda por
/// lo mismo que el anterior —la lista lo muestra sin abrir las líneas— y lo
/// recalcula entero `RepositorioReservas` cada vez que una línea entra, cambia
/// o sale. `descuadresTotal()` es el que afirma que coincide.
@TableIndex(name: 'idx_reservas_cliente', columns: {#clienteId})
@TableIndex(name: 'idx_reservas_cotizacion', columns: {#cotizacionId})
@TableIndex(name: 'idx_reservas_estado', columns: {#estado})
@TableIndex(name: 'idx_reservas_creado', columns: {#creadoEn})
class TablaReserva extends Table {
  @override
  String get tableName => 'reservas';

  IntColumn get id => integer().autoIncrement()();

  TextColumn get numero => text().unique()();

  /// `restrict`: una reserva es un compromiso con alguien; borrar a ese
  /// alguien la dejaría sin dueño.
  IntColumn get clienteId =>
      integer().references(TablaCliente, #id, onDelete: KeyAction.restrict)();

  /// `setNull` en las dos: son referencias informativas. La reserva sigue en
  /// pie aunque se borre la moto o la cotización de la que salió.
  IntColumn get motoId => integer()
      .nullable()
      .references(TablaMoto, #id, onDelete: KeyAction.setNull)();

  /// `unique`: una cotización se reserva **una vez**. Sin esto, dos clics en
  /// «Reservar» creaban dos reservas del mismo presupuesto y descontaban el
  /// stock dos veces. En SQLite una columna `UNIQUE` admite todos los `NULL`
  /// que quiera, así que las reservas que no vienen de cotización no chocan.
  IntColumn get cotizacionId => integer()
      .nullable()
      .unique()
      .references(TablaCotizacion, #id, onDelete: KeyAction.setNull)();

  /// `ACTIVA` | `COMPLETADA` | `CANCELADA`.
  TextColumn get estado => text().withDefault(const Constant('ACTIVA'))();

  /// Los dos en pesos enteros.
  IntColumn get totalReserva => integer()();
  IntColumn get pagadoAcumulado => integer().withDefault(const Constant(0))();

  /// Hasta cuándo se guarda la mercancía. Fecha sin hora, a medianoche.
  DateTimeColumn get fechaLimite => dateTime().nullable()();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        "CHECK (estado IN ('ACTIVA', 'COMPLETADA', 'CANCELADA'))",
        'CHECK (length(trim(numero)) > 0)',
        'CHECK (total_reserva >= 0 AND pagado_acumulado >= 0)',
        // Recibir más de lo pactado es siempre un error de captura.
        'CHECK (pagado_acumulado <= total_reserva)',
      ];
}
