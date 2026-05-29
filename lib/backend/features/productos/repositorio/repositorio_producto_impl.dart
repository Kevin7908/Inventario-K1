import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../mapper/producto_mapper.dart';
import '../modelo/producto.dart';
import 'repositorio_producto.dart';

class RepositorioProductosImpl implements RepositorioProducto {
  final AppDb _db;

  RepositorioProductosImpl(this._db);

  // Helper: JOIN base

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

  List<Producto> _mapear(List<TypedResult> filas) =>
      filas.map((r) => ProductoMapper.filaJoinAModelo(r, _db)).toList();

  // Streams reactivos

  @override
  Stream<List<Producto>> observarTodos() =>
      _queryConJoin().watch().map(_mapear);

  @override
  Stream<List<Producto>> observarConStockBajo() =>
      (_queryConJoin()
            ..where(_db.tablaProducto.stockActual
                .isSmallerOrEqual(_db.tablaProducto.stockMinimo)))
          .watch()
          .map(_mapear);

  // Consultas únicas

  @override
  Future<List<Producto>> obtenerTodos() async =>
      _mapear(await _queryConJoin().get());

  @override
  Future<Producto?> obtenerPorId(int id) async {
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
    return _mapear(
      await (_queryConJoin()
            ..where(_db.tablaProducto.nombre.like(termino) |
                _db.tablaProducto.sku.like(termino)))
          .get(),
    );
  }

  @override
  Future<List<Producto>> obtenerPorCategoria(int categoriaId) async =>
      _mapear(
        await (_queryConJoin()
              ..where(_db.tablaProducto.categoriaId.equals(categoriaId)))
            .get(),
      );

  @override
  Future<List<Producto>> obtenerPorProveedor(int proveedorId) async =>
      _mapear(
        await (_queryConJoin()
              ..where(_db.tablaProducto.proveedorId.equals(proveedorId)))
            .get(),
      );

  @override
  Future<List<Producto>> obtenerActivos() async =>
      _mapear(
        await (_queryConJoin()
              ..where(_db.tablaProducto.activo.equals(true)))
            .get(),
      );

  @override
  Future<List<Producto>> obtenerConStockBajo() async =>
      _mapear(
        await (_queryConJoin()
              ..where(_db.tablaProducto.stockActual
                  .isSmallerOrEqual(_db.tablaProducto.stockMinimo)))
            .get(),
      );

  // Escrituras

  @override
  Future<Producto> crear(Producto producto) async {
    final companion = ProductoMapper.modeloACompanion(producto);
    final id = await _db.into(_db.tablaProducto).insert(companion);
    // No hay SELECT extra: el stream de Drift emite el dato completo.
    return producto.copyWith(id: id);
  }

  @override
  Future<Producto> actualizar(Producto producto) async {
    final companion = ProductoMapper.modeloACompanion(producto);
    await (_db.update(_db.tablaProducto)
          ..where((t) => t.id.equals(producto.id!)))
        .write(companion);
    // No hay SELECT extra: el stream emite el resultado actualizado.
    return producto;
  }

  @override
  Future<Producto> ajustarStock(int id, double cantidad) async {
    // Un solo UPDATE atómico en vez del ciclo read→modify→write.
    await _db.customUpdate(
      'UPDATE productos SET stock_actual = stock_actual + ?, '
      'actualizado_en = ? WHERE id = ?',
      variables: [
        Variable.withReal(cantidad),
        Variable.withDateTime(DateTime.now()),
        Variable.withInt(id),
      ],
      updates: {_db.tablaProducto},
    );
    final actualizado = await obtenerPorId(id);
    return actualizado!;
  }

  @override
  Future<void> eliminar(int id) async {
    await (_db.delete(_db.tablaProducto)..where((t) => t.id.equals(id))).go();
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

  // Conteos — COUNT(*) real, no fetch-all

  @override
  Future<int> contarActivos() async {
    final expr = _db.tablaProducto.id.count();
    final query = _db.selectOnly(_db.tablaProducto)
      ..where(_db.tablaProducto.activo.equals(true))
      ..addColumns([expr]);
    final result = await query.getSingle();
    return result.read(expr) ?? 0;
  }

  @override
  Future<int> contarConStockBajo() async {
    final expr = _db.tablaProducto.id.count();
    final query = _db.selectOnly(_db.tablaProducto)
      ..where(_db.tablaProducto.stockActual
          .isSmallerOrEqual(_db.tablaProducto.stockMinimo))
      ..addColumns([expr]);
    final result = await query.getSingle();
    return result.read(expr) ?? 0;
  }
}
