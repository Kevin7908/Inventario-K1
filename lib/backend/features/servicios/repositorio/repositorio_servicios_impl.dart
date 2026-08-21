import 'package:drift/drift.dart';

import '../../../../share/database/app_db.dart';
import '../mapper/servicio_mapper.dart';
import '../modelo/servicio.dart';
import 'repositorio_servicios.dart';

class RepositorioServiciosImpl implements RepositorioServicios {
  const RepositorioServiciosImpl(this._db);

  final AppDb _db;

  // Alias conveniente al getter generado por Drift.
  $TablaServicioTable get _tabla => _db.tablaServicio;

  @override
  Stream<List<Servicio>> observarTodos() {
    return (_db.select(_tabla)
          ..orderBy([
            (t) => OrderingTerm(expression: t.activo, mode: OrderingMode.desc),
            (t) => OrderingTerm.asc(t.nombre),
          ]))
        .watch()
        .map(ServicioMapper.desdeFilas);
  }

  @override
  Future<List<Servicio>> obtenerTodos() async {
    final filas = await (_db.select(_tabla)
          ..orderBy([
            (t) => OrderingTerm(expression: t.activo, mode: OrderingMode.desc),
            (t) => OrderingTerm.asc(t.nombre),
          ]))
        .get();
    return ServicioMapper.desdeFilas(filas);
  }

  // Validacion 

  @override
  Future<bool> existeNombre(String nombre, {int? ignorarId}) async {
    final query = _db.select(_tabla)
      ..where((t) => t.nombre.lower().equals(nombre.toLowerCase()));

    if (ignorarId != null) {
      query.where((t) => t.id.isNotValue(ignorarId));
    }

    return (await query.getSingleOrNull()) != null;
  }

  @override
  Future<Servicio> agregar({
    required String nombre,
    String? descripcion,
    int precioSugerido = 0,
    bool activo = true,
  }) async {
    final companion = ServicioMapper.aCompanionNuevo(
      nombre: nombre.trim(),
      descripcion: descripcion?.trim(),
      precioSugerido: precioSugerido,
      activo: activo,
    );
    final id = await _db.into(_tabla).insert(companion);
    return _porId(id);
  }

  @override
  Future<Servicio> actualizar({
    required int id,
    required String nombre,
    String? descripcion,
    int precioSugerido = 0,
    required bool activo,
  }) async {
    final companion = ServicioMapper.aCompanionActualizar(
      id: id,
      nombre: nombre.trim(),
      descripcion: descripcion?.trim(),
      precioSugerido: precioSugerido,
      activo: activo,
    );
    await (_db.update(_tabla)..where((t) => t.id.equals(id))).write(companion);
    return _porId(id);
  }

  @override
  Future<void> eliminar(int id) async {
    final eliminados =
        await (_db.delete(_tabla)..where((t) => t.id.equals(id))).go();
    if (eliminados == 0) {
      throw Exception('No se encontro el servicio con id $id.');
    }
  }

  @override
  Future<void> alternarActivo(int id, {required bool activo}) async {
    await (_db.update(_tabla)..where((t) => t.id.equals(id)))
        .write(TablaServicioCompanion(activo: Value(activo)));
  }

  // Helper privado

  Future<Servicio> _porId(int id) async {
    final fila =
        await (_db.select(_tabla)..where((t) => t.id.equals(id))).getSingle();
    return ServicioMapper.desdeFila(fila);
  }
}