// Utilidad de desarrollo: imprime el esquema real que crea Drift.
//
// No es un test de verdad —no afirma nada—, pero vive aquí porque es la forma
// más simple de arrancar la base con `NativeDatabase` sin montar un binario
// aparte. Se ejecuta a mano cuando hay que regenerar el `.sql` de diseño.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'soporte/base_en_memoria.dart';

void main() {
  test('vuelca el esquema a /tmp/esquema.sql', () async {
    final db = baseEnMemoria();

    final filas = await db
        .customSelect(
          "SELECT type, name, sql FROM sqlite_master "
          "WHERE sql IS NOT NULL ORDER BY "
          "CASE type WHEN 'table' THEN 0 WHEN 'index' THEN 1 ELSE 2 END, name",
        )
        .get();

    final buffer = StringBuffer();
    for (final fila in filas) {
      buffer
        ..writeln('${fila.read<String>("type")}\t${fila.read<String>("name")}')
        ..writeln(fila.read<String>('sql'))
        ..writeln('---8<---');
    }
    File('/tmp/esquema.sql').writeAsStringSync(buffer.toString());
    await db.close();
  });
}
