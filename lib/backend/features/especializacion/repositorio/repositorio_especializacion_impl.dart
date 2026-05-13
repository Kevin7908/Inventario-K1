import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../mapper/especializacion_mapper.dart';
import '../modelo/especializacion.dart';
import 'repositorio_especializacion.dart';

class RepositorioEspecializacionImpl implements RepositorioEspecializacion {
  const RepositorioEspecializacionImpl(this._db);

  final AppDb _db;

  // Alias conveniente
  $TablaEspecializacionTable get _tabla => _db.tablaEspecializacion;

  // Stream reactivo 
  @override
  Stream<List<Especializacion>> observarTodas() {
    return (_db.select(_tabla)
          ..orderBy([(t) => OrderingTerm.asc(t.nombre)]))
        .watch()
        .map(EspecializacionMapper.desdeFilas);
  }

  @override
  Future<List<Especializacion>> obtenerTodas() async {
    final filas = await (_db.select(_tabla)
          ..orderBy([(t) => OrderingTerm.asc(t.nombre)]))
        .get();
    return EspecializacionMapper.desdeFilas(filas);
  }

  // Validación de nombre único 
  @override
  Future<bool> existeNombre(String nombre, {int? ignorarId}) async {
    final query = _db.select(_tabla)
      ..where(
        (t) => t.nombre.lower().equals(nombre.toLowerCase()),
      );

    if (ignorarId != null) {
      query.where((t) => t.id.isNotValue(ignorarId));
    }

    final fila = await query.getSingleOrNull();
    return fila != null;
  }

  // CRUD 
  @override
  Future<Especializacion> agregar({
    required String nombre,
    String? descripcion,
  }) async {
    final companion = EspecializacionMapper.aCompanionNuevo(
      nombre: nombre.trim(),
      descripcion: descripcion?.trim(),
    );
    final id = await _db.into(_tabla).insert(companion);
    final fila = await (_db.select(_tabla)..where((t) => t.id.equals(id)))
        .getSingle();
    return EspecializacionMapper.desdeFila(fila);
  }

  @override
  Future<Especializacion> actualizar({
    required int id,
    required String nombre,
    String? descripcion,
  }) async {
    final companion = EspecializacionMapper.aCompanionActualizar(
      id: id,
      nombre: nombre.trim(),
      descripcion: descripcion?.trim(),
    );
    await (_db.update(_tabla)..where((t) => t.id.equals(id)))
        .write(companion);
    final fila = await (_db.select(_tabla)..where((t) => t.id.equals(id)))
        .getSingle();
    return EspecializacionMapper.desdeFila(fila);
  }

  @override
  Future<void> eliminar(int id) async {
    await (_db.delete(_tabla)..where((t) => t.id.equals(id))).go();
  }
}