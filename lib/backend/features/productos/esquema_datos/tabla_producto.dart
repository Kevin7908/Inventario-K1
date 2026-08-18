import 'package:drift/drift.dart';

import '../../categorias/esquema_datos/tabla_categoria.dart';
import '../../proveedores/esquema_datos/tabla_proveedor.dart';
import '../../unidades_medida/esquema_datos/tabla_unidades_medida.dart';

/// El catálogo de repuestos del taller.
///
/// `stock_actual` es un **caché**: la verdad es la suma de
/// `movimientos_inventario.cantidad` de ese producto. Se guarda aquí porque la
/// app lo consulta cien veces por pantalla y reconstruirlo cada vez sería
/// absurdo, pero nadie lo escribe a mano —solo `RepositorioInventario`, que
/// mueve las dos tablas en la misma transacción.
@TableIndex(name: 'idx_productos_categoria', columns: {#categoriaId})
@TableIndex(name: 'idx_productos_proveedor', columns: {#proveedorId})
@TableIndex(name: 'idx_productos_activo', columns: {#activo})
class TablaProducto extends Table {
  @override
  String get tableName => 'productos';

  IntColumn get id => integer().autoIncrement()();

  /// Código interno del repuesto. `UNIQUE` en el esquema y no solo en Dart:
  /// entre el `existeSku()` de validación y el `INSERT` cabe otra escritura.
  TextColumn get sku => text().unique()();

  TextColumn get nombre => text()();

  TextColumn get descripcion => text().nullable()();

  /// `setNull` en los tres: borrar una categoría, un proveedor o una unidad no
  /// puede llevarse el producto por delante; solo lo deja sin clasificar.
  IntColumn get categoriaId => integer()
      .nullable()
      .references(TablaCategoria, #id, onDelete: KeyAction.setNull)();

  IntColumn get unidadMedidaId => integer()
      .nullable()
      .references(TablaUnidadesMedida, #id, onDelete: KeyAction.setNull)();

  IntColumn get proveedorId => integer()
      .nullable()
      .references(TablaProveedor, #id, onDelete: KeyAction.setNull)();

  /// Los tres precios en **pesos enteros**. El peso colombiano no tiene
  /// decimales y `REAL` arrastraba error de coma flotante: mil líneas de
  /// `19.999` no daban lo que el usuario esperaba, y el mismo producto salía
  /// con un centavo de diferencia según se cobrara por el POS (`REAL`) o por
  /// una cotización (`INTEGER`).
  IntColumn get precioCompra => integer().withDefault(const Constant(0))();

  IntColumn get precioVenta => integer().withDefault(const Constant(0))();

  /// Precio especial para servicios internos del taller. `null` = se cobra
  /// [precioVenta].
  IntColumn get precioVentaTaller => integer().nullable()();

  /// Caché de `SUM(movimientos_inventario.cantidad)`. Ver el docstring de la
  /// clase. `REAL` sí corresponde: hay productos por litro y por metro.
  RealColumn get stockActual => real().withDefault(const Constant(0))();

  RealColumn get stockMinimo => real().withDefault(const Constant(0))();

  TextColumn get ubicacionBodega => text().nullable()();

  TextColumn get imagenUrl => text().nullable()();

  BoolColumn get aplicaIva => boolean().withDefault(const Constant(true))();

  BoolColumn get activo => boolean().withDefault(const Constant(true))();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get actualizadoEn =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        'CHECK (length(trim(sku)) > 0)',
        'CHECK (length(trim(nombre)) > 0)',
        'CHECK (precio_compra >= 0)',
        'CHECK (precio_venta >= 0)',
        'CHECK (precio_venta_taller IS NULL OR precio_venta_taller >= 0)',
        'CHECK (stock_minimo >= 0)',
      ];
}
