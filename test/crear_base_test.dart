// Utilidad de desarrollo: crea la base de la app desde cero.
//
// **No es un test y destruye datos**: borra la base que haya en `~/Documentos`
// y la recrea con el mismo Drift que usa la aplicación —tablas, guardas y
// catálogos iniciales—. Se ejecuta a mano cuando el esquema cambió y hay que
// empezar de nuevo.
//
// Por eso va **apagada por defecto**. Vive en `test/`, así que `flutter test`
// la recogía junto con los demás y le borraba la base al que estuviera usando
// la app: se trabajaba una mañana entera, alguien corría la suite, y al
// siguiente hot reload no quedaba nada. Ahora hay que pedirla a mano:
//
// ```
// RECREAR_BD=1 flutter test test/crear_base_test.dart
// ```
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:path/path.dart' as p;

/// Solo corre si se pide explícitamente por entorno.
final _pedida = Platform.environment['RECREAR_BD'] == '1';

void main() {
  test('recrea ~/Documentos/InventarioK1.sqlite', () async {
    final carpeta = p.join(
      Platform.environment['HOME']!,
      'Documentos',
    );
    final ruta = p.join(carpeta, 'InventarioK1.sqlite');

    // También los ficheros del WAL: dejar el `-wal` de la base anterior junto
    // a un fichero nuevo es la forma más rápida de corromperla.
    for (final sufijo in ['', '-wal', '-shm']) {
      final f = File('$ruta$sufijo');
      if (f.existsSync()) {
        f.deleteSync();
        // ignore: avoid_print
        print('borrado: ${f.path}');
      }
    }

    final db = AppDb(
      NativeDatabase(
        File(ruta),
        setup: (raw) {
          raw.execute('PRAGMA journal_mode = WAL');
          raw.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );

    // Cualquier consulta dispara `onCreate`, que crea tablas y guardas.
    final tablas = await db
        .customSelect("SELECT COUNT(*) AS n FROM sqlite_master "
            "WHERE type = 'table'")
        .getSingle();
    await db.close();

    // ignore: avoid_print
    print('creada: $ruta  ·  ${tablas.read<int>('n')} tablas');

    expect(File(ruta).existsSync(), isTrue);
  }, skip: _pedida ? null : 'Utilidad manual que BORRA la base de la app. '
      'Para ejecutarla: RECREAR_BD=1 flutter test test/crear_base_test.dart');
}
