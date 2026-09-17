import 'package:drift/drift.dart';

import '../../autenticacion/esquema_datos/tabla_usuario.dart';
import '../../clientes/esquema_datos/tabla_cliente.dart';
import '../../motos/esquema_datos/tabla_moto.dart';
import '../../ordenes/esquema_datos/tabla_ordenes_servicio.dart';

/// Lo que un cliente quedó debiendo por mercancía que **ya se llevó**, con sus
/// líneas y sus abonos.
///
/// Es la contraparte de una reserva y conviene leerlas juntas, porque se
/// parecen en todo menos en lo que importa: apartar deja el repuesto en la
/// bodega y fiar lo saca del taller montado en una moto. Por eso una reserva
/// cancelada devuelve su mercancía al inventario y una deuda **nunca**: si el
/// cliente no paga, el taller pierde la plata, no recupera la pieza.
///
/// `monto_total` es un **caché** de `SUM(deudor_items.cantidad *
/// precio_unitario)` y `monto_pagado` lo es de `SUM(deudor_pagos.monto)`. Los
/// dos los recalcula enteros `RepositorioDeudores`, y `descuadresTotal()` y
/// `descuadres()` son las consultas que afirman que coinciden —que es lo único
/// que justifica tenerlos (§7 de `REGLAS_BD.md`)—.
///
/// **La deuda nace en Cuentas por cobrar o al cerrar una orden a crédito.**
/// Hubo una columna `venta_id` que apuntaba a la venta que la originó; se
/// quitó cuando el mostrador dejó de fiar —toda venta se cobra completa— y
/// nadie volvió a escribirla. [ordenId] sí se escribe, y es lo que impide el
/// descuento doble: fiar lo que ya salió por una orden era anotar el mismo
/// repuesto en dos sitios y descontarlo dos veces del inventario.
///
/// `VENCIDA` es un estado guardado y a la vez calculable desde
/// `fecha_vencimiento`. Se guarda porque el usuario puede marcar una deuda
/// como vencida antes de tiempo —o dejarla activa después—, así que no es una
/// función de la fecha: es una decisión. `DeudorResumen.estaVencida` responde
/// la pregunta completa, la del calendario **y** la de la marca.
@TableIndex(name: 'idx_deudores_estado', columns: {#estado})
@TableIndex(name: 'idx_deudores_cliente', columns: {#clienteId})
@TableIndex(name: 'idx_deudores_moto', columns: {#motoId})
@TableIndex(name: 'idx_deudores_creado', columns: {#creadoEn})
@TableIndex(name: 'idx_deudores_vencimiento', columns: {#fechaVencimiento})
@TableIndex(name: 'idx_deudores_usuario', columns: {#usuarioId})
class TablaDeudor extends Table {
  @override
  String get tableName => 'deudores';

  IntColumn get id => integer().autoIncrement()();

  TextColumn get numero => text().unique()();

  /// `restrict`: no se borra a quien debe.
  IntColumn get clienteId =>
      integer().references(TablaCliente, #id, onDelete: KeyAction.restrict)();

  /// La orden de servicio que se cerró a crédito, cuando la deuda nació así.
  ///
  /// **`UNIQUE`**: una orden se fía una sola vez. Sin eso, cerrar dos veces la
  /// misma orden abriría dos deudas por el mismo trabajo, y el `UNIQUE` de
  /// una columna nulable no estorba a las deudas de mostrador —SQLite admite
  /// tantos NULL como haga falta—.
  ///
  /// **`restrict`**: la orden que explica la deuda no se borra. Es lo mismo
  /// que hace `ventas.orden_id`, y por lo mismo: sin ella, las líneas de la
  /// deuda dejan de tener de dónde salieron.
  ///
  /// Las líneas de una deuda con orden **no mueven inventario**: el repuesto
  /// salió del estante al anotarlo en la orden. Que no se pueda anotar dos
  /// veces no lo garantiza esta columna sola, sino la guarda de
  /// `guardas_sql.dart` que cierra sus líneas a la edición a mano.
  IntColumn get ordenId => integer()
      .nullable()
      .unique()
      .references(TablaOrdenesServicio, #id, onDelete: KeyAction.restrict)();

  /// En qué moto se montó lo fiado. `setNull`: es informativa —hay fiados de
  /// mostrador que no van a ninguna moto— y la deuda sigue en pie aunque la
  /// moto se borre.
  IntColumn get motoId => integer()
      .nullable()
      .references(TablaMoto, #id, onDelete: KeyAction.setNull)();

  /// Por qué se debe, en una línea. **Opcional**: las líneas ya dicen qué se
  /// llevó, y esto es para el caso en que haga falta nombrarlo («Reparación
  /// del motor», «Fiado de mostrador»).
  TextColumn get concepto => text().nullable()();

  /// Caché de la suma de las líneas. Nace en cero: la deuda se abre vacía y se
  /// le van anotando los repuestos, como una reserva.
  IntColumn get montoTotal => integer().withDefault(const Constant(0))();

  /// Caché de la suma de los abonos.
  IntColumn get montoPagado => integer().withDefault(const Constant(0))();

  /// Rebaja sobre la suma de las líneas, en pesos. `monto_total` es
  /// `SUM(líneas) − descuento`, y por eso [montoTotal] sigue siendo lo que el
  /// cliente debe de verdad.
  ///
  /// Existe porque una orden puede llevar rebaja: sin esta columna, cerrar a
  /// crédito una orden con descuento abriría una deuda por más de lo que el
  /// documento dice. **No hay `CHECK (descuento <= …)`**, por lo mismo que en
  /// `ordenes_servicio`: la suma de las líneas no es una columna y un `CHECK`
  /// no puede consultarla. Lo recorta `RepositorioDeudores`.
  IntColumn get descuento => integer().withDefault(const Constant(0))();

  /// `ACTIVA` | `VENCIDA` | `PAGADA` | `INCOBRABLE`.
  TextColumn get estado => text().withDefault(const Constant('ACTIVA'))();

  /// Fecha sin hora, a medianoche. `null` = sin plazo pactado.
  DateTimeColumn get fechaVencimiento => dateTime().nullable()();

  TextColumn get notas => text().nullable()();

  /// Quién lo registró. `restrict`: borrar la cuenta destruiría la atribución
  /// de lo que esa persona hizo, que es justo lo que esta columna existe para
  /// conservar.
  ///
  /// `NOT NULL` **y sin valor por defecto**, a propósito: así el
  /// `Companion.insert` que genera Drift lo exige como parámetro obligatorio y
  /// un método de escritura nuevo que se olvide del autor no compila.
  IntColumn get usuarioId => integer()
      .references(TablaUsuario, #id, onDelete: KeyAction.restrict)();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        "CHECK (estado IN ('ACTIVA', 'VENCIDA', 'PAGADA', 'INCOBRABLE'))",
        'CHECK (length(trim(numero)) > 0)',
        'CHECK (concepto IS NULL OR length(trim(concepto)) > 0)',
        'CHECK (monto_total >= 0 AND monto_pagado >= 0)',
        'CHECK (descuento >= 0)',
        // Recibir más de lo debido es siempre un error de captura.
        'CHECK (monto_pagado <= monto_total)',
      ];
}
