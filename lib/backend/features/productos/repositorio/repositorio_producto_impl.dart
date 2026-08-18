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

  // Paginación — WHERE, COUNT y LIMIT los resuelve SQLite, no el frontend.

  /// Parte del filtro que **no** mira el stock: búsqueda y categoría.
  ///
  /// Va aparte porque `observarResumen` necesita contar los tres tramos de
  /// stock dentro del mismo ámbito que la tabla está mostrando; si aplicara
  /// también el tramo activo, cada chip contaría solo sus propias filas.
  Expression<bool> _condicionAmbito(FiltroProductos filtro) {
    final p = _db.tablaProducto;
    Expression<bool> acumulado = const Constant(true);

    final texto = filtro.busqueda.trim();
    if (texto.isNotEmpty) {
      final patron = '%${texto.toLowerCase()}%';
      acumulado = acumulado &
          (p.nombre.lower().like(patron) |
              p.sku.lower().like(patron) |
              _db.tablaCategoria.nombre.lower().like(patron));
    }

    final categoria = filtro.categoriaId;
    if (categoria != null) {
      acumulado = acumulado & p.categoriaId.equals(categoria);
    }

    if (filtro.soloActivos) {
      acumulado = acumulado & p.activo.equals(true);
    }

    return acumulado;
  }

  /// Traduce [FiltroProductos] a una expresión SQL reutilizable por la
  /// consulta de la página y por la del total.
  Expression<bool> _condicion(FiltroProductos filtro) {
    final p = _db.tablaProducto;
    var acumulado = _condicionAmbito(filtro);

    if (filtro.soloSinStock) {
      acumulado = acumulado & p.stockActual.isSmallerOrEqualValue(0);
    } else if (filtro.soloStockBajo) {
      acumulado = acumulado &
          p.stockActual.isBiggerThanValue(0) &
          p.stockActual.isSmallerOrEqual(p.stockMinimo);
    } else if (filtro.soloEnStock) {
      acumulado = acumulado & p.stockActual.isBiggerThan(p.stockMinimo);
    }

    return acumulado;
  }

  @override
  Stream<PaginaProductos> observarPagina({
    required FiltroProductos filtro,
    required int pagina,
    required int tamano,
  }) {
    final condicion = _condicion(filtro);

    final consultaPagina = _queryConJoin()
      ..where(condicion)
      ..orderBy([OrderingTerm.asc(_db.tablaProducto.nombre)])
      ..limit(tamano, offset: pagina * tamano);

    // El total va en su propia consulta: `limit` no debe afectarlo.
    final total = _db.tablaProducto.id.count();
    final consultaTotal = _db.select(_db.tablaProducto).join([
      leftOuterJoin(
        _db.tablaCategoria,
        _db.tablaCategoria.id.equalsExp(_db.tablaProducto.categoriaId),
      ),
    ])
      ..addColumns([total])
      ..where(condicion);

    return consultaPagina.watch().asyncMap((filas) async {
      final fila = await consultaTotal.getSingleOrNull();
      return PaginaProductos(
        items: _mapear(filas),
        total: fila?.read(total) ?? 0,
      );
    });
  }

  @override
  Stream<Map<int, int>> observarConteoPorCategoria() {
    final cantidad = _db.tablaProducto.id.count();
    final consulta = _db.selectOnly(_db.tablaProducto)
      ..addColumns([_db.tablaProducto.categoriaId, cantidad])
      ..where(_db.tablaProducto.categoriaId.isNotNull())
      ..groupBy([_db.tablaProducto.categoriaId]);

    return consulta.watch().map((filas) {
      final conteo = <int, int>{};
      for (final fila in filas) {
        final id = fila.read(_db.tablaProducto.categoriaId);
        if (id != null) conteo[id] = fila.read(cantidad) ?? 0;
      }
      return conteo;
    });
  }

  @override
  Stream<Map<int, int>> observarConteoPorProveedor() {
    final cantidad = _db.tablaProducto.id.count();
    final consulta = _db.selectOnly(_db.tablaProducto)
      ..addColumns([_db.tablaProducto.proveedorId, cantidad])
      ..where(_db.tablaProducto.proveedorId.isNotNull())
      ..groupBy([_db.tablaProducto.proveedorId]);

    return consulta.watch().map((filas) {
      final conteo = <int, int>{};
      for (final fila in filas) {
        final id = fila.read(_db.tablaProducto.proveedorId);
        if (id != null) conteo[id] = fila.read(cantidad) ?? 0;
      }
      return conteo;
    });
  }

  @override
  Stream<({int total, int enStock, int stockBajo, int sinStock})>
      observarResumen({FiltroProductos filtro = const FiltroProductos()}) {
    final p = _db.tablaProducto;
    final total = p.id.count();

    // Los mismos tres tramos que `_condicion`, para que el número del chip
    // coincida siempre con las filas que ese chip termina mostrando.
    final enStock = p.id.count(
      filter: p.stockActual.isBiggerThan(p.stockMinimo),
    );
    final bajos = p.id.count(
      filter: p.stockActual.isBiggerThanValue(0) &
          p.stockActual.isSmallerOrEqual(p.stockMinimo),
    );
    final agotados = p.id.count(
      filter: p.stockActual.isSmallerOrEqualValue(0),
    );

    // El join con categorías es el mismo de `observarPagina`: la búsqueda del
    // ámbito también mira el nombre de la categoría.
    final consulta = _db.selectOnly(p).join([
      leftOuterJoin(
        _db.tablaCategoria,
        _db.tablaCategoria.id.equalsExp(p.categoriaId),
      ),
    ])
      ..addColumns([total, enStock, bajos, agotados])
      ..where(_condicionAmbito(filtro));

    return consulta.watchSingleOrNull().map(
          (fila) => (
            total: fila?.read(total) ?? 0,
            enStock: fila?.read(enStock) ?? 0,
            stockBajo: fila?.read(bajos) ?? 0,
            sinStock: fila?.read(agotados) ?? 0,
          ),
        );
  }
}
