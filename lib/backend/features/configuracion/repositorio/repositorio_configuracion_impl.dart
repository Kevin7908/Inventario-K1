import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../modelo/clave_configuracion.dart';
import 'repositorio_configuracion.dart';

class RepositorioConfiguracionImpl implements RepositorioConfiguracion {
  RepositorioConfiguracionImpl(this._db);

  final AppDb _db;

  $TablaConfiguracionTable get _tabla => _db.tablaConfiguracion;

  @override
  Future<String> leer(ClaveConfiguracion clave) async {
    final fila = await (_db.select(_tabla)
          ..where((c) => c.clave.equals(clave.clave)))
        .getSingleOrNull();
    return fila?.valor ?? clave.porDefecto;
  }

  @override
  Stream<Map<ClaveConfiguracion, String>> observarTodas() {
    return _db.select(_tabla).watch().map((filas) {
      // Se parte de los valores por defecto y se pisan con lo guardado: así
      // una clave que todavía no está en la tabla no falta en el mapa.
      final valores = {
        for (final clave in ClaveConfiguracion.values) clave: clave.porDefecto,
      };
      for (final fila in filas) {
        final clave = ClaveConfiguracion.desdeClave(fila.clave);
        if (clave != null && fila.valor != null) valores[clave] = fila.valor!;
      }
      return valores;
    });
  }

  @override
  Future<void> guardar(ClaveConfiguracion clave, String valor) async {
    // Un `UPSERT` en una sola sentencia, en vez del ciclo «¿existe? → INSERT
    // o UPDATE», que además tenía carrera. El `target` es explícito: por
    // defecto Drift resuelve el conflicto contra la clave primaria, y aquí el
    // que choca es el `UNIQUE` de `clave`.
    final fila = TablaConfiguracionCompanion.insert(
      clave: clave.clave,
      valor: Value(valor),
      actualizadoEn: Value(DateTime.now()),
    );

    await _db.into(_tabla).insert(
          fila,
          onConflict: DoUpdate(
            (_) => fila,
            target: [_tabla.clave],
          ),
        );
  }
}
