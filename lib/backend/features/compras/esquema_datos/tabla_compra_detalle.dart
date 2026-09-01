import 'package:drift/drift.dart';

import '../../productos/esquema_datos/tabla_producto.dart';
import 'tabla_compra.dart';

/// Una línea de la remisión: qué producto llegó, cuánto y a qué costo.
///
/// `descripcion` y `costo_unitario` **duplican** a propósito lo que en su
/// momento decía el catálogo (§1.2): es lo que permite responder «¿a cómo
/// compramos esta pastilla la última vez? ¿nos subieron el precio?». Si el
/// costo viviera solo en `productos.precio_compra`, cada compra nueva borraría
/// la anterior y no habría con qué comparar.
///
/// **Sin `usuario_id`**, y es la misma decisión que en `venta_detalles`: la
/// compra se escribe entera en una transacción, así que el autor de cada línea
/// es siempre el de `compras.usuario_id`. Repetirlo sería el dato duplicado
/// que prohíbe §1.1. Las líneas que **sí** llevan autor propio son las de los
/// editores que autoguardan, donde el documento pasa de un turno a otro.
@TableIndex(name: 'idx_compra_detalles_compra', columns: {#compraId})
@TableIndex(name: 'idx_compra_detalles_producto', columns: {#productoId})
class TablaCompraDetalle extends Table {
  @override
  String get tableName => 'compra_detalles';

  IntColumn get id => integer().autoIncrement()();

  /// `cascade`: una línea no existe sin su remisión.
  IntColumn get compraId =>
      integer().references(TablaCompra, #id, onDelete: KeyAction.cascade)();

  /// `restrict`: un producto que aparece en una compra registrada no se borra
  /// del catálogo; se llevaría su historial de costos.
  IntColumn get productoId => integer()
      .references(TablaProducto, #id, onDelete: KeyAction.restrict)();

  /// Nombre congelado el día que llegó la mercancía.
  TextColumn get descripcion => text()();

  /// `REAL` porque hay mercancía por litro y por metro.
  RealColumn get cantidad => real()();

  /// Lo que de verdad se pagó por unidad, en pesos enteros. Puede ser cero:
  /// hay proveedores que mandan muestras.
  IntColumn get costoUnitario => integer()();

  @override
  List<String> get customConstraints => [
        'CHECK (cantidad > 0)',
        'CHECK (costo_unitario >= 0)',
        'CHECK (length(trim(descripcion)) > 0)',
      ];

  /// El mismo producto no abre dos líneas en la misma remisión: se le suma
  /// cantidad a la que ya está, como en el carrito. Aquí sí cabe la
  /// restricción —a diferencia de `deudor_items`— porque la compra se teclea
  /// de una vez y no copia ningún documento anterior.
  @override
  List<Set<Column>> get uniqueKeys => [
        {compraId, productoId},
      ];
}
