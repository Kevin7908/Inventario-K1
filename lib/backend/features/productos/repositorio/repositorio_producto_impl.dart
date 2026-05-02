import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/features/productos/repositorio/repositorio_producto.dart';

import '../../../share/database/app_db.dart';
import '../mapper/producto_mapper.dart';
import '../modelo/producto.dart';

class RepositorioProductosImpl implements RepositorioProducto {
  final AppDb _db;

  RepositorioProductosImpl(this._db);

  // Helper: construye el JOIN base 
  // Centraliza los tres leftOuterJoin para no repetirlos en cada método.
  // Devuelve un JoinedSelectStatement listo para añadir .where() o .watch().
  JoinedSelectStatement<HasResultSet, dynamic> _queryConJoin() {
    return _db.select(_db.tablaProducto).join([
      leftOuterJoin(
        _db.tablaCategoria,
        _db.tablaCategoria.id.equalsExp(_db.tablaProducto.categoriaId),
      ),
      leftOuterJoin(
        _db.tablaProveedor,
        _db.tablaProveedor.id.equalsExp(_db.tablaProducto.proveedorId),
      ),
      leftOuterJoin(
        _db.tablaUnidadesMedida,
        _db.tablaUnidadesMedida.id.equalsExp(_db.tablaProducto.unidadMedidaId),
      ),
    ]);
  }

  // Conversión de lista de TypedResult → List<Producto> 
  List<Producto> _mapearResultados(List<TypedResult> filas) {
    return filas
        .map((r) => ProductoMapper.filaJoinAModelo(r, _db))
        .toList();
  }

  // Streams reactivos 

  @override
  Stream<List<Producto>> observarTodos() {
    return _queryConJoin()
        .watch()
        .map(_mapearResultados);
  }

  @override
  Stream<List<Producto>> observarConStockBajo() {
    return (_queryConJoin()
          ..where(
            _db.tablaProducto.stockActual
                .isSmallerOrEqual(_db.tablaProducto.stockMinimo),
          ))
        .watch()
        .map(_mapearResultados);
  }

  // Consultas únicas 

  @override
  Future<List<Producto>> obtenerTodos() async {
    final filas = await _queryConJoin().get();
    return _mapearResultados(filas);
  }

  @override
  Future<Producto?> obtenerPorId(int id) async {
    // Lectura simple — no necesita JOIN porque el resultado se usa
    // internamente (tras crear/actualizar) y la UI ya tiene los nombres.
    final fila = await (_db.select(_db.tablaProducto)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return fila != null ? ProductoMapper.filaAModelo(fila) : null;
  }

  @override
  Future<Producto?> obtenerPorSku(String sku) async {
    final fila = await (_db.select(_db.tablaProducto)
          ..where((t) => t.sku.equals(sku)))
        .getSingleOrNull();
    return fila != null ? ProductoMapper.filaAModelo(fila) : null;
  }

  @override
  Future<List<Producto>> buscarPorNombreOSku(String consulta) async {
    final termino = '%$consulta%';
    final filas = await (_queryConJoin()
          ..where(
            _db.tablaProducto.nombre.like(termino) |
                _db.tablaProducto.sku.like(termino),
          ))
        .get();
    return _mapearResultados(filas);
  }

  @override
  Future<List<Producto>> obtenerPorCategoria(int categoriaId) async {
    final filas = await (_queryConJoin()
          ..where(_db.tablaProducto.categoriaId.equals(categoriaId)))
        .get();
    return _mapearResultados(filas);
  }

  @override
  Future<List<Producto>> obtenerPorProveedor(int proveedorId) async {
    final filas = await (_queryConJoin()
          ..where(_db.tablaProducto.proveedorId.equals(proveedorId)))
        .get();
    return _mapearResultados(filas);
  }

  @override
  Future<List<Producto>> obtenerActivos() async {
    final filas = await (_queryConJoin()
          ..where(_db.tablaProducto.activo.equals(true)))
        .get();
    return _mapearResultados(filas);
  }

  @override
  Future<List<Producto>> obtenerConStockBajo() async {
    final filas = await (_queryConJoin()
          ..where(
            _db.tablaProducto.stockActual
                .isSmallerOrEqual(_db.tablaProducto.stockMinimo),
          ))
        .get();
    return _mapearResultados(filas);
  }

  @override
  Future<Producto> crear(Producto producto) async {
    final companion = ProductoMapper.modeloACompanion(producto);
    final id = await _db.into(_db.tablaProducto).insert(companion);
    final creado = await obtenerPorId(id);
    return creado!;
  }

  @override
  Future<Producto> actualizar(Producto producto) async {
    final companion = ProductoMapper.modeloACompanion(producto);
    await (_db.update(_db.tablaProducto)
          ..where((t) => t.id.equals(producto.id!)))
        .write(companion);
    final actualizado = await obtenerPorId(producto.id!);
    return actualizado!;
  }

  @override
  Future<Producto> ajustarStock(int id, double cantidad) async {
    final producto = await obtenerPorId(id);
    if (producto == null) {
      throw Exception('Producto con id $id no encontrado');
    }
    final actualizado = producto.copyWith(
      stockActual: producto.stockActual + cantidad,
      actualizadoEn: DateTime.now(),
    );
    return actualizar(actualizado);
  }

  @override
  Future<void> eliminar(int id) async {
    await (_db.delete(_db.tablaProducto)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  // Validaciones 

  @override
  Future<bool> existeNombre(String nombre, {int? excludirId}) async {
    final query = _db.select(_db.tablaProducto)
      ..where((t) => t.nombre.lower().equals(nombre.toLowerCase()));
    if (excludirId != null) {
      query.where((t) => t.id.equals(excludirId).not());
    }
    return await query.getSingleOrNull() != null;
  }

  @override
  Future<bool> existeSku(String sku, {int? excludirId}) async {
    final query = _db.select(_db.tablaProducto)
      ..where((t) => t.sku.equals(sku));
    if (excludirId != null) {
      query.where((t) => t.id.equals(excludirId).not());
    }
    return await query.getSingleOrNull() != null;
  }

  // Conteos 

  @override
  Future<int> contarActivos() async {
    final filas = await (_db.select(_db.tablaProducto)
          ..where((t) => t.activo.equals(true)))
        .get();
    return filas.length;
  }

  @override
  Future<int> contarConStockBajo() async {
    final filas = await (_db.select(_db.tablaProducto)
          ..where(
            (t) => t.stockActual.isSmallerOrEqual(t.stockMinimo),
          ))
        .get();
    return filas.length;
  }
}