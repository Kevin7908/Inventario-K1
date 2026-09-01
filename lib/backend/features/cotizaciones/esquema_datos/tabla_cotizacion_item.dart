import 'package:drift/drift.dart';

import '../../autenticacion/esquema_datos/tabla_usuario.dart';
import '../../productos/esquema_datos/tabla_producto.dart';
import '../../servicios/esquema_datos/tabla_servicio.dart';
import 'tabla_cotizacion.dart';

/// Una línea de la cotización.
///
/// La referencia al catálogo son **dos columnas nulables** y no el par
/// `referencia_id` + `tipo_item` que había antes: una FK polimórfica no la
/// puede verificar la base, así que nada impedía que una línea de producto
/// apuntara a un id de servicio. Es la misma solución que en
/// `movimientos_inventario`, y el `CHECK` de abajo la cierra:
///
/// - `PRODUCTO` → `producto_id` puesto, `servicio_id` en NULL;
/// - `SERVICIO` → `servicio_id` puesto, `producto_id` en NULL;
/// - `LIBRE` → las dos en NULL: descripción y precio escritos a mano.
///
/// El modelo `CotizacionItem` sigue exponiendo un solo `referenciaId`, que es
/// como se lee bien desde la vista; el mapper elige la columna según el tipo.
@TableIndex(name: 'idx_cotizacion_items_cotizacion', columns: {#cotizacionId})
// Cubre el WHERE usuarioId = ? de «qué anotó esta cuenta».
@TableIndex(name: 'idx_cotizacion_items_usuario', columns: {#usuarioId})
class TablaCotizacionItem extends Table {
  @override
  String get tableName => 'cotizacion_items';

  IntColumn get id => integer().autoIncrement()();

  /// `cascade`: una línea no existe sin su cotización.
  IntColumn get cotizacionId => integer()
      .references(TablaCotizacion, #id, onDelete: KeyAction.cascade)();

  /// `PRODUCTO` | `SERVICIO` | `LIBRE`.
  TextColumn get tipoItem => text()();

  /// `restrict` en las dos: lo que aparece en una cotización emitida no se
  /// borra del catálogo mientras ella exista.
  IntColumn get productoId => integer()
      .nullable()
      .references(TablaProducto, #id, onDelete: KeyAction.restrict)();

  IntColumn get servicioId => integer()
      .nullable()
      .references(TablaServicio, #id, onDelete: KeyAction.restrict)();

  /// Quién anotó **esta línea**, que no siempre es quien abrió el documento:
  /// el editor guarda solo y el documento puede pasar de un turno a otro
  /// (`REGLAS_BD.md` §7.0).
  ///
  /// `NOT NULL` y sin valor por defecto **a propósito**: así el
  /// `Companion.insert` que genera Drift lo exige como parámetro, y un método
  /// de escritura nuevo que se olvide del autor no compila. La garantía la da
  /// el compilador, no la disciplina.
  ///
  /// `restrict`: la cuenta que anotó algo no se borra mientras eso exista.
  IntColumn get usuarioId => integer()
      .references(TablaUsuario, #id, onDelete: KeyAction.restrict)();

  /// Nombre congelado: si mañana renombran el repuesto, la cotización impresa
  /// sigue diciendo lo que decía.
  TextColumn get descripcion => text()();

  /// `REAL` porque hay repuestos por litro y por metro.
  RealColumn get cantidad => real()();

  IntColumn get precioUnitario => integer()();

  /// `cantidad × precio_unitario` **redondeado al peso**. Se guarda —y no se
  /// deduce— porque el redondeo es información: es la cifra que salió impresa
  /// en la cotización que el cliente tiene en la mano.
  IntColumn get subtotal => integer()();

  @override
  List<String> get customConstraints => [
        "CHECK (tipo_item IN ('PRODUCTO', 'SERVICIO', 'LIBRE'))",
        'CHECK (cantidad > 0)',
        'CHECK (precio_unitario >= 0 AND subtotal >= 0)',
        'CHECK (length(trim(descripcion)) > 0)',
        "CHECK ("
            "(tipo_item = 'PRODUCTO' AND producto_id IS NOT NULL "
            "AND servicio_id IS NULL) OR "
            "(tipo_item = 'SERVICIO' AND servicio_id IS NOT NULL "
            "AND producto_id IS NULL) OR "
            "(tipo_item = 'LIBRE' AND producto_id IS NULL "
            "AND servicio_id IS NULL))",
      ];
}
