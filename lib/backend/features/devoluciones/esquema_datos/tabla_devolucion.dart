import 'package:drift/drift.dart';

import '../../autenticacion/esquema_datos/tabla_usuario.dart';
import '../../pos/esquema_datos/tabla_ventas.dart';
import '../enum/enum_devoluciones.dart';

/// Lo que el cliente trajo de vuelta de una venta ya cobrada.
///
/// **No es lo mismo que anular.** Anular deshace la venta entera: la factura
/// queda en `ANULADA` y vuelve todo el stock. Una devolución le quita una
/// parte y la venta sigue viva, con su número y su estado. Por eso es un
/// documento aparte y no una columna en `ventas`: se pueden devolver dos
/// piezas hoy y otra la semana que viene, y cada una tiene su fecha, su
/// motivo y su autor.
///
/// La devolución **no toca `ventas.estado_pago`**. La factura de ayer decía
/// lo que se cobró ayer y sigue diciéndolo; lo devuelto se lee sumando estos
/// documentos, que es lo que hace `RepositorioDevoluciones.devueltoPorLinea`.
///
/// [total] es **caché** de `SUM(cantidad * precio_unitario)` de sus líneas.
/// Se guarda porque el historial lo muestra sin abrir el detalle, y como todo
/// caché lleva su comprobación: `RepositorioDevoluciones.descuadres()`.
@TableIndex(name: 'idx_devoluciones_venta', columns: {#ventaId})
@TableIndex(name: 'idx_devoluciones_creado', columns: {#creadoEn})
@TableIndex(name: 'idx_devoluciones_usuario', columns: {#usuarioId})
class TablaDevolucion extends Table {
  @override
  String get tableName => 'devoluciones';

  IntColumn get id => integer().autoIncrement()();

  /// Consecutivo `DEV-0001`, de la tabla `consecutivos` y dentro de la
  /// transacción que crea el documento (`REGLAS_BD.md` §7.1).
  TextColumn get numero => text().unique()();

  /// `restrict`: la venta que explica la devolución no puede desaparecer. De
  /// todos modos una factura no se borra —hay guarda—, así que esto cierra el
  /// camino por partida doble.
  IntColumn get ventaId =>
      integer().references(TablaVentas, #id, onDelete: KeyAction.restrict)();

  /// Uno de [MotivoDevolucion]. El `CHECK` sale del propio enum.
  TextColumn get motivo => text()();

  /// Si la mercancía volvió al estante o se quedó fuera del inventario.
  ///
  /// Una pieza que llegó rota no se vuelve a vender: se le reclama al
  /// proveedor. Sin esta columna, `MotivoDevolucion.defectuoso` se guardaba y
  /// no cambiaba nada —la unidad volvía a `stock_actual` y quedaba
  /// disponible—, que es el error que más caro sale de los que no dan error.
  ///
  /// **El motivo la propone, no la decide** (ver
  /// `MotivoDevolucion.reponeStockPorDefecto`): «defectuosa» es lo que dijo el
  /// cliente, y quien recibe puede ver que la pieza está bien.
  ///
  /// `DEFAULT true` porque es el caso corriente y porque las devoluciones que
  /// existían antes de esta columna sí repusieron stock: el valor por defecto
  /// tiene que decir la verdad sobre ellas.
  BoolColumn get reingresaStock =>
      boolean().withDefault(const Constant(true))();

  /// Lo que se le regresa al cliente, en pesos enteros.
  IntColumn get total => integer()();

  TextColumn get notas => text().nullable()();

  /// Quién la recibió. `restrict` y `NOT NULL` sin valor por defecto: así el
  /// `Companion.insert` exige el autor y un método nuevo que se olvide de él
  /// no compila (`REGLAS_BD.md` §7.0).
  IntColumn get usuarioId =>
      integer().references(TablaUsuario, #id, onDelete: KeyAction.restrict)();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        'CHECK (motivo IN (${MotivoDevolucion.listaSql}))',
        'CHECK (length(trim(numero)) > 0)',
        // Cero no: una devolución que no devuelve nada no existe.
        'CHECK (total > 0)',
      ];
}
