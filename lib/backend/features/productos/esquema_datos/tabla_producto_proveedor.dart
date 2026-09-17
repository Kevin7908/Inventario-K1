import 'package:drift/drift.dart';

import '../../proveedores/esquema_datos/tabla_proveedor.dart';
import 'tabla_producto.dart';

/// Quién le vende cada repuesto al taller.
///
/// Sustituye a `productos.proveedor_id`, que solo admitía uno. En la práctica
/// una pastilla de freno se le compra a dos o tres proveedores según quién la
/// tenga y a cómo, y con una sola columna la respuesta a «¿quién me la vende
/// más barato?» no estaba en ninguna parte: cada remisión pisaba
/// `productos.precio_compra` y el anterior se perdía.
///
/// **El principal vive aquí, no allá.** Tener la columna en `productos` *y*
/// la marca en esta tabla sería el mismo dato en dos sitios, que es lo que
/// prohíbe `REGLAS_BD.md` §1.1: el día que se actualizara uno y no el otro,
/// la ficha y la rejilla dirían proveedores distintos del mismo repuesto.
/// `Producto.proveedorId` sigue existiendo en el modelo, pero es **lectura
/// resuelta** desde [esPrincipal], como `categoriaNombre`.
///
/// Que no haya **dos principales a la vez** lo garantiza una guarda de la
/// base (`guardas_sql.dart`), no la disciplina del repositorio: es justo el
/// tipo de invariante que un método nuevo se salta sin querer.
///
/// [ultimoCosto] es un **snapshot** de §1.2 con una diferencia: sí se
/// actualiza, en cada remisión de ese proveedor. No es el historial —ese está
/// en `compra_detalles`, que no se toca— sino la respuesta rápida a «¿a cómo
/// me lo dejó la última vez?», que es lo que se mira al comparar antes de
/// pedir.
@TableIndex(name: 'idx_producto_proveedores_producto', columns: {#productoId})
@TableIndex(name: 'idx_producto_proveedores_proveedor', columns: {#proveedorId})
class TablaProductoProveedor extends Table {
  @override
  String get tableName => 'producto_proveedores';

  IntColumn get id => integer().autoIncrement()();

  /// `cascade`: la relación no existe sin el producto. No es histórico —lo
  /// que se compró de verdad vive en `compras` y `compra_detalles`, que sí
  /// están protegidas—, así que borrar un producto se lleva sus vínculos y no
  /// deja filas huérfanas apuntando a un id que ya no está.
  IntColumn get productoId => integer()
      .references(TablaProducto, #id, onDelete: KeyAction.cascade)();

  /// `cascade` por lo mismo. Dar de baja a un proveedor se hace con su
  /// `activo`, no borrándolo: si de verdad se borra, lo que se va es la lista
  /// de qué le comprábamos, no las remisiones.
  IntColumn get proveedorId => integer()
      .references(TablaProveedor, #id, onDelete: KeyAction.cascade)();

  /// El código con el que **el proveedor** llama a esta pieza.
  ///
  /// No es el SKU del taller: es lo que hay que decirle por teléfono para que
  /// mande la correcta, y cada proveedor tiene el suyo.
  TextColumn get referenciaProveedor => text().nullable()();

  /// A cómo la dejó la última vez, en pesos enteros. 0 mientras no haya
  /// comprado nada por remisión.
  IntColumn get ultimoCosto => integer().withDefault(const Constant(0))();

  /// Cuándo fue esa última compra. `null` mientras el vínculo sea solo una
  /// anotación de catálogo y no venga de una remisión.
  DateTimeColumn get fechaUltimaCompra => dateTime().nullable()();

  /// El de cabecera: el que se propone al pedir y el que sale en la rejilla.
  ///
  /// Como mucho uno por producto, y lo impone la guarda de la base.
  BoolColumn get esPrincipal => boolean().withDefault(const Constant(false))();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn =>
      dateTime().withDefault(currentDateAndTime)();

  /// Un proveedor no se repite dentro del mismo producto. Es unicidad de
  /// negocio, así que va en el esquema aunque el repositorio la valide
  /// (`REGLAS_BD.md` §3.1).
  @override
  List<Set<Column>> get uniqueKeys => [
        {productoId, proveedorId},
      ];

  @override
  List<String> get customConstraints => [
        'CHECK (ultimo_costo >= 0)',
      ];
}
