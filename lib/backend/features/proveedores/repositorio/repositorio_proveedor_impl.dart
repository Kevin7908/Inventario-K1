// backend/features/proveedores/repositorio/repositorio_proveedores_impl.dart

import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/features/proveedores/modelo/proveedor.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import '../mapper/proveedor_mapper.dart';
import 'repositorio_proveedores.dart';

// Implementación concreta usando Drift como fuente de datos
class RepositorioProveedoresImpl implements RepositorioProveedores {
  final AppDb _db;

  RepositorioProveedoresImpl(this._db);

  @override
  Stream<List<Proveedor>> observarTodas() {
    return _db
        .select(_db.tablaProveedor)
        .watch()
        .map((filas) => filas.map(ProveedorMapper.filaAModelo).toList());
  }

  @override
  Future<Proveedor?> obtenerPorId(int id) async {
    final fila = await (_db.select(
      _db.tablaProveedor,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return fila != null ? ProveedorMapper.filaAModelo(fila) : null;
  }

  @override
  Future<List<Proveedor>> buscarPorNombre(String consulta) async {
    final filas = await (_db.select(
      _db.tablaProveedor,
    )..where((t) => t.nombre.like('%$consulta%'))).get();
    return filas.map(ProveedorMapper.filaAModelo).toList();
  }

  @override
  Future<Proveedor> crear(Proveedor proveedor) async {
    final companion = ProveedorMapper.modeloACompanion(proveedor);
    final id = await _db.into(_db.tablaProveedor).insert(companion);
    final creado = await obtenerPorId(id);
    return creado!;
  }

  @override
  Future<Proveedor> actualizar(Proveedor proveedor) async {
    final companion = ProveedorMapper.modeloACompanion(proveedor);
    await (_db.update(
      _db.tablaProveedor,
    )..where((t) => t.id.equals(proveedor.id!))).write(companion);
    final actualizado = await obtenerPorId(proveedor.id!);
    return actualizado!;
  }

  @override
  Future<void> eliminar(int id) async {
    await (_db.delete(_db.tablaProveedor)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<bool> existeNombre(String nombre, {int? excludirId}) async {
    final query = _db.select(_db.tablaProveedor)
      ..where((t) => t.nombre.lower().equals(nombre.toLowerCase()));
    if (excludirId != null) {
      query.where((t) => t.id.equals(excludirId).not());
    }
    final resultado = await query.getSingleOrNull();
    return resultado != null;
  }

  @override
  Future<bool> existeNit(String nit, {int? excludirId}) async {
    final query = _db.select(_db.tablaProveedor)
      ..where((t) => t.nitCedula.equals(nit));
    if (excludirId != null) {
      query.where((t) => t.id.equals(excludirId).not());
    }
    final resultado = await query.getSingleOrNull();
    return resultado != null;
  }
}
