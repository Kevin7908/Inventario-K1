import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/features/categorias/esquema_datos/tabla_categoria.dart';
import 'package:inventario_k1/backend/features/proveedores/esquema_datos/tabla_proveedor.dart';
import 'package:inventario_k1/backend/features/unidades_medida/esquema_datos/tabla_unidades_medida.dart';

class TablaProducto extends Table {
  @override
  String get tableName => 'productos';

  IntColumn get id => integer().autoIncrement()();

  TextColumn get sku => text()();

  TextColumn get nombre => text()();

  TextColumn get descripcion => text().nullable()();

  IntColumn get categoriaId =>
      integer().nullable().references(TablaCategoria, #id)();

  IntColumn get unidadMedidaId =>
      integer().nullable().references(TablaUnidadesMedida, #id)();

  IntColumn get proveedorId =>
      integer().nullable().references(TablaProveedor, #id)();

  RealColumn get precioCompra => real().withDefault(const Constant(0))();

  RealColumn get precioVenta => real().withDefault(const Constant(0))();

  RealColumn get precioVentaTaller => real().nullable()();

  RealColumn get stockActual => real().withDefault(const Constant(0))();

  RealColumn get stockMinimo => real().withDefault(const Constant(0))();

  TextColumn get ubicacionBodega => text().nullable()();

  TextColumn get imagenUrl => text().nullable()();

  BoolColumn get activo => boolean().withDefault(const Constant(true))();

  DateTimeColumn get creadoEn =>
      dateTime().nullable().withDefault(currentDateAndTime)();

  DateTimeColumn get actualizadoEn =>
      dateTime().nullable().withDefault(currentDateAndTime)();
}