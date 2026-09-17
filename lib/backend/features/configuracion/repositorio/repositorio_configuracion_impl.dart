import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../../../share/dominio/permiso.dart';
import '../../../share/dominio/sesion_actual.dart';
import '../modelo/clave_configuracion.dart';
import 'repositorio_configuracion.dart';

class RepositorioConfiguracionImpl
    with FirmaDeSesion
    implements RepositorioConfiguracion {
  RepositorioConfiguracionImpl(this._db, [this.sesion]);

  final AppDb _db;

  @override
  final SesionActual? sesion;

  $TablaConfiguracionTable get _tabla => _db.tablaConfiguracion;

  /// **Sin compuerta, a propósito.** Leer una clave suelta no es entrar a
  /// Configuración: es lo que hace el encabezado de cada factura para saber
  /// cómo se llama el taller, y un cajero imprime facturas sin tener
  /// `CONFIGURACION_VER`. Lo que esa compuerta protege es el formulario
  /// entero, y ese lo sirve [observarTodas].
  @override
  Future<String> leer(ClaveConfiguracion clave) async {
    final fila = await (_db.select(_tabla)
          ..where((c) => c.clave.equals(clave.clave)))
        .getSingleOrNull();
    return fila?.valor ?? clave.porDefecto;
  }

  /// Sin compuerta, igual que [leer] y por la misma razón.
  @override
  Future<Map<ClaveConfiguracion, String>> leerTodas() async =>
      _armar(await _db.select(_tabla).get());

  @override
  Stream<Map<ClaveConfiguracion, String>> observarTodas() {
    exigir(Permiso.configuracionVer);

    return _db.select(_tabla).watch().map(_armar);
  }

  /// Los valores por defecto pisados con lo guardado: así una clave que
  /// todavía no está en la tabla no falta en el mapa.
  Map<ClaveConfiguracion, String> _armar(List<TablaConfiguracionData> filas) {
    final valores = {
      for (final clave in ClaveConfiguracion.values) clave: clave.porDefecto,
    };
    for (final fila in filas) {
      final clave = ClaveConfiguracion.desdeClave(fila.clave);
      if (clave != null && fila.valor != null) valores[clave] = fila.valor!;
    }
    return valores;
  }

  @override
  Future<void> guardar(ClaveConfiguracion clave, String valor) async {
    exigir(Permiso.configuracionEditar);

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
