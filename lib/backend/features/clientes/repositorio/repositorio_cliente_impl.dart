import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/features/clientes/repositorio/repositorio_cliente.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import '../mapper/cliente_mapper.dart';
import '../modelo/cliente.dart';



class RepositorioClientesImpl implements RepositorioClientes {
  final AppDb _db;

  RepositorioClientesImpl(this._db);

  // Stream reactivo

  @override
  Stream<List<Cliente>> observarTodos() {
    return (_db.select(_db.tablaCliente)
          ..orderBy([
            (t) => OrderingTerm.asc(t.nombres),
          ]))
        .watch()
        .map((filas) => filas.map(ClienteMapper.filaAModelo).toList());
  }

  // Consultas puntuales 

  @override
  Future<List<Cliente>> obtenerTodos() async {
    final filas = await (_db.select(_db.tablaCliente)
          ..orderBy([(t) => OrderingTerm.asc(t.nombres)]))
        .get();
    return filas.map(ClienteMapper.filaAModelo).toList();
  }

  @override
  Future<List<Cliente>> buscar(String query) async {
    final termino = '%${query.toLowerCase()}%';
    final filas = await (_db.select(_db.tablaCliente)
          ..where(
            (t) =>
                t.nombres.lower().like(termino) |
                t.apellidos.lower().like(termino) |
                t.cedula.lower().like(termino) |
                t.telefono.lower().like(termino),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.nombres)]))
        .get();
    return filas.map(ClienteMapper.filaAModelo).toList();
  }

  // Escritura

  @override
  Future<int> crear(Cliente cliente) async {
    final companion = ClienteMapper.modeloACompanion(cliente);
    return _db.into(_db.tablaCliente).insert(companion);
  }

  @override
  Future<void> actualizar(Cliente cliente) async {
    final companion = ClienteMapper.modeloACompanion(cliente);
    await (_db.update(_db.tablaCliente)
          ..where((t) => t.id.equals(cliente.id)))
        .write(companion);
  }

  @override
  Future<void> eliminar(int id) async {
    await (_db.delete(_db.tablaCliente)..where((t) => t.id.equals(id))).go();
  }
}