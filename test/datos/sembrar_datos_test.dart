// Utilidad de desarrollo: llena la base real con datos de prueba.
//
// **No es un test**: no afirma más que una cosa —que el stock cuadre—. Vive
// aquí por lo mismo que `volcado_esquema_test.dart`: es la forma más simple de
// abrir la base sin montar un binario aparte. Y está **apagado por defecto**,
// porque escribe en la base de verdad del taller y `flutter test` la
// reescribiría en cada pasada.
//
// Uso:
//
//     SEMBRAR=1 flutter test test/datos/sembrar_datos_test.dart
//     SEMBRAR=1 BD=/ruta/otra.sqlite flutter test test/datos/sembrar_datos_test.dart
//
// El catálogo —categorías, productos, clientes, motos, proveedores— se siembra
// **una sola vez**: si ya está, la corrida solo agrega documentos nuevos sobre
// los mismos productos. Así se sube el volumen de operación sin inflar el
// inventario.
//
// La lógica está en `sembrador.dart`, al lado.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/backend/share/database/guardas_sql.dart';

import 'sembrador.dart';

void main() {
  final encendido = Platform.environment['SEMBRAR'] == '1';

  test(
    'siembra la base con datos de prueba',
    skip: encendido
        ? null
        : 'Apagado. Para sembrar: SEMBRAR=1 flutter test test/datos/sembrar_datos_test.dart',
    () async {
      final ruta = Platform.environment['BD'] ??
          '${Platform.environment['HOME']}/Documentos/InventarioK1.sqlite';
      final archivo = File(ruta);

      // ignore: avoid_print
      print('\nBase: $ruta ${archivo.existsSync() ? '' : '(se crea)'}');

      final db = AppDb(NativeDatabase(archivo, setup: (raw) {
        raw.execute('PRAGMA foreign_keys = ON');
        raw.execute('PRAGMA journal_mode = WAL');
      }));

      // Drift solo corre `onCreate` con su propia conexión; al abrir el
      // archivo a mano hay que asegurarse de que las guardas estén puestas.
      for (final guarda in guardasSql) {
        await db.customStatement(guarda);
      }

      final reloj = Stopwatch()..start();

      // Todo en una transacción: 70.000 inserciones sueltas serían 70.000
      // commits, y eso es la diferencia entre segundos y minutos.
      final conteos = await db.transaction(() => Sembrador(db).sembrar());

      reloj.stop();

      var total = 0;
      for (final entrada in conteos.entries) {
        total += entrada.value;
        // ignore: avoid_print
        print('  ${entrada.key.padRight(24)} '
            '${entrada.value.toString().padLeft(7)}');
      }

      // ── Lo que sí se afirma ────────────────────────────────────────────
      //
      // Que el caché de stock cuadre con el libro mayor. Si no cuadra, los
      // datos sembrados no sirven para probar nada: `descuadres()` saldría
      // rojo en la app y no se sabría si es un bug o el sembrador.
      final descuadres = await db.customSelect('''
        SELECT COUNT(*) AS n FROM (
          SELECT p.id
          FROM productos p
          LEFT JOIN movimientos_inventario m ON m.producto_id = p.id
          GROUP BY p.id
          HAVING ABS(p.stock_actual - COALESCE(SUM(m.cantidad), 0)) > 0.0001)
      ''').getSingle().then((f) => f.read<int>('n'));

      final negativos = await db
          .customSelect('SELECT COUNT(*) AS n FROM productos WHERE stock_actual < 0')
          .getSingle()
          .then((f) => f.read<int>('n'));

      await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      final mb = archivo.lengthSync() / 1024 / 1024;

      // ignore: avoid_print
      print('  ${'TOTAL'.padRight(24)} ${total.toString().padLeft(7)} filas');
      // ignore: avoid_print
      print('  Peso: ${mb.toStringAsFixed(1)} MB · ${reloj.elapsed.inSeconds}s '
          '· descuadres: $descuadres · stock negativo: $negativos\n');

      expect(descuadres, 0, reason: 'el stock no cuadra con los movimientos');
      expect(negativos, 0, reason: 'algún documento sacó más de lo que había');

      await db.close();
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
