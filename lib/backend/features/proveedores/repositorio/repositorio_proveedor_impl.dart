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

  // Paginación — WHERE, COUNT y LIMIT los resuelve SQLite, no el frontend.

  /// Traduce [FiltroProveedores] a una expresión SQL reutilizable por la
  /// consulta de la página y por la del total.
  Expression<bool> _condicion(FiltroProveedores filtro) {
    final p = _db.tablaProveedor;
    Expression<bool> acumulado = const Constant(true);

    final texto = filtro.busqueda.trim();
    if (texto.isNotEmpty) {
      final patron = '%${texto.toLowerCase()}%';
      // NIT, ciudad y contacto son nullable: en esas filas el LIKE devuelve
      // NULL, no false. No hace falta `coalesce` porque en SQLite
      // `TRUE OR NULL` sigue siendo TRUE — basta con que otro campo coincida.
      acumulado = acumulado &
          (p.nombre.lower().like(patron) |
              p.nitCedula.lower().like(patron) |
              p.ciudad.lower().like(patron) |
              p.contacto.lower().like(patron));
    }

    final activo = filtro.activo;
    if (activo != null) {
      acumulado = acumulado & p.activo.equals(activo);
    }

    return acumulado;
  }

  @override
  Stream<PaginaProveedores> observarPagina({
    required FiltroProveedores filtro,
    required int pagina,
    required int tamano,
  }) {
    final condicion = _condicion(filtro);

    final consultaPagina = _db.select(_db.tablaProveedor)
      ..where((_) => condicion)
      ..orderBy([(t) => OrderingTerm.asc(t.nombre)])
      ..limit(tamano, offset: pagina * tamano);

    // El total va en su propia consulta: `limit` no debe afectarlo.
    final total = _db.tablaProveedor.id.count();
    final consultaTotal = _db.selectOnly(_db.tablaProveedor)
      ..addColumns([total])
      ..where(condicion);

    return consultaPagina.watch().asyncMap((filas) async {
      final fila = await consultaTotal.getSingleOrNull();
      return PaginaProveedores(
        items: filas.map(ProveedorMapper.filaAModelo).toList(),
        total: fila?.read(total) ?? 0,
      );
    });
  }

  @override
  Stream<({int total, int activos})> observarResumen() {
    final p = _db.tablaProveedor;
    final total = p.id.count();
    final activos = p.id.count(filter: p.activo.equals(true));

    final consulta = _db.selectOnly(p)..addColumns([total, activos]);

    return consulta.watchSingleOrNull().map(
          (fila) => (
            total: fila?.read(total) ?? 0,
            activos: fila?.read(activos) ?? 0,
          ),
        );
  }
}
