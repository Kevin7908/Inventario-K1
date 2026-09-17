import 'package:drift/drift.dart';

import '../../productos/esquema_datos/tabla_producto.dart';
import '../../tecnicos/esquema_datos/tabla_tecnico.dart';
import '../../servicios/esquema_datos/tabla_servicio.dart';
import 'tabla_ventas.dart';

/// Una línea de la factura, congelada.
///
/// `descripcion`, `precio_unitario` y `costo_unitario` **duplican** a
/// propósito lo que en su momento decía el catálogo: es el caso legítimo del
/// que habla §1.2 de las reglas. Si mañana sube el precio de una pastilla, la
/// factura de ayer no puede cambiar, y la ganancia de ayer se calcula con el
/// costo de ayer.
///
/// Las FK a producto, servicio y técnico se conservan **además** del texto,
/// para poder cruzar el histórico con el catálogo; no lo sustituyen.
///
/// **No lleva `usuario_id`, y es una decisión.** Una venta se escribe entera
/// en una transacción, así que el autor de cada línea es siempre el de
/// `ventas.usuario_id`: repetirlo aquí sería el dato duplicado que prohíbe
/// `REGLAS_BD.md` §1.1, y no cumple las tres condiciones del snapshot de §1.2.
/// Las tablas de líneas que **sí** lo llevan son las que se agregan de a una
/// desde un editor que autoguarda, donde cada renglón lo puede poner una
/// persona distinta.
@TableIndex(name: 'idx_venta_detalles_venta', columns: {#ventaId})
@TableIndex(name: 'idx_venta_detalles_producto', columns: {#productoId})
class TablaVentaDetalles extends Table {
  @override
  String get tableName => 'venta_detalles';

  IntColumn get id => integer().autoIncrement()();

  /// `cascade`: una línea no existe sin su factura.
  IntColumn get ventaId => integer()
      .references(TablaVentas, #id, onDelete: KeyAction.cascade)();

  /// 'PRODUCTO' | 'SERVICIO'.
  TextColumn get tipoItem => text()();

  /// `restrict` en las tres: lo que aparece en una factura emitida no se borra
  /// del catálogo.
  IntColumn get productoId => integer()
      .nullable()
      .references(TablaProducto, #id, onDelete: KeyAction.restrict)();

  IntColumn get servicioId => integer()
      .nullable()
      .references(TablaServicio, #id, onDelete: KeyAction.restrict)();

  IntColumn get tecnicoId => integer()
      .nullable()
      .references(TablaTecnico, #id, onDelete: KeyAction.restrict)();

  /// Nombre congelado en el momento de la venta.
  TextColumn get descripcion => text()();

  /// `REAL` porque hay repuestos por litro y por metro.
  RealColumn get cantidad => real().withDefault(const Constant(1.0))();

  /// Importes en pesos enteros.
  IntColumn get precioUnitario => integer()();
  IntColumn get costoUnitario => integer().withDefault(const Constant(0))();
  IntColumn get subtotal => integer()();

  @override
  List<String> get customConstraints => [
        "CHECK (tipo_item IN ('PRODUCTO', 'SERVICIO'))",
        'CHECK (cantidad > 0)',
        'CHECK (precio_unitario >= 0 AND costo_unitario >= 0)',
        'CHECK (subtotal >= 0)',
        'CHECK (length(trim(descripcion)) > 0)',
        // Coherencia del tipo con la referencia: una línea de producto sin
        // `producto_id` no se puede cruzar con el inventario.
        "CHECK ((tipo_item = 'PRODUCTO' AND producto_id IS NOT NULL AND "
            "servicio_id IS NULL) OR (tipo_item = 'SERVICIO' AND "
            "producto_id IS NULL))",
      ];
}
