import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/features/categorias/modelo/categoria.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import '../mapper/categorias_mapper.dart';
import 'repositorio_categorias.dart';
import '../../../share/dominio/sesion_actual.dart';
import '../../bitacora/modelo/entrada_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora_impl.dart';
import '../../../share/dominio/permiso.dart';

// Implementación concreta usando Drift como fuente de datos
class RepositorioCategoriasImpl with FirmaDeSesion implements RepositorioCategorias {
  final AppDb _db;

  RepositorioCategoriasImpl(this._db, this.sesion);

  /// Quién firma lo que este repositorio escribe. La inyecta Riverpod por el
  /// constructor, no la busca en ningún registro global.
  @override
  final SesionActual? sesion;

  late final RepositorioBitacora _bitacora =
      RepositorioBitacoraImpl(_db, sesion);

  /// Deja el renglón de la bitácora. Se llama **dentro** de la transacción del
  /// cambio: si la escritura se revierte, el renglón se va con ella.
  Future<void> _anotar(
    AccionAuditada accion,
    int? id,
    String descripcion, {
    String? detalle,
  }) =>
      _bitacora.anotar(
        Anotacion(
          entidad: EntidadAuditada.categoria,
          accion: accion,
          entidadId: id,
          descripcion: descripcion,
          detalle: detalle,
        ),
      );


  @override
  Stream<List<Categoria>> observarTodas() {
    exigir(Permiso.categoriasVer);
    return _db
        .select(_db.tablaCategoria)
        .watch()
        .map((filas) => filas.map(CategoriaMapper.filaAModelo).toList());
  }

  @override
  Future<Categoria?> obtenerPorId(int id) async {
    exigir(Permiso.categoriasVer);
    final fila = await (_db.select(
      _db.tablaCategoria,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    return fila != null ? CategoriaMapper.filaAModelo(fila) : null;
  }

  @override
  Future<List<Categoria>> buscarPorNombre(String consulta) async {
    exigir(Permiso.categoriasVer);
    final filas = await (_db.select(
      _db.tablaCategoria,
    )..where((t) => t.nombre.like('%$consulta%'))).get();
    return filas.map(CategoriaMapper.filaAModelo).toList();
  }

  @override
  Future<Categoria> crear(Categoria categoria) {
    exigir(Permiso.categoriasEditar);
    // Alta y renglón de bitácora entran juntos o no entra ninguno.
    return _db.transaction(() async {
      final companion = CategoriaMapper.modeloACompanion(categoria);
      final id = await _db.into(_db.tablaCategoria).insert(companion);
      await _anotar(AccionAuditada.creo, id, categoria.nombre);
      return (await obtenerPorId(id))!;
    });
  }

  @override
  Future<Categoria> actualizar(Categoria categoria) {
    exigir(Permiso.categoriasEditar);
    return _db.transaction(() async {
      final companion = CategoriaMapper.modeloACompanion(categoria);
      await (_db.update(
        _db.tablaCategoria,
      )..where((t) => t.id.equals(categoria.id!))).write(companion);
      await _anotar(AccionAuditada.modifico, categoria.id, categoria.nombre);
      return (await obtenerPorId(categoria.id!))!;
    });
  }

  @override
  Future<void> eliminar(int id) {
    exigir(Permiso.categoriasEliminar);
    // El nombre se lee **antes** de borrar: después no queda a quién
    // preguntárselo, y «eliminó la categoría 7» no le sirve a nadie.
    return _db.transaction(() async {
      final antes = await obtenerPorId(id);
      await (_db.delete(_db.tablaCategoria)..where((t) => t.id.equals(id))).go();
      await _anotar(
        AccionAuditada.elimino,
        id,
        antes?.nombre ?? 'Categoría #$id',
      );
    });
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
    exigir(Permiso.categoriasVer);
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
