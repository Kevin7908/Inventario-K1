// Utilidad de desarrollo: crea la base de la app desde cero.
//
// No es un test: borra la base que haya en `~/Documentos` y la recrea con el
// mismo Drift que usa la aplicación —tablas, guardas y catálogos iniciales—.
// Se ejecuta a mano cuando el esquema cambió y hay que empezar de nuevo.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:path/path.dart' as p;

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
  });
}
