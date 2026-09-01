import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../consecutivos/tabla_consecutivo.dart';
import 'guardas_sql.dart';

import '../../features/autenticacion/esquema_datos/tabla_usuario.dart';
import '../../features/autenticacion/esquema_datos/tabla_usuario_permiso.dart';
import '../../features/bitacora/esquema_datos/tabla_bitacora.dart';
import '../../features/categorias/esquema_datos/tabla_categoria.dart';
import '../../features/clientes/esquema_datos/tabla_cliente.dart';
import '../../features/configuracion/esquema_datos/configuracion_tabla.dart';
import '../../features/cotizaciones/esquema_datos/tabla_cotizacion.dart';
import '../../features/cotizaciones/esquema_datos/tabla_cotizacion_item.dart';
import '../../features/especializacion/esquema_datos/tabla_especializacion.dart';
import '../../features/inventario/esquema_datos/tabla_movimiento_inventario.dart';
import '../../features/motos/esquema_datos/tabla_marca_moto.dart';
import '../../features/motos/esquema_datos/tabla_modelo_moto.dart';
import '../../features/motos/esquema_datos/tabla_moto.dart';
import '../../features/persona/esquema_datos/tabla_persona.dart';
import '../../features/productos/esquema_datos/tabla_producto.dart';
import '../../features/productos/esquema_datos/tabla_producto_compatibilidad.dart';
import '../../features/tecnicos/esquema_datos/tabla_tecnico.dart';
import '../../features/unidades_medida/esquema_datos/tabla_unidades_medida.dart';
import '../../features/proveedores/esquema_datos/tabla_proveedor.dart';
import '../../features/pos/esquema_datos/tabla_venta_detalles.dart';
import '../../features/pos/esquema_datos/tabla_ventas.dart';
import '../../features/ordenes/esquema_datos/tabla_ordenes_cargo.dart';
import '../../features/ordenes/esquema_datos/tabla_ordenes_repuesto.dart';
import '../../features/ordenes/esquema_datos/tabla_ordenes_servicio.dart';
import '../../features/ordenes/esquema_datos/tabla_ordenes_tarea.dart';
import '../../features/servicios/esquema_datos/tabla_servicio.dart';
import '../../features/reservas/esquema_datos/tabla_reserva.dart';
import '../../features/reservas/esquema_datos/tabla_reserva_item.dart';
import '../../features/reservas/esquema_datos/tabla_reserva_abono.dart';
import '../../features/devoluciones/esquema_datos/tabla_devolucion.dart';
import '../../features/devoluciones/esquema_datos/tabla_devolucion_detalle.dart';
import '../../features/deudores/esquema_datos/tabla_deudor.dart';
import '../../features/deudores/esquema_datos/tabla_deudor_item.dart';
import '../../features/deudores/esquema_datos/tabla_deudor_pago.dart';

part 'app_db.g.dart';

@DriftDatabase(
  tables: [
    TablaPersona,
    TablaConsecutivo,
    TablaConfiguracion,
    TablaCategoria,
    TablaUnidadesMedida,
    TablaProveedor,
    TablaProducto,
    TablaProductoCompatibilidad,
    TablaMovimientoInventario,
    TablaUsuario,
    TablaUsuarioPermiso,
    TablaCliente,
    TablaMarcaMoto,
    TablaModeloMoto,
    TablaMoto,
    TablaEspecializacion,
    TablaTecnico,
    TablaServicio,
    TablaOrdenesServicio,
    TablaOrdenesTarea,
    TablaOrdenesRepuesto,
    TablaOrdenesCargo,
    TablaVentas,
    TablaVentaDetalles,
    TablaCotizacion,
    TablaCotizacionItem,
    TablaReserva,
    TablaReservaItem,
    TablaReservaAbono,
    TablaDeudor,
    TablaDeudorItem,
    TablaDeudorPago,
    TablaDevolucion,
    TablaDevolucionDetalle,
    TablaBitacora,
  ],
)
class AppDb extends _$AppDb {
  AppDb([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

  /// Además de crear las tablas, instala las guardas de `guardas_sql.dart`.
  ///
  /// Van en `onCreate` y no en `beforeOpen` porque son parte del esquema, no
  /// de la sesión. Cuando `schemaVersion` empiece a subir —el día que haya un
  /// taller con datos reales— cada paso de migración tendrá que volver a
  /// aplicarlas.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          for (final guarda in guardasSql) {
            await customStatement(guarda);
          }
        },
      );

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'InventarioK1.sqlite'));

      return NativeDatabase.createInBackground(
        file,
        setup: (db) async {
          // Habilitar WAL mode para mejor rendimiento
          db.execute('PRAGMA journal_mode = WAL');
          db.execute('PRAGMA foreign_keys = ON');
        },
      );
    });
  }
}
