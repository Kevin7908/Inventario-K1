import 'package:drift/drift.dart';

import '../../autenticacion/esquema_datos/tabla_usuario.dart';
import '../../proveedores/esquema_datos/tabla_proveedor.dart';
import '../enum/enum_compras.dart';

/// La remisión del proveedor: qué llegó al taller, de quién y a cuánto.
///
/// Es **el POS al revés**. La factura dice qué salió y a qué precio se vendió;
/// esta dice qué entró y qué se pagó por ello, y por eso se escribe igual: la
/// cabecera, sus líneas y las entradas de inventario, todo en una transacción.
///
/// **Por qué existe la tabla y no bastaban dos columnas en
/// `movimientos_inventario`.** El movimiento responde «¿cuántas pastillas
/// entraron el martes?»; la remisión responde «¿cuánto costó el pedido
/// completo que llegó el martes?», que es la pregunta con la que el taller
/// discute con el proveedor. Sin cabecera no hay documento que abrir, ni
/// número que citar, ni forma de saber que catorce entradas sueltas eran un
/// solo pedido.
///
/// `total` es un **caché** de `SUM(compra_detalles.cantidad * costo_unitario)`,
/// como `ventas.subtotal`: se guarda porque el listado lo muestra sin abrir el
/// detalle, y `RepositorioCompras.descuadres()` es la consulta que afirma que
/// coincide (§7).
///
/// Una compra registrada **no se borra: se anula**, igual que una factura.
/// Borrarla dejaría entradas de inventario sin documento que las explique. Lo
/// impide una guarda de `guardas_sql.dart`, que deja pasar un solo caso: el
/// borrador **sin una sola línea**, que es el que se abre por error y no llegó
/// a ser nada.
@TableIndex(name: 'idx_compras_proveedor', columns: {#proveedorId})
@TableIndex(name: 'idx_compras_fecha', columns: {#fecha})
@TableIndex(name: 'idx_compras_estado', columns: {#estado})
@TableIndex(name: 'idx_compras_usuario', columns: {#usuarioId})
class TablaCompra extends Table {
  @override
  String get tableName => 'compras';

  IntColumn get id => integer().autoIncrement()();

  /// Consecutivo del taller, `COM-2026-0007`. Sale de la tabla `consecutivos`
  /// dentro de la transacción que crea la compra (§7.1): ni del `id` ni de un
  /// `MAX + 1`.
  ///
  /// Es **el número del taller**, no el del proveedor: ese es
  /// [numeroFactura], y los dos hacen falta —el primero para archivar, el
  /// segundo para reclamar—.
  TextColumn get numero => text().unique()();

  /// `restrict`: un proveedor con historial de compras no se borra. Es la
  /// misma política que `venta_detalles → productos`, y por lo mismo: sin él,
  /// el histórico de costos deja de tener a quién atribuirle nada.
  IntColumn get proveedorId => integer()
      .references(TablaProveedor, #id, onDelete: KeyAction.restrict)();

  /// El número de la factura o remisión **del proveedor**, tal como viene
  /// impreso. Opcional: hay mercancía que llega con un papel escrito a mano.
  TextColumn get numeroFactura => text().nullable()();

  /// Cuándo llegó la mercancía, que no siempre es cuándo se teclea: una
  /// remisión del sábado se registra el lunes. Por eso es una columna y no
  /// [creadoEn].
  DateTimeColumn get fecha => dateTime().withDefault(currentDateAndTime)();

  /// Caché de la suma de las líneas, en pesos enteros.
  IntColumn get total => integer().withDefault(const Constant(0))();

  /// Uno de [EstadoCompra]. El `CHECK` sale del propio enum; el valor por
  /// defecto va literal porque el código que genera Drift no importa el enum
  /// —una constante suya ahí no compila—.
  ///
  /// **Nace como borrador**: la remisión se abre y se va tecleando, y solo
  /// cuando quien recibe dice «ya está todo» pasa a `REGISTRADA`. Mientras
  /// tanto no cuenta como gasto del mes ni como última compra del producto,
  /// aunque su mercancía sí esté ya en el inventario.
  TextColumn get estado => text().withDefault(const Constant('BORRADOR'))();

  TextColumn get notas => text().nullable()();

  /// Quién la registró. `restrict`: borrar la cuenta destruiría la atribución
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
        'CHECK (estado IN (${EstadoCompra.listaSql}))',
        'CHECK (length(trim(numero)) > 0)',
        // Vacío es un NULL mal escrito, igual que en el código de barras.
        'CHECK (numero_factura IS NULL OR length(trim(numero_factura)) > 0)',
        'CHECK (notas IS NULL OR length(trim(notas)) > 0)',
        'CHECK (total >= 0)',
      ];

  /// La misma remisión no se teclea dos veces al mismo proveedor.
  ///
  /// Es el error de captura más caro del módulo: registrar dos veces la
  /// factura FV-2291 mete el doble de mercancía al inventario y duplica lo
  /// que figura pagado. Con `numero_factura` en NULL no estorba —SQLite admite
  /// tantos NULL como haga falta—, que es el caso de lo que llega sin papel.
  @override
  List<Set<Column>> get uniqueKeys => [
        {proveedorId, numeroFactura},
      ];
}
