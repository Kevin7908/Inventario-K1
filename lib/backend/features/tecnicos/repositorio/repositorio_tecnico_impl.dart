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
          ..orderBy([(t) => OrderingTerm(expression: t.nombres)]))
        .watch()
        .map((filas) => filas.map(TecnicoMapper.desdeFila).toList());
  }

  @override
  Future<bool> existeCedula(String cedula, {int? excluirId}) async {
    var query = _db.select(_tabla)..where((t) => t.cedula.equals(cedula));

    if (excluirId != null) {
      query = query..where((t) => t.id.isNotValue(excluirId));
    }

    final resultado = await query.getSingleOrNull();
    return resultado != null;
  }

  Future<Tecnico?> _obtenerPorId(int id) async {
    final fila = await (_db.select(
      _tabla,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return fila != null ? TecnicoMapper.desdeFila(fila) : null;
  }

  @override
  Future<Tecnico> crear(Tecnico tecnico) async {
    final companion = TecnicoMapper.modeloACompanion(tecnico);
    final id = await _db.into(_tabla).insert(companion);
    return (await _obtenerPorId(id))!;
  }

  @override
  Future<Tecnico> actualizar(Tecnico tecnico) async {
    final companion = TecnicoMapper.modeloACompanion(tecnico);
    await (_db.update(
      _tabla,
    )..where((t) => t.id.equals(tecnico.id!))).write(companion);
    return (await _obtenerPorId(tecnico.id!))!;
  }

  @override
  Future<void> eliminar(int id) async {
    await (_db.delete(_tabla)..where((t) => t.id.equals(id))).go();
  }

  // Paginación — WHERE, COUNT y LIMIT los resuelve SQLite, no el frontend.

  /// Traduce [FiltroTecnicos] a una expresión SQL reutilizable por la
  /// consulta de la página y por la del total.
  Expression<bool> _condicion(FiltroTecnicos filtro) {
    final t = _tabla;
    Expression<bool> acumulado = const Constant(true);

    final texto = filtro.busqueda.trim();
    if (texto.isNotEmpty) {
      final patron = '%${texto.toLowerCase()}%';
      // Apellidos, cédula y teléfono son nullable: en esas filas el LIKE
      // devuelve NULL, no false. No hace falta `coalesce` porque en SQLite
      // `TRUE OR NULL` sigue siendo TRUE — basta con que otro campo coincida.
      acumulado = acumulado &
          (t.nombres.lower().like(patron) |
              t.apellidos.lower().like(patron) |
              t.cedula.lower().like(patron) |
              t.telefono.lower().like(patron));
    }

    final activo = filtro.activo;
    if (activo != null) {
      acumulado = acumulado & t.activo.equals(activo);
    }

    return acumulado;
  }

  @override
  Stream<PaginaTecnicos> observarPagina({
    required FiltroTecnicos filtro,
    required int pagina,
    required int tamano,
  }) {
    final condicion = _condicion(filtro);

    final consultaPagina = _db.select(_tabla)
      ..where((_) => condicion)
      ..orderBy([(t) => OrderingTerm.asc(t.nombres)])
      ..limit(tamano, offset: pagina * tamano);

    // El total va en su propia consulta: `limit` no debe afectarlo.
    final total = _tabla.id.count();
    final consultaTotal = _db.selectOnly(_tabla)
      ..addColumns([total])
      ..where(condicion);

    return consultaPagina.watch().asyncMap((filas) async {
      final fila = await consultaTotal.getSingleOrNull();
      return PaginaTecnicos(
        items: filas.map(TecnicoMapper.desdeFila).toList(),
        total: fila?.read(total) ?? 0,
      );
    });
  }

  @override
  Stream<({int total, int activos})> observarResumen() {
    final t = _tabla;
    final total = t.id.count();
    final activos = t.id.count(filter: t.activo.equals(true));

    final consulta = _db.selectOnly(t)..addColumns([total, activos]);

    return consulta.watchSingleOrNull().map(
          (fila) => (
            total: fila?.read(total) ?? 0,
            activos: fila?.read(activos) ?? 0,
          ),
        );
  }
}
