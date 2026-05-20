import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/autenticacion/esquema_datos/tabla_usuario.dart';
import '../../features/categorias/esquema_datos/tabla_categoria.dart';
import '../../features/clientes/esquema_datos/tabla_cliente.dart';
import '../../features/especializacion/esquema_datos/tabla_especializacion.dart';
import '../../features/motos/esquema_datos/tabla_moto.dart';
import '../../features/productos/esquema_datos/tabla_producto.dart';
import '../../features/tecnicos/esquema_datos/tabla_tecnico.dart';
import '../../features/unidades_medida/esquema_datos/tabla_unidades_medida.dart';
import '../../features/proveedores/esquema_datos/tabla_proveedor.dart';
import '../../features/ventas/servicios/esquema_datos/tabla_servicio.dart';

part 'app_db.g.dart';

@DriftDatabase(
  tables: [
    TablaCategoria, 
    TablaUnidadesMedida, 
    TablaProveedor, TablaProducto, 
    TablaUsuario,
    TablaCliente,
    TablaMoto,
    TablaEspecializacion,
    TablaTecnico,
    TablaServicio,
    ],
)
class AppDb extends _$AppDb {
  AppDb([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

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
