import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/features/motos/repositorio/repositorio_motos.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import '../mapper/moto_mapper.dart';
import '../modelo/moto.dart';

class RepositorioMotosImpl implements RepositorioMotos {
  final AppDb _db;

  RepositorioMotosImpl(this._db);

JoinedSelectStatement<HasResultSet, dynamic> get _baseQuery {
  return _db.select(_db.tablaMoto).join([
    leftOuterJoin(
      _db.tablaCliente,
      _db.tablaCliente.id.equalsExp(_db.tablaMoto.clienteId),
    ),
  ]);
}

  Moto _rowToMoto(TypedResult row) {
    final motoData = row.readTable(_db.tablaMoto);
    final clienteData = row.readTableOrNull(_db.tablaCliente);
    final nombreCliente = clienteData != null
        ? '${clienteData.nombres} ${clienteData.apellidos ?? ''}'.trim()
        : null;
    return MotoMapper.filaAModelo(motoData, nombreCliente: nombreCliente);
  }

  // Stream reactivo (todos)

  @override
  Stream<List<Moto>> observarTodos() {
    return (_baseQuery
          ..orderBy([
            OrderingTerm.asc(_db.tablaMoto.marca),
            OrderingTerm.asc(_db.tablaMoto.modelo),
          ]))
        .watch()
        .map((rows) => rows.map(_rowToMoto).toList());
  }

  //Stream reactivo (por cliente) 

  @override
  Stream<List<Moto>> observarPorCliente(int clienteId) {
    return (_baseQuery
          ..where(_db.tablaMoto.clienteId.equals(clienteId))
          ..orderBy([
            OrderingTerm.asc(_db.tablaMoto.marca),
            OrderingTerm.asc(_db.tablaMoto.modelo),
          ]))
        .watch()
        .map((rows) => rows.map(_rowToMoto).toList());
  }

  // Consulta puntual 

  @override
  Future<List<Moto>> obtenerTodos() async {
    final rows = await (_baseQuery
          ..orderBy([
            OrderingTerm.asc(_db.tablaMoto.marca),
            OrderingTerm.asc(_db.tablaMoto.modelo),
          ]))
        .get();
    return rows.map(_rowToMoto).toList();
  }

  // Búsqueda 

  @override
  Future<List<Moto>> buscar(String query) async {
    final termino = '%${query.toLowerCase()}%';
    final rows = await (_baseQuery
          ..where(
            _db.tablaMoto.marca.lower().like(termino) |
                _db.tablaMoto.modelo.lower().like(termino) |
                _db.tablaMoto.placa.lower().like(termino) |
                _db.tablaMoto.color.lower().like(termino) |
                _db.tablaMoto.vin.lower().like(termino),
          )
          ..orderBy([
            OrderingTerm.asc(_db.tablaMoto.marca),
            OrderingTerm.asc(_db.tablaMoto.modelo),
          ]))
        .get();
    return rows.map(_rowToMoto).toList();
  }

  // Escritura 

  @override
  Future<int> crear(Moto moto) async {
    final companion = MotoMapper.modeloACompanion(moto);
    return _db.into(_db.tablaMoto).insert(companion);
  }

  @override
  Future<void> actualizar(Moto moto) async {
    final companion = MotoMapper.modeloACompanion(moto);
    await (_db.update(_db.tablaMoto)
          ..where((t) => t.id.equals(moto.id)))
        .write(companion);
  }

  @override
  Future<void> eliminar(int id) async {
    await (_db.delete(_db.tablaMoto)..where((t) => t.id.equals(id))).go();
  }
}