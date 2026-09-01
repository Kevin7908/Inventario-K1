import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../../../share/dominio/sesion_actual.dart';
import '../../bitacora/modelo/entrada_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora_impl.dart';
import '../../inventario/modelo/movimiento_inventario.dart';
import '../../inventario/repositorio/repositorio_inventario.dart';
import '../../inventario/repositorio/repositorio_inventario_impl.dart';
import '../../../share/consecutivos/repositorio_consecutivos.dart';
import '../../../share/utils/sku_utils.dart';
import '../mapper/producto_mapper.dart';
import '../modelo/producto.dart';
import 'repositorio_producto.dart';
import '../../../share/dominio/permiso.dart';

class RepositorioProductosImpl with FirmaDeSesion implements RepositorioProducto {
  RepositorioProductosImpl(this._db, this.sesion);

  final AppDb _db;

  /// Quién firma lo que este repositorio escribe. La inyecta Riverpod por el
  /// constructor, no la busca en ningún registro global.
  @override
  final SesionActual? sesion;

  /// Todo cambio de stock pasa por aquí. Ni este repositorio escribe
  /// `stock_actual` a mano.
  late final RepositorioInventario _inventario =
      RepositorioInventarioImpl(_db, sesion);

  late final RepositorioBitacora _bitacora =
      RepositorioBitacoraImpl(_db, sesion);

