import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_db.dart';

/// La única conexión a SQLite de la app.
///
/// Es el puente que todos los `repositorioXProvider` observan. Vive aquí, en
/// `share/database/`, y no dentro de un módulo, para que ninguna feature
/// dependa de otra solo por la base.
///
/// Antes lo resolvía `locator<AppDb>()` con `get_it`; el `locator` se fue con
/// la migración de `autenticacion` y con él el segundo mecanismo de inyección
/// que quedaba en el proyecto (`CLAUDE.md` §3).
final appDatabaseProvider = Provider<AppDb>(
  name: 'appDatabaseProvider',
  (ref) {
    final db = AppDb();
    ref.onDispose(db.close);
    return db;
  },
);
