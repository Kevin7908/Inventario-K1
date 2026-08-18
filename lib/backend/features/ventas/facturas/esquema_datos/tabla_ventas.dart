import 'package:drift/drift.dart';

import '../../../../share/dominio/metodo_pago.dart';
import '../../../clientes/esquema_datos/tabla_cliente.dart';
import '../../ordenes/esquema_datos/tabla_ordenes_servicio.dart';

/// La factura: el cierre contable de una venta.
///
/// Es un **documento**, no un registro de trabajo: una vez emitida no se
/// borra, se anula. `RepositorioFacturas.anular` la deja en `ANULADA` y
/// devuelve el stock; el `DELETE` lo impide una guarda en la propia base
/// (ver `guardas_sql.dart`), porque una factura borrada rompe la
/// consecutividad del numerador y deja el inventario sin explicación.
///
/// `subtotal` y `total` son **caché** de las líneas: `subtotal` es
/// `SUM(venta_detalles.subtotal)` y `total` es `subtotal − descuento + iva`.
/// Se guardan porque la lista de facturas los muestra sin abrir el detalle, y
/// `RepositorioFacturas` es el único que los recalcula.
@TableIndex(name: 'idx_ventas_cliente', columns: {#clienteId})
@TableIndex(name: 'idx_ventas_orden', columns: {#ordenId})
@TableIndex(name: 'idx_ventas_estado', columns: {#estadoPago})
@TableIndex(name: 'idx_ventas_creado', columns: {#creadoEn})
class TablaVentas extends Table {
  @override
  String get tableName => 'ventas';

  IntColumn get id => integer().autoIncrement()();

  /// Consecutivo del documento. `UNIQUE` en el esquema: es la referencia con
  /// la que el cliente reclama.
  TextColumn get numeroFactura => text().unique()();

  /// 'SERVICIO' | 'MOSTRADOR'.
  TextColumn get tipo => text().withDefault(const Constant('SERVICIO'))();

  /// NULL para ventas de mostrador. `restrict`: una orden ya facturada no
  /// puede desaparecer y dejar la factura sin su trabajo.
  IntColumn get ordenId => integer()
      .nullable()
      .references(TablaOrdenesServicio, #id, onDelete: KeyAction.restrict)();

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

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        "CHECK (tipo IN ('SERVICIO', 'MOSTRADOR'))",
        "CHECK (metodo_pago IN (${MetodoPago.listaSql}))",
        "CHECK (estado_pago IN ('PAGADO', 'PENDIENTE', 'ANULADA'))",
        'CHECK (length(trim(numero_factura)) > 0)',
        'CHECK (subtotal >= 0 AND iva >= 0 AND descuento >= 0)',
        'CHECK (total >= 0 AND total_pagado >= 0)',
        // Cobrar más de lo facturado es siempre un error de captura.
        'CHECK (total_pagado <= total)',
        // Una venta de mostrador no tiene orden; una de servicio, sí.
        "CHECK ((tipo = 'MOSTRADOR' AND orden_id IS NULL) OR tipo = 'SERVICIO')",
      ];
}