  /// Reparte los números del SKU. Es el mismo mecanismo de las facturas: un
  /// `UPSERT ... RETURNING` por serie, que no repite ni reutiliza el número de
  /// lo que se borró.
  late final RepositorioConsecutivos _consecutivos =
      RepositorioConsecutivos(_db);

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
          entidad: EntidadAuditada.producto,
          accion: accion,
          entidadId: id,
          descripcion: descripcion,
          detalle: detalle,
        ),
      );

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
      // La razón social del proveedor vive en `personas`.
      leftOuterJoin(
        _db.tablaPersona,
        _db.tablaPersona.id.equalsExp(_db.tablaProveedor.personaId),
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

  /// El prefijo que le corresponde a [categoriaId].
  ///
  /// Trae los nombres de las categorías porque el desempate necesita saber
  /// cuáles empiezan igual. Es un catálogo de decenas de filas y solo se
  /// consulta al dar de alta un producto, no en cada repintado.
  Future<String> _prefijoDe(int? categoriaId) async {
    if (categoriaId == null) return prefijoSinCategoria;

    final filas = await (_db.select(_db.tablaCategoria)
          ..orderBy([(c) => OrderingTerm.asc(c.id)]))
        .get();

    final anteriores = <String>[];
    for (final fila in filas) {
      if (fila.id == categoriaId) {
        return prefijoDeCategoria(fila.nombre, anteriores);
      }
      anteriores.add(fila.nombre);
    }

    // La categoría se borró entre que se eligió y se guardó.
    return prefijoSinCategoria;
  }

  @override
  Future<String> previsualizarSku(int? categoriaId) async {
    final prefijo = await _prefijoDe(categoriaId);
    final numero = await _consecutivos.proximoDeSerie(_serie(prefijo));
    return formatearSku(prefijo, numero);
  }

  /// La serie del consecutivo, una por prefijo.
  static String _serie(String prefijo) => 'SKU_$prefijo';

  /// Toma el siguiente número de la serie del prefijo. Se llama **dentro** de
  /// la transacción del alta.
  Future<String> _generarSku(int? categoriaId) async {
    final prefijo = await _prefijoDe(categoriaId);
    final numero = await _consecutivos.siguienteDeSerie(_serie(prefijo));
    return formatearSku(prefijo, numero);
  }

  @override
  Future<Producto> crear(Producto producto) {
    exigir(Permiso.productosCrear);
    // El producto nace con stock 0 y el inventario inicial entra como
    // movimiento, no como columna: si el alta pusiera `stock_actual` a mano,
    // el libro mayor arrancaría descuadrado desde la primera fila.
    return _db.transaction(() async {
      // El SKU se asigna aquí y no en la vista: es una regla de negocio, y
      // dentro de la transacción un alta que falle devuelve el número a la
      // serie en vez de dejar un hueco en la estantería.
      final conSku = producto.sku.trim().isEmpty
          ? producto.copyWith(sku: await _generarSku(producto.categoriaId))
          : producto;

      final id = await _db
          .into(_db.tablaProducto)
          .insert(ProductoMapper.modeloACompanion(conSku));

      if (producto.stockActual != 0) {
        await _inventario.registrar(
          SolicitudMovimiento(
            productoId: id,
            cantidad: producto.stockActual,
            tipo: TipoMovimiento.ajusteInicial,
            notas: 'Alta del producto',
          ),
        );
      }

      await _anotar(AccionAuditada.creo, id, _nombreDe(conSku));

      // No hay SELECT extra: el stream de Drift emite el dato completo.
      return conSku.copyWith(id: id);
    });
  }

  @override
  Future<Producto> actualizar(Producto producto) {
    exigir(Permiso.productosEditar);
    // `stock_actual` no viaja en el companion —el mapper lo excluye a
    // propósito, §7 de las reglas de base de datos—, así que editar el campo
    // en la ficha no escribía nada y el valor volvía al de antes en cuanto el
    // stream reemitía. La corrección no es escribir la columna: es registrar
    // el ajuste que explica la diferencia, en la misma transacción que el
    // resto de la edición.
    return _db.transaction(() async {
      final antes = await (_db.select(_db.tablaProducto)
            ..where((t) => t.id.equals(producto.id!)))
          .getSingleOrNull();

      await (_db.update(_db.tablaProducto)
            ..where((t) => t.id.equals(producto.id!)))
          .write(ProductoMapper.modeloACompanion(producto));

      final diferencia = producto.stockActual - (antes?.stockActual ?? 0);
      if (diferencia != 0) {
        await _inventario.registrar(
          SolicitudMovimiento(
            productoId: producto.id!,
            cantidad: diferencia,
            tipo: diferencia > 0
                ? TipoMovimiento.ajustePositivo
                : TipoMovimiento.ajusteNegativo,
            notas: 'Ajuste desde la ficha del producto',
          ),
        );
      }

      await _anotar(
        AccionAuditada.modifico,
        producto.id,
        _nombreDe(producto),
        detalle: diferencia == 0
            ? null
            : 'Stock ajustado en ${diferencia > 0 ? '+' : ''}$diferencia',
      );

      // No hay SELECT extra: el stream emite el resultado actualizado.
      return producto;
    });
  }

  @override
  Future<Producto> ajustarStock(int id, double cantidad) async {
    exigir(Permiso.productosStock);
    if (cantidad == 0) return (await obtenerPorId(id))!;

    // El movimiento ya lleva su `usuario_id`, pero el ajuste a mano también va
    // a la bitácora: es una decisión de una persona, no la consecuencia de una
    // venta, y es justo lo que alguien va a querer revisar.
    await _db.transaction(() async {
      await _inventario.registrar(
        SolicitudMovimiento(
          productoId: id,
          cantidad: cantidad,
          tipo: cantidad > 0
              ? TipoMovimiento.ajustePositivo
              : TipoMovimiento.ajusteNegativo,
          notas: 'Ajuste manual',
        ),
      );

      final producto = await obtenerPorId(id);
      await _anotar(
        AccionAuditada.modifico,
        id,
        producto == null ? 'Producto #$id' : _nombreDe(producto),
        detalle: 'Ajuste manual de stock: ${cantidad > 0 ? '+' : ''}$cantidad',
      );
    });

    return (await obtenerPorId(id))!;
  }

  @override
  Future<void> eliminar(int id) async {
    exigir(Permiso.productosEliminar);
    // Se lee **antes** de borrar: después no hay a quién preguntarle cómo se
    // llamaba, y un renglón que dice «eliminó el producto 47» no le sirve a
    // nadie.
    await _db.transaction(() async {
      final antes = await (_db.select(_db.tablaProducto)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();

      await (_db.delete(_db.tablaProducto)..where((t) => t.id.equals(id))).go();

      await _anotar(
        AccionAuditada.elimino,
        id,
        antes == null ? 'Producto #$id' : '${antes.nombre} (${antes.sku})',
      );
    });
  }

  /// Cómo se lee un producto en la bitácora: nombre y SKU, que es lo que
  /// permite reconocerlo cuando la fila ya no existe.
  static String _nombreDe(Producto producto) =>
      '${producto.nombre} (${producto.sku})';

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
      // El código de barras se compara **exacto y normalizado**, no con
      // `LIKE`: lo que llega ahí lo escribió un lector, no una persona, y
      // tiene que dar en el producto de una sola vez aunque el patrón traiga
      // los espacios que el lector inserta. Va en `OR` con lo demás para que
      // el mismo cuadro siga sirviendo para teclear un nombre.
      final codigo = normalizarCodigoBarras(texto);
      acumulado = acumulado &
          (p.nombre.lower().like(patron) |
              p.sku.lower().like(patron) |
              (codigo == null
                  ? const Constant(false)
                  : p.codigoBarras.equals(codigo)) |
              _db.tablaCategoria.nombre.lower().like(patron));
    }

    final categoria = filtro.categoriaId;
    if (categoria != null) {
      acumulado = acumulado & p.categoriaId.equals(categoria);
    }

    if (filtro.soloActivos) {
      acumulado = acumulado & p.activo.equals(true);
    }

    final marcaMoto = filtro.compatibleConMarcaId;
    if (marcaMoto != null) {
      acumulado = acumulado & _compatibleCon(marcaMoto, filtro.compatibleConModeloId);
    }

    return acumulado;
  }

  /// «Este producto le sirve a esta moto», como condición de la misma consulta.
  ///
  /// Es un `EXISTS` correlacionado y no un `WHERE id IN (…)` con los ids
  /// traídos desde Dart: el `IN` obligaría a resolver antes el conjunto entero
  /// de productos compatibles y a meterlo en la consulta, que es traer filas
  /// para descartarlas (`REGLAS_BD.md` §5) y además rompe con un catálogo
  /// grande.
  ///
  /// Las dos condiciones van en `OR` porque la compatibilidad tiene dos
  /// niveles: la línea de marca vale para toda la marca —el aceite de
  /// cualquier Yamaha— y la de modelo solo para ese —la pastilla de la FZ—.
  Expression<bool> _compatibleCon(int marcaId, int? modeloId) {
    final compat = _db.tablaProductoCompatibilidad;
    return existsQuery(
      _db.selectOnly(compat)
        ..addColumns([compat.id])
        ..where(
          compat.productoId.equalsExp(_db.tablaProducto.id) &
              (compat.marcaId.equals(marcaId) |
                  (modeloId == null
                      ? const Constant(false)
                      : compat.modeloId.equals(modeloId))),
        ),
    );
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
