import 'package:drift/drift.dart';

import '../../clientes/esquema_datos/tabla_cliente.dart';
import '../../motos/esquema_datos/tabla_moto.dart';

/// La moto mientras está en el taller.
///
/// Los importes no se guardan: el total es la suma de sus tareas, repuestos y
/// cargos, y lo resuelve SQLite con subconsultas correlacionadas. Guardarlo
/// sería un caché más que mantener y cuadrar (§7), y aquí no hace falta.
///
/// A diferencia de la factura, la orden es un registro de trabajo: se puede
/// editar mientras está `ABIERTA`. Una vez `ENTREGADA` o `ANULADA` queda
/// cerrada, y una guarda de la base impide seguir agregándole tareas o
/// repuestos (ver `guardas_sql.dart`).
///
/// **Los repuestos descuentan stock al anotarlos**, igual que en `reservas`:
/// apartar una pieza para una moto la saca del inventario disponible aunque
/// siga en la bodega. No hay columna que diga si el inventario ya salió,
/// porque no hace falta: salió siempre, salvo que la orden esté `ANULADA`,
/// que es lo único que lo devuelve.
@TableIndex(name: 'idx_ordenes_moto', columns: {#motoId})
@TableIndex(name: 'idx_ordenes_cliente', columns: {#clienteId})
@TableIndex(name: 'idx_ordenes_estado', columns: {#estado})
@TableIndex(name: 'idx_ordenes_ingreso', columns: {#fechaIngreso})
class TablaOrdenesServicio extends Table {
  @override
  String get tableName => 'ordenes_servicio';

  IntColumn get id => integer().autoIncrement()();

  /// Consecutivo visible, `ORD-0041`. Sale de la tabla `consecutivos` dentro
  /// de la transacción que crea la orden (§7.1 de las reglas de base de
  /// datos).
  ///
  /// Antes se armaba en el mapper con `'#ORD-' + id`. Eso deja huecos —un
  /// `INSERT` fallido se salta un número para siempre— y ata el número visible
  /// a un detalle de implementación de SQLite: al primer `VACUUM` o a la
  /// primera restauración parcial, las órdenes cambian de nombre.
  TextColumn get numero => text().unique()();

  /// `restrict` en las dos: una moto o un cliente con historial de taller no
  /// se borran.
  IntColumn get motoId =>
      integer().references(TablaMoto, #id, onDelete: KeyAction.restrict)();

  IntColumn get clienteId =>
      integer().references(TablaCliente, #id, onDelete: KeyAction.restrict)();

  IntColumn get kilometrajeEntrada => integer()();

  /// Rebaja sobre el total de la orden, en pesos. Como los precios ya traen el
  /// IVA dentro (`iva_app.dart`), rebajar aquí rebaja exactamente eso de lo
  /// que paga el cliente.
  ///
  /// **No hay `CHECK (descuento <= subtotal)`**, a diferencia de
  /// `cotizaciones`: el subtotal de una orden no es una columna sino la suma
  /// de otras tres tablas, y un `CHECK` no puede consultarlas. Lo recorta
  /// `RepositorioOrdenes`, y hay un test que lo verifica.
  IntColumn get descuento => integer().withDefault(const Constant(0))();

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
        'CHECK (descuento >= 0)',
        'CHECK (length(trim(numero)) > 0)',
        'CHECK (fecha_salida IS NULL OR fecha_salida >= fecha_ingreso)',
      ];
}
