import 'dart:async';
import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/features/tecnicos/repositorio/repositorio_tecnico.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import '../mapper/tecnico_mapper.dart';
import '../modelo/tecnico.dart';

final class RepositorioTecnicoDrift implements RepositorioTecnico {
  const RepositorioTecnicoDrift(this._db);

  final AppDb _db;

  $TablaTecnicoTable get _tabla => _db.tablaTecnico;

  @override
  Stream<List<Tecnico>> observarTodos() {
    return (_db.select(_tabla)
          ..orderBy([
            (t) => OrderingTerm(expression: t.nombres),
          ]))
        .watch()
        .map((filas) => filas.map(TecnicoMapper.desdeFila).toList());
  }

  @override
  Future<bool> existeCedula(String cedula, {int? excluirId}) async {
    var query = _db.select(_tabla)
      ..where((t) => t.cedula.equals(cedula));

    if (excluirId != null) {
      query = query..where((t) => t.id.isNotValue(excluirId));
    }

    final resultado = await query.getSingleOrNull();
    return resultado != null;
  }

  @override
  Future<Tecnico> insertar({
    required String nombres,
    String? cedula,
    String? apellidos,
    String? telefono,
    String? email,
    int? especializacionId,
    double? salarioBase,
    required bool activo,
  }) async {
    final companion = TecnicoMapper.aCompanion(
      nombres: nombres,
      cedula: cedula,
      apellidos: apellidos,
      telefono: telefono,
      email: email,
      especializacionId: especializacionId,
      salarioBase: salarioBase,
      activo: activo,
    );

    final id = await _db.into(_tabla).insert(companion);
    final fila = await (_db.select(_tabla)..where((t) => t.id.equals(id)))
        .getSingle();
    return TecnicoMapper.desdeFila(fila);
  }

  @override
  Future<Tecnico> actualizar({
    required int id,
    required String nombres,
    String? cedula,
    String? apellidos,
    String? telefono,
    String? email,
    int? especializacionId,
    double? salarioBase,
    required bool activo,
  }) async {
    final companion = TecnicoMapper.aCompanion(
      nombres: nombres,
      cedula: cedula,
      apellidos: apellidos,
      telefono: telefono,
      email: email,
      especializacionId: especializacionId,
      salarioBase: salarioBase,
      activo: activo,
    );

    await (_db.update(_tabla)..where((t) => t.id.equals(id))).write(companion);
    final fila = await (_db.select(_tabla)..where((t) => t.id.equals(id)))
        .getSingle();
    return TecnicoMapper.desdeFila(fila);
  }

  @override
  Future<void> eliminar(int id) async {
    await (_db.delete(_tabla)..where((t) => t.id.equals(id))).go();
  }
}