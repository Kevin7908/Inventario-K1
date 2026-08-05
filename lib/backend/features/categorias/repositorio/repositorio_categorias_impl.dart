import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/features/categorias/modelo/categoria.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import '../mapper/categorias_mapper.dart';
import 'repositorio_categorias.dart';

// Implementación concreta usando Drift como fuente de datos
class RepositorioCategoriasImpl implements RepositorioCategorias {
  final AppDb _db;

  RepositorioCategoriasImpl(this._db);

  @override
  Stream<List<Categoria>> observarTodas() {
    return _db
        .select(_db.tablaCategoria)
        .watch()
        .map((filas) => filas.map(CategoriaMapper.filaAModelo).toList());
  }

  @override
  Future<Categoria?> obtenerPorId(int id) async {
    final fila = await (_db.select(
      _db.tablaCategoria,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    return fila != null ? CategoriaMapper.filaAModelo(fila) : null;
  }

  @override
  Future<List<Categoria>> buscarPorNombre(String consulta) async {
    final filas = await (_db.select(
      _db.tablaCategoria,
    )..where((t) => t.nombre.like('%$consulta%'))).get();
    return filas.map(CategoriaMapper.filaAModelo).toList();
  }

  @override
  Future<Categoria> crear(Categoria categoria) async {
    final companion = CategoriaMapper.modeloACompanion(categoria);
    final id = await _db.into(_db.tablaCategoria).insert(companion);
    final creada = await obtenerPorId(id);
    return creada!;
  }

  @override
  Future<Categoria> actualizar(Categoria categoria) async {
    final companion = CategoriaMapper.modeloACompanion(categoria);
    await (_db.update(
      _db.tablaCategoria,
    )..where((t) => t.id.equals(categoria.id!))).write(companion);
    final actualizada = await obtenerPorId(categoria.id!);
    return actualizada!;
  }

  @override
  Future<void> eliminar(int id) async {
    await (_db.delete(_db.tablaCategoria)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<bool> existeNombre(String nombre, {int? excludirId}) async {
    final query = _db.select(_db.tablaCategoria)
      ..where((t) => t.nombre.lower().equals(nombre.toLowerCase()));
    if (excludirId != null) {
      query.where((t) => t.id.equals(excludirId).not());
    }
    final resultado = await query.getSingleOrNull();
    return resultado != null;
  }

  @override
  Stream<PaginaCategorias> observarPagina({
    String busqueda = '',
    required int pagina,
    required int tamano,
  }) {
    final t = _db.tablaCategoria;
    final texto = busqueda.trim().toLowerCase();

    Expression<bool> condicion(dynamic tabla) => texto.isEmpty
        ? const Constant(true)
        : t.nombre.lower().like('%$texto%');

    final consultaPagina = _db.select(t)
      ..where(condicion)
      ..orderBy([(f) => OrderingTerm.asc(f.nombre)])
      ..limit(tamano, offset: pagina * tamano);

    // El total va en su propia consulta: `limit` no debe recortarlo.
    final cantidad = t.id.count();
    final consultaTotal = _db.selectOnly(t)
      ..addColumns([cantidad])
      ..where(condicion(t));

    return consultaPagina.watch().asyncMap((filas) async {
      final fila = await consultaTotal.getSingleOrNull();
      return PaginaCategorias(
        items: filas.map(CategoriaMapper.filaAModelo).toList(),
        total: fila?.read(cantidad) ?? 0,
      );
    });
  }
}
