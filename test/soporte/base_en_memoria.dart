import 'package:drift/native.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

/// Una base en memoria con las mismas garantías que la de producción.
///
/// El `PRAGMA foreign_keys` no es un detalle: SQLite lo trae **apagado** por
/// defecto, así que sin él un test verde no prueba nada sobre las claves
/// foráneas —insertar una venta con un cliente inexistente pasaría en
/// silencio—. `AppDb._openConnection` lo activa en la app; aquí se hace lo
/// mismo para que los tests corran contra el mismo motor.
AppDb baseEnMemoria() => AppDb(
      NativeDatabase.memory(
        setup: (db) => db.execute('PRAGMA foreign_keys = ON'),
      ),
    );
