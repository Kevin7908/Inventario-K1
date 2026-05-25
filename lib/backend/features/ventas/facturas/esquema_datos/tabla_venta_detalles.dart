import 'package:drift/drift.dart';

import '../../../productos/esquema_datos/tabla_producto.dart';
import '../../../tecnicos/esquema_datos/tabla_tecnico.dart';
import '../../servicios/esquema_datos/tabla_servicio.dart';
import 'tabla_ventas.dart';

class TablaVentaDetalles extends Table {
  @override
  String get tableName => 'venta_detalles';

  IntColumn get id => integer().autoIncrement()();

  IntColumn get ventaId =>
      integer().named('venta_id').references(TablaVentas, #id, onDelete: KeyAction.cascade)();

  // 'PRODUCTO' | 'SERVICIO'
  TextColumn get tipoItem => text().named('tipo_item')();

  IntColumn get productoId =>
      integer().nullable().named('producto_id').references(TablaProducto, #id)();

  IntColumn get servicioId =>
      integer().nullable().named('servicio_id').references(TablaServicio, #id)();

  IntColumn get tecnicoId =>
      integer().nullable().named('tecnico_id').references(TablaTecnico, #id)();

  // Snapshot del nombre en el momento de la venta
  TextColumn get descripcion => text()();

  RealColumn get cantidad =>
      real().withDefault(const Constant(1.0))();

  RealColumn get precioUnitario =>
      real().named('precio_unitario')();

  RealColumn get costoUnitario =>
      real().named('costo_unitario').withDefault(const Constant(0.0))();

  RealColumn get subtotal => real()();
}
