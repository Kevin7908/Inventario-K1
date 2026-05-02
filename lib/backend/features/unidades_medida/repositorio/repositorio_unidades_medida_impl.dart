import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import '../modelo/unidad_medida.dart';
import 'repositorio_unidades_medida.dart';

class RepositorioUnidadesMedidaImpl implements RepositorioUnidadesMedida {
  final AppDb _db;

  RepositorioUnidadesMedidaImpl(this._db);

  UnidadMedida _filaAModelo(TablaUnidadesMedidaData fila) {
    return UnidadMedida(
      id: fila.id,
      nombre: fila.nombre,
      abreviatura: fila.abreviatura,
      tipo: fila.tipo,
      descripcion: fila.descripcion,
      creadoEn: fila.creadoEn,
      actualizadoEn: fila.actualizadoEn,
    );
  }

  TablaUnidadesMedidaCompanion _modeloACompanion(UnidadMedida unidad) {
    return TablaUnidadesMedidaCompanion(
      id: unidad.id != null ? Value(unidad.id!) : const Value.absent(),
      nombre: Value(unidad.nombre),
      abreviatura: Value(unidad.abreviatura),
      tipo: Value(unidad.tipo),
      descripcion: Value(unidad.descripcion),
      actualizadoEn: Value(DateTime.now()),
    );
  }

  @override
  Future<List<UnidadMedida>> obtenerTodas() async {
    final filas = await _db.select(_db.tablaUnidadesMedida).get();
    return filas.map(_filaAModelo).toList();
  }

  @override
  Future<UnidadMedida?> obtenerPorId(int id) async {
    final fila = await (_db.select(
      _db.tablaUnidadesMedida,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return fila != null ? _filaAModelo(fila) : null;
  }

  @override
  Future<List<UnidadMedida>> buscarPorNombre(String consulta) async {
    final filas = await (_db.select(
      _db.tablaUnidadesMedida,
    )..where((t) => t.nombre.like('%$consulta%'))).get();
    return filas.map(_filaAModelo).toList();
  }

  @override
  Future<List<UnidadMedida>> obtenerPorTipo(String tipo) async {
    final filas = await (_db.select(
      _db.tablaUnidadesMedida,
    )..where((t) => t.tipo.equals(tipo))).get();
    return filas.map(_filaAModelo).toList();
  }

  @override
  Future<UnidadMedida> crear(UnidadMedida unidad) async {
    final companion = _modeloACompanion(unidad);
    final id = await _db.into(_db.tablaUnidadesMedida).insert(companion);
    final creada = await obtenerPorId(id);
    return creada!;
  }

  @override
  Future<UnidadMedida> actualizar(UnidadMedida unidad) async {
    final companion = _modeloACompanion(unidad);
    await (_db.update(
      _db.tablaUnidadesMedida,
    )..where((t) => t.id.equals(unidad.id!))).write(companion);
    final actualizada = await obtenerPorId(unidad.id!);
    return actualizada!;
  }

  @override
  Future<void> eliminar(int id) async {
    await (_db.delete(
      _db.tablaUnidadesMedida,
    )..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<bool> existeNombre(String nombre, {int? excludirId}) async {
    final query = _db.select(_db.tablaUnidadesMedida)
      ..where((t) => t.nombre.lower().equals(nombre.toLowerCase()));
    if (excludirId != null) {
      query.where((t) => t.id.equals(excludirId).not());
    }
    return await query.getSingleOrNull() != null;
  }

  @override
  Future<bool> existeAbreviatura(String abreviatura, {int? excludirId}) async {
    final query = _db.select(_db.tablaUnidadesMedida)
      ..where((t) => t.abreviatura.lower().equals(abreviatura.toLowerCase()));
    if (excludirId != null) {
      query.where((t) => t.id.equals(excludirId).not());
    }
    return await query.getSingleOrNull() != null;
  }
}
