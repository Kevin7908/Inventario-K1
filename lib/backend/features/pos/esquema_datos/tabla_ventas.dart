import 'package:drift/drift.dart';

import '../../../share/dominio/metodo_pago.dart';
import '../../clientes/esquema_datos/tabla_cliente.dart';
import '../../autenticacion/esquema_datos/tabla_usuario.dart';
import '../../deudores/esquema_datos/tabla_deudor.dart';
import '../../ordenes/esquema_datos/tabla_ordenes_servicio.dart';
import '../../reservas/esquema_datos/tabla_reserva.dart';

/// La factura: el cierre contable de una venta.
///
/// Es un **documento**, no un registro de trabajo: una vez emitida no se
/// borra, se anula. `RepositorioVentas.anular` la deja en `ANULADA` y
/// devuelve el stock; el `DELETE` lo impide una guarda en la propia base
/// (ver `guardas_sql.dart`), porque una factura borrada rompe la
/// consecutividad del numerador y deja el inventario sin explicación.
///
/// `subtotal` y `total` son **caché** de las líneas: `subtotal` es
/// `SUM(venta_detalles.subtotal)` y `total` es `subtotal − descuento + iva`. Se
/// guardan porque la lista de facturas los muestra sin abrir el detalle, y
/// `RepositorioVentas` es el único que los recalcula.
///
/// **`iva` sí se suma al total**: el precio del catálogo es la base gravable
/// (ver `iva_app.dart`), así que `total` es `subtotal − descuento + iva`. La
/// columna guarda el impuesto liquidado con la tasa del día en que se facturó,
/// y no se recalcula si mañana cambia la tasa: subir el IVA no reescribe la
/// factura de ayer.
@TableIndex(name: 'idx_ventas_cliente', columns: {#clienteId})
// Sin índice propio para `orden_id`, `deudor_id` ni `reserva_id`: su `UNIQUE`
// ya crea uno y duplicarlo solo cuesta en cada INSERT (`REGLAS_BD.md` §4).
@TableIndex(name: 'idx_ventas_estado', columns: {#estadoPago})
@TableIndex(name: 'idx_ventas_creado', columns: {#creadoEn})
@TableIndex(name: 'idx_ventas_usuario', columns: {#usuarioId})
// Cubre el «cuánto vendió cada quien» del cierre de caja: WHERE vendedor_id = ?
@TableIndex(name: 'idx_ventas_vendedor', columns: {#vendedorId})
class TablaVentas extends Table {
  @override
  String get tableName => 'ventas';

  IntColumn get id => integer().autoIncrement()();

  /// Consecutivo del documento. `UNIQUE` en el esquema: es la referencia con
  /// la que el cliente reclama.
  TextColumn get numeroFactura => text().unique()();

  /// De dónde salió la plata: 'MOSTRADOR', 'SERVICIO', 'DEUDA' o 'RESERVA'.
  ///
  /// Las cuatro son ventas y por eso viven en la misma tabla: el historial y
  /// el cuadre del día preguntan «cuánto entró», no «por qué puerta». Lo que
  /// cambia es qué documento las originó, y eso lo dicen las tres FK de abajo.
  ///
  /// El valor por defecto es `MOSTRADOR` y **no** `SERVICIO`, que era el de
  /// antes: es el único tipo que no exige un documento detrás, así que es el
  /// único con el que un `INSERT` mínimo pasa el `CHECK`. Con `SERVICIO` de
  /// por defecto, insertar una venta sin decir el tipo fallaba pidiendo una
  /// orden que nadie tenía intención de poner.
  TextColumn get tipo => text().withDefault(const Constant('MOSTRADOR'))();

  /// El documento del que salió esta venta. **Exactamente uno**, o ninguno si
  /// es de mostrador; el `CHECK` de abajo lo impone.
  ///
  /// Son tres columnas y no una pareja polimórfica `(origen_tipo, origen_id)`
  /// porque `REGLAS_BD.md` §3.2 exige `onDelete` explícito en cada FK, y la
  /// bitácora es la única excepción del esquema. Con FK de verdad, borrar una
  /// orden facturada no puede dejar la factura sin su trabajo.
  ///
  /// Las tres son `UNIQUE`: un documento se factura **una vez**. Sin eso, dos
  /// clics en «Entregar» cobrarían dos veces el mismo trabajo, y el `UNIQUE`
  /// es la única garantía real —entre la comprobación y el `INSERT` cabe otra
  /// escritura (§3.1)—. En SQLite una columna `UNIQUE` admite todos los `NULL`
  /// que quiera, así que las ventas de mostrador no chocan entre sí.
  ///
  /// `restrict` en las tres, por lo mismo: son históricos.
  IntColumn get ordenId => integer()
      .nullable()
      .unique()
      .references(TablaOrdenesServicio, #id, onDelete: KeyAction.restrict)();

  IntColumn get deudorId => integer()
      .nullable()
      .unique()
      .references(TablaDeudor, #id, onDelete: KeyAction.restrict)();

  IntColumn get reservaId => integer()
      .nullable()
      .unique()
      .references(TablaReserva, #id, onDelete: KeyAction.restrict)();

  /// NULL para ventas de mostrador sin cliente identificado. `restrict`: no se
  /// borra a quien tiene facturas.
  IntColumn get clienteId => integer()
      .nullable()
      .references(TablaCliente, #id, onDelete: KeyAction.restrict)();

  /// Los cinco importes en **pesos enteros**, como el resto del sistema.
  IntColumn get subtotal => integer().withDefault(const Constant(0))();
  IntColumn get iva => integer().withDefault(const Constant(0))();
  IntColumn get descuento => integer().withDefault(const Constant(0))();
  IntColumn get total => integer().withDefault(const Constant(0))();
  IntColumn get totalPagado => integer().withDefault(const Constant(0))();

  /// Uno de [MetodoPago]. El `CHECK` sale del propio enum: agregar un método
  /// no obliga a acordarse de esta tabla.
  TextColumn get metodoPago =>
      text().withDefault(const Constant('EFECTIVO'))();

  /// 'PAGADO' | 'PENDIENTE' | 'ANULADA'.
  TextColumn get estadoPago =>
      text().withDefault(const Constant('PENDIENTE'))();

  /// Quién lo registró. `restrict`: borrar la cuenta destruiría la atribución
  /// de lo que esa persona hizo, que es justo lo que esta columna existe para
  /// conservar.
  ///
  /// `NOT NULL` **y sin valor por defecto**, a propósito: así el
  /// `Companion.insert` que genera Drift lo exige como parámetro obligatorio y
  /// un método de escritura nuevo que se olvide del autor no compila.
  IntColumn get usuarioId => integer()
      .references(TablaUsuario, #id, onDelete: KeyAction.restrict)();

  /// Quién **vendió**, si no es el mismo que la registró.
  ///
  /// Es otra pregunta que [usuarioId] y por eso es otra columna: uno responde
  /// quién tecleó la factura —el de la caja— y este, a quién reclamarle por el
  /// trato. En un mostrador con un solo cajero y tres vendedores son personas
  /// distintas todos los días.
  ///
  /// `NULL` significa «el mismo que la registró», no «no se sabe»: así el caso
  /// normal no obliga a elegir nada al cobrar. `restrict` como el otro: borrar
  /// la cuenta destruiría la atribución que esta columna existe para conservar.
  IntColumn get vendedorId => integer()
      .nullable()
      .references(TablaUsuario, #id, onDelete: KeyAction.restrict)();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        "CHECK (tipo IN ('SERVICIO', 'MOSTRADOR', 'DEUDA', 'RESERVA'))",
        "CHECK (metodo_pago IN (${MetodoPago.listaSql}))",
        "CHECK (estado_pago IN ('PAGADO', 'PENDIENTE', 'ANULADA'))",
        'CHECK (length(trim(numero_factura)) > 0)',
        'CHECK (subtotal >= 0 AND iva >= 0 AND descuento >= 0)',
        'CHECK (total >= 0 AND total_pagado >= 0)',
        // Cobrar más de lo facturado es siempre un error de captura.
        'CHECK (total_pagado <= total)',
        // Cada tipo trae su documento, y solo el suyo. Sin esto, una venta
        // podría decir que es de una reserva y apuntar a una orden, y el
        // historial mostraría el número equivocado sin que nada fallara.
        '''CHECK (
             (tipo = 'MOSTRADOR'
                AND orden_id IS NULL AND deudor_id IS NULL AND reserva_id IS NULL)
          OR (tipo = 'SERVICIO'
                AND orden_id IS NOT NULL AND deudor_id IS NULL AND reserva_id IS NULL)
          OR (tipo = 'DEUDA'
                AND deudor_id IS NOT NULL AND orden_id IS NULL AND reserva_id IS NULL)
          OR (tipo = 'RESERVA'
                AND reserva_id IS NOT NULL AND orden_id IS NULL AND deudor_id IS NULL)
        )''',
      ];
}
