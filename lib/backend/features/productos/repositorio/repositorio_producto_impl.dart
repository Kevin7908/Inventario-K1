import 'package:drift/drift.dart';

import '../../../../core/formato.dart';
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
import '../../../share/utils/texto_utils.dart';
import '../mapper/producto_mapper.dart';
import '../../../../core/resultado.dart';
import '../modelo/producto.dart';
import '../modelo/proveedor_de_producto.dart';
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

  /// El proveedor **principal**, que es lo que la rejilla y la ficha enseñan.
  ///
  /// Va por `producto_proveedores` y no por una columna de `productos`: un
  /// repuesto se le compra a varios y la marca de principal vive con la
  /// relación. El filtro `esPrincipal` va en la condición del JOIN y no en un
  /// `WHERE`, porque en un `WHERE` convertiría el `LEFT` en `INNER` y dejaría
  /// fuera los productos sin proveedor asignado.
  JoinedSelectStatement<HasResultSet, dynamic> _queryConJoin() {
    return _db.select(_db.tablaProducto).join([
      leftOuterJoin(
        _db.tablaCategoria,
        _db.tablaCategoria.id.equalsExp(_db.tablaProducto.categoriaId),
      ),
      leftOuterJoin(
        _db.tablaProductoProveedor,
        _db.tablaProductoProveedor.productoId.equalsExp(_db.tablaProducto.id) &
            _db.tablaProductoProveedor.esPrincipal.equals(true),
      ),
      leftOuterJoin(
        _db.tablaProveedor,
        _db.tablaProveedor.id
            .equalsExp(_db.tablaProductoProveedor.proveedorId),
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
  Stream<List<Producto>> observarTodos() {
    exigir(Permiso.productosVer);
    return _queryConJoin().watch().map(_mapear);
  }

  @override
  Stream<List<Producto>> observarConStockBajo() {
    exigir(Permiso.productosVer);
    return (_queryConJoin()
          ..where(_db.tablaProducto.stockActual
              .isSmallerOrEqual(_db.tablaProducto.stockMinimo)))
        .watch()
        .map(_mapear);
  }

  // Consultas únicas

  @override
  Future<List<Producto>> obtenerTodos() async {
    exigir(Permiso.productosVer);
    return _mapear(await _queryConJoin().get());
  }

  @override
  /// Va por el JOIN y no por la fila pelada: desde que el proveedor vive en
  /// `producto_proveedores`, leer solo `productos` devuelve un modelo sin
  /// proveedor —y sin categoría ni unidad—, y quien pide un producto por id lo
  /// pide para enseñarlo.
  @override
  Future<Producto?> obtenerPorId(int id) async {
    exigir(Permiso.productosVer);
    final filas =
        await (_queryConJoin()..where(_db.tablaProducto.id.equals(id))).get();
    return filas.isEmpty
        ? null
        : ProductoMapper.filaJoinAModelo(filas.first, _db);
  }

  @override
  Future<Producto?> obtenerPorSku(String sku) async {
    exigir(Permiso.productosVer);
    final filas = await (_queryConJoin()
          ..where(_db.tablaProducto.sku.equals(sku)))
        .get();
    return filas.isEmpty
        ? null
        : ProductoMapper.filaJoinAModelo(filas.first, _db);
  }

  @override
  Future<List<Producto>> buscarPorNombreOSku(String consulta) async {
    exigir(Permiso.productosVer);
    final termino = '%$consulta%';
    return _mapear(
      await (_queryConJoin()
            ..where(_db.tablaProducto.nombre.like(termino) |
                _db.tablaProducto.sku.like(termino)))
          .get(),
    );
  }

  @override
  Future<List<Producto>> obtenerPorCategoria(int categoriaId) async {
    exigir(Permiso.productosVer);
    return _mapear(
      await (_queryConJoin()
            ..where(_db.tablaProducto.categoriaId.equals(categoriaId)))
          .get(),
    );
  }

  /// Todo lo que ese proveedor le vende al taller, sea principal o no.
  ///
  /// El `WHERE` no puede ir sobre el JOIN del principal —ese trae solo la
  /// fila marcada—, así que se resuelve con un `IN` sobre la tabla de
  /// vínculos: un producto sale si ese proveedor está entre los suyos.
  @override
  Future<List<Producto>> obtenerPorProveedor(int proveedorId) async {
    exigir(Permiso.productosVer);
    final vinculados = _db.selectOnly(_db.tablaProductoProveedor)
      ..addColumns([_db.tablaProductoProveedor.productoId])
      ..where(_db.tablaProductoProveedor.proveedorId.equals(proveedorId));

    return _mapear(
      await (_queryConJoin()
            ..where(_db.tablaProducto.id.isInQuery(vinculados)))
          .get(),
    );
  }

  @override
  Future<List<Producto>> obtenerActivos() async {
    exigir(Permiso.productosVer);
    return _mapear(
      await (_queryConJoin()
            ..where(_db.tablaProducto.activo.equals(true)))
          .get(),
    );
  }

  @override
  Future<List<Producto>> obtenerConStockBajo() async {
    exigir(Permiso.productosVer);
    return _mapear(
      await (_queryConJoin()
            ..where(_db.tablaProducto.stockActual
                .isSmallerOrEqual(_db.tablaProducto.stockMinimo)))
          .get(),
    );
  }

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

      // El proveedor del formulario es el **principal**, y ya no es una
      // columna de `productos`: se escribe como vínculo, en esta misma
      // transacción, para que un alta fallida no deje la relación suelta.
      await _sincronizarPrincipal(id, producto.proveedorId);

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

      await _sincronizarPrincipal(producto.id!, producto.proveedorId);

      await _anotar(
        AccionAuditada.modifico,
        producto.id,
        _nombreDe(producto),
        detalle: _queCambio(antes, producto, diferencia),
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

  // Proveedores del producto

  $TablaProductoProveedorTable get _vinculos => _db.tablaProductoProveedor;

  /// Deja como principal al proveedor que trae el formulario.
  ///
  /// Es lo que traduce el único selector del formulario a la tabla de
  /// vínculos: si el proveedor todavía no estaba entre los del repuesto, se
  /// agrega; si venía en `null`, el producto se queda sin principal y **los
  /// demás vínculos no se tocan**, que es lo que distingue «no tiene
  /// preferido» de «no le compro a nadie».
  ///
  /// Va sin `exigir`: lo llaman `crear` y `actualizar`, que ya comprobaron su
  /// permiso, y dentro de su misma transacción.
  Future<void> _sincronizarPrincipal(int productoId, int? proveedorId) async {
    await _apagarPrincipal(productoId);
    if (proveedorId == null) return;

    final existente = await (_db.select(_vinculos)
          ..where((t) =>
              t.productoId.equals(productoId) &
              t.proveedorId.equals(proveedorId)))
        .getSingleOrNull();

    if (existente == null) {
      await _db.into(_vinculos).insert(
            TablaProductoProveedorCompanion.insert(
              productoId: productoId,
              proveedorId: proveedorId,
              esPrincipal: const Value(true),
            ),
          );
      return;
    }

    await (_db.update(_vinculos)..where((t) => t.id.equals(existente.id)))
        .write(
      TablaProductoProveedorCompanion(
        esPrincipal: const Value(true),
        actualizadoEn: Value(DateTime.now()),
      ),
    );
  }

  @override
  Stream<List<ProveedorDeProducto>> observarProveedoresDe(int productoId) {
    exigir(Permiso.productosVer);

    // La razón social del proveedor vive en `personas`, no en `proveedores`:
    // hacen falta los dos JOIN encadenados, como en el resto del proyecto.
    final consulta = _db.select(_vinculos).join([
      innerJoin(
        _db.tablaProveedor,
        _db.tablaProveedor.id.equalsExp(_vinculos.proveedorId),
      ),
      innerJoin(
        _db.tablaPersona,
        _db.tablaPersona.id.equalsExp(_db.tablaProveedor.personaId),
      ),
    ])
      ..where(_vinculos.productoId.equals(productoId))
      // El principal primero —es el que se propone al pedir— y el resto por
      // nombre. `desc` sobre un booleano pone el `true` arriba.
      ..orderBy([
        OrderingTerm.desc(_vinculos.esPrincipal),
        OrderingTerm.asc(_db.tablaPersona.nombres),
      ]);

    return consulta.watch().map(
          (filas) => filas.map((fila) {
            final vinculo = fila.readTable(_vinculos);
            final persona = fila.readTable(_db.tablaPersona);
            return ProveedorDeProducto(
              id: vinculo.id,
              productoId: vinculo.productoId,
              proveedorId: vinculo.proveedorId,
              proveedorNombre: persona.nombres,
              proveedorTelefono: persona.telefono,
              referenciaProveedor: vinculo.referenciaProveedor,
              ultimoCosto: vinculo.ultimoCosto,
              fechaUltimaCompra: vinculo.fechaUltimaCompra,
              esPrincipal: vinculo.esPrincipal,
            );
          }).toList(),
        );
  }

  @override
  Future<Resultado> vincularProveedor({
    required int productoId,
    required int proveedorId,
    String? referenciaProveedor,
    bool esPrincipal = false,
  }) async {
    exigir(Permiso.productosEditar);

    return _db.transaction(() async {
      final proveedor = await (_db.select(_db.tablaProveedor)
            ..where((t) => t.id.equals(proveedorId)))
          .getSingleOrNull();
      if (proveedor == null) {
        return const Fallo(
          MotivoFallo.validacion,
          'Ese proveedor ya no está en el catálogo.',
        );
      }

      // Se apaga el anterior **antes** de encender el nuevo: la guarda de la
      // base rechaza dos principales a la vez, así que el orden no es un
      // detalle de estilo.
      if (esPrincipal) await _apagarPrincipal(productoId);

      final existente = await (_db.select(_vinculos)
            ..where((t) =>
                t.productoId.equals(productoId) &
                t.proveedorId.equals(proveedorId)))
          .getSingleOrNull();

      if (existente == null) {
        await _db.into(_vinculos).insert(
              TablaProductoProveedorCompanion.insert(
                productoId: productoId,
                proveedorId: proveedorId,
                referenciaProveedor: Value(referenciaProveedor),
                esPrincipal: Value(esPrincipal),
              ),
            );
      } else {
        await (_db.update(_vinculos)..where((t) => t.id.equals(existente.id)))
            .write(
          TablaProductoProveedorCompanion(
            // La referencia solo se pisa si llega una: volver a marcar
            // principal desde la ficha no puede borrar el código que alguien
            // tecleó.
            referenciaProveedor: referenciaProveedor == null
                ? const Value.absent()
                : Value(referenciaProveedor),
            esPrincipal: Value(esPrincipal || existente.esPrincipal),
            actualizadoEn: Value(DateTime.now()),
          ),
        );
      }

      await _anotarProveedor(
        productoId,
        'Proveedor vinculado: ${await _nombreProveedor(proveedorId)}',
      );
      return const Exito();
    });
  }

  @override
  Future<Resultado> desvincularProveedor({
    required int productoId,
    required int proveedorId,
  }) async {
    exigir(Permiso.productosEditar);

    return _db.transaction(() async {
      final borradas = await (_db.delete(_vinculos)
            ..where((t) =>
                t.productoId.equals(productoId) &
                t.proveedorId.equals(proveedorId)))
          .go();

      if (borradas == 0) {
        return const Fallo(
          MotivoFallo.validacion,
          'Ese proveedor ya no estaba en la lista.',
        );
      }

      await _anotarProveedor(
        productoId,
        'Proveedor quitado: ${await _nombreProveedor(proveedorId)}',
      );
      return const Exito();
    });
  }

  @override
  Future<Resultado> fijarProveedorPrincipal({
    required int productoId,
    required int? proveedorId,
  }) async {
    exigir(Permiso.productosEditar);

    return _db.transaction(() async {
      await _apagarPrincipal(productoId);
      if (proveedorId == null) {
        await _anotarProveedor(productoId, 'Sin proveedor principal');
        return const Exito();
      }

      final encendidas = await (_db.update(_vinculos)
            ..where((t) =>
                t.productoId.equals(productoId) &
                t.proveedorId.equals(proveedorId)))
          .write(
        TablaProductoProveedorCompanion(
          esPrincipal: const Value(true),
          actualizadoEn: Value(DateTime.now()),
        ),
      );

      if (encendidas == 0) {
        return const Fallo(
          MotivoFallo.validacion,
          'Ese proveedor no está entre los del repuesto.',
        );
      }

      await _anotarProveedor(
        productoId,
        'Proveedor principal: ${await _nombreProveedor(proveedorId)}',
      );
      return const Exito();
    });
  }

  /// La razón social del proveedor, que vive en `personas`.
  ///
  /// La bitácora guarda el **nombre** y no el id, como snapshot de §1.2: es la
  /// parte legible que sobrevive al borrado del proveedor.
  Future<String> _nombreProveedor(int proveedorId) async {
    final fila = await (_db.select(_db.tablaProveedor).join([
      innerJoin(
        _db.tablaPersona,
        _db.tablaPersona.id.equalsExp(_db.tablaProveedor.personaId),
      ),
    ])
          ..where(_db.tablaProveedor.id.equals(proveedorId)))
        .getSingleOrNull();

    return fila?.readTable(_db.tablaPersona).nombres ?? '#$proveedorId';
  }

  /// Deja al producto sin ningún principal marcado.
  Future<void> _apagarPrincipal(int productoId) =>
      (_db.update(_vinculos)
            ..where((t) =>
                t.productoId.equals(productoId) & t.esPrincipal.equals(true)))
          .write(
        TablaProductoProveedorCompanion(
          esPrincipal: const Value(false),
          actualizadoEn: Value(DateTime.now()),
        ),
      );

  /// El renglón de bitácora de un cambio de proveedores.
  ///
  /// Se lee el producto para poder nombrarlo: «Ana modificó Pastilla de freno
  /// (FRE-0012) · Proveedor principal: 4» dice algo; «modificó el producto 47»
  /// no le sirve a nadie.
  Future<void> _anotarProveedor(int productoId, String detalle) async {
    final producto = await (_db.select(_db.tablaProducto)
          ..where((t) => t.id.equals(productoId)))
        .getSingleOrNull();

    await _anotar(
      AccionAuditada.modifico,
      productoId,
      producto == null
          ? 'Producto #$productoId'
          : '${producto.nombre} (${producto.sku})',
      detalle: detalle,
    );
  }

  /// Cómo se lee un producto en la bitácora: nombre y SKU, que es lo que
  /// permite reconocerlo cuando la fila ya no existe.
  static String _nombreDe(Producto producto) =>
      '${producto.nombre} (${producto.sku})';

  /// Qué cambió de verdad, campo por campo, para el renglón de la bitácora.
  ///
  /// Sin esto la ficha decía «Ana modificó Pastilla de freno» y nada más, que
  /// es justo lo que no responde la pregunta con la que se abre ese panel: por
  /// qué cambió el precio, quién movió el stock mínimo. La bitácora guarda el
  /// **qué**, no un diff completo: los valores de antes y después de los tres
  /// o cuatro campos que se tocaron, en una línea que se lee de un vistazo.
  ///
  /// Devuelve `null` si no cambió nada de lo que se vigila —guardar el
  /// formulario sin tocar un campo no tiene por qué contar nada—, y entonces
  /// el renglón queda con la fecha y el autor, como antes.
  ///
  /// El stock va aparte porque no se escribe en la columna: se registra como
  /// movimiento (§7 de las reglas de base de datos) y aquí solo se nombra.
  static String? _queCambio(
    TablaProductoData? antes,
    Producto ahora,
    double diferenciaStock,
  ) {
    if (antes == null) return null;

    final cambios = <String>[
      ?_campo('Nombre', antes.nombre, ahora.nombre),
      ?_campo('SKU', antes.sku, ahora.sku),
      ?_precio('Precio de venta', antes.precioVenta, ahora.precioVenta),
      ?_precio('Precio de compra', antes.precioCompra, ahora.precioCompra),
      ?_precio(
        'Precio de taller',
        antes.precioVentaTaller,
        ahora.precioVentaTaller,
      ),
      ?_campo(
        'Stock mínimo',
        _cantidad(antes.stockMinimo),
        _cantidad(ahora.stockMinimo),
      ),
      ?_campo('Ubicación', antes.ubicacionBodega, ahora.ubicacionBodega),
      ?_campo(
        'Estado',
        antes.activo ? 'activo' : 'inactivo',
        ahora.activo ? 'activo' : 'inactivo',
      ),
      if (diferenciaStock != 0)
        'Stock ajustado en ${diferenciaStock > 0 ? '+' : ''}'
            '${_cantidad(diferenciaStock)}',
    ];

    return cambios.isEmpty ? null : cambios.join(' · ');
  }

  /// «Precio de venta: \$10.000 → \$12.000», o `null` si no se movió.
  ///
  /// El importe sale de `core/formato.dart`, que es el único sitio donde se
  /// formatea dinero (`CLAUDE.md` §6). No rompe la regla de que el repositorio
  /// no conozca Flutter: `core/` es Dart puro —lo mismo que `iva_app.dart`,
  /// que este archivo ya usa— y lo que se escribe aquí no es una pantalla,
  /// es el texto que queda guardado en la bitácora.
  static String? _precio(String etiqueta, int? antes, int? ahora) => _campo(
        etiqueta,
        antes == null ? '' : formatearPrecio(antes),
        ahora == null ? '' : formatearPrecio(ahora),
      );

  static String? _campo(String etiqueta, String? antes, String? ahora) {
    final viejo = (antes ?? '').trim();
    final nuevo = (ahora ?? '').trim();
    if (viejo == nuevo) return null;
    return '$etiqueta: ${viejo.isEmpty ? '—' : viejo} → '
        '${nuevo.isEmpty ? '—' : nuevo}';
  }

  /// Una cantidad sin decimales de relleno: `12` y no `12.0`.
  static String _cantidad(double valor) =>
      valor.truncateToDouble() == valor
          ? valor.toInt().toString()
          : valor.toStringAsFixed(2);

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
    exigir(Permiso.productosVer);
    final expr = _db.tablaProducto.id.count();
    final query = _db.selectOnly(_db.tablaProducto)
      ..where(_db.tablaProducto.activo.equals(true))
      ..addColumns([expr]);
    final result = await query.getSingle();
    return result.read(expr) ?? 0;
  }

  @override
  Future<int> contarConStockBajo() async {
    exigir(Permiso.productosVer);
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
      // El código de barras se compara **exacto y normalizado**, no con
      // `LIKE`: lo que llega ahí lo escribió un lector, no una persona, y
      // tiene que dar en el producto de una sola vez aunque el patrón traiga
      // los espacios que el lector inserta. Va en `OR` con lo demás para que
      // el mismo cuadro siga sirviendo para teclear un nombre.
      final codigo = normalizarCodigoBarras(texto);

      // **Todas las palabras tienen que aparecer, cada una donde sea.** Antes
      // se buscaba la frase entera con un solo `LIKE`, así que «freno yamaha»
      // no encontraba «Frenos Yamaha FZ»: nadie escribe las palabras en el
      // orden exacto del catálogo.
      Expression<bool> porPalabras = const Constant(true);
      for (final palabra in _palabras(texto)) {
        final patron = '%$palabra%';
        porPalabras = porPalabras &
            (_plano(p.nombre).like(patron) |
                _plano(p.sku).like(patron) |
                _plano(_db.tablaCategoria.nombre).like(patron));
      }

      acumulado = acumulado &
          (porPalabras |
              (codigo == null
                  ? const Constant(false)
                  : p.codigoBarras.equals(codigo)));
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

  /// Las palabras de la búsqueda, en minúsculas, sin tildes y sin huecos.
  ///
  /// Partirla es lo que la vuelve utilizable: quien teclea «freno yamaha»
  /// quiere lo que sea las dos cosas, y la frase literal solo acierta si la
  /// escribió en el mismo orden en que está el catálogo.
  static List<String> _palabras(String texto) => aplanarTexto(texto)
      .split(RegExp(r'\s+'))
      .where((palabra) => palabra.isNotEmpty)
      .toList(growable: false);

  /// La columna en minúsculas **y sin tildes**, para comparar contra el patrón
  /// ya aplanado.
  ///
  /// Nadie teclea «Baterías» con la tilde, y sin esto «bateria» no encontraba
  /// nada: `LIKE` de SQLite ignora las mayúsculas del ASCII y nada más. Se
  /// resuelve con `replace` anidados en la propia consulta y no con una
  /// columna normalizada aparte, que sería el mismo dato guardado dos veces
  /// (`REGLAS_BD.md` §1.1). Sobre el catálogo de un taller —miles de filas—
  /// cuesta lo mismo que el `LIKE`, que tampoco usa índice (§5).
  static Expression<String> _plano(Expression<String> columna) {
    var expresion = columna.lower();
    tildes.forEach((conTilde, sinTilde) {
      expresion = FunctionCallExpression('replace', [
        expresion,
        Constant(conTilde),
        Constant(sinTilde),
      ]);
    });
    return expresion;
  }

  /// Qué tan bien responde una fila a lo que se tecleó: 0 el nombre, 1 el
  /// SKU, 2 lo demás —hoy, el nombre de su categoría—.
  ///
  /// Sin esto la búsqueda **parecía rota**: como el nombre de la categoría
  /// también cuenta, escribir «freno» devolvía cientos de aceites cuya
  /// categoría era «Frenos», y al ordenar por nombre las pastillas de freno
  /// caían en la página nueve. Ordenar por relevancia se hace en SQL, con un
  /// `CASE`, y no recortando en Dart (§5).
  Expression<int> _relevancia(String texto) {
    final palabras = _palabras(texto);
    if (palabras.isEmpty) return const Constant(2);

    Expression<bool> todasEn(Expression<String> columna) => palabras.fold(
          const Constant(true),
          (acumulado, palabra) => acumulado & _plano(columna).like('%$palabra%'),
        );

    return CaseWhenExpression<int>(
      cases: [
        CaseWhen(todasEn(_db.tablaProducto.nombre), then: const Constant(0)),
        CaseWhen(todasEn(_db.tablaProducto.sku), then: const Constant(1)),
      ],
      orElse: const Constant(2),
    );
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
    exigir(Permiso.productosVer);
    final condicion = _condicion(filtro);
    final texto = filtro.busqueda.trim();

    final consultaPagina = _queryConJoin()
      ..where(condicion)
      // Con búsqueda manda la relevancia y el nombre desempata; sin ella, el
      // catálogo se lee en orden alfabético.
      ..orderBy([
        if (texto.isNotEmpty) OrderingTerm.asc(_relevancia(texto)),
        OrderingTerm.asc(_db.tablaProducto.nombre),
      ])
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
    exigir(Permiso.productosVer);
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

  /// Cuántos repuestos le compra el taller a cada proveedor.
  ///
  /// Cuenta **todos** los vínculos, no solo los principales: la tarjeta del
  /// proveedor dice de cuántas piezas es una opción, que es lo que se quiere
  /// saber al llamarlo. Sale de un `GROUP BY` sobre la tabla de vínculos, no
  /// de recorrer el catálogo (`REGLAS_BD.md` §5).
  @override
  Stream<Map<int, int>> observarConteoPorProveedor() {
    exigir(Permiso.productosVer);
    final cantidad = _db.tablaProductoProveedor.productoId.count();
    final consulta = _db.selectOnly(_db.tablaProductoProveedor)
      ..addColumns([_db.tablaProductoProveedor.proveedorId, cantidad])
      ..groupBy([_db.tablaProductoProveedor.proveedorId]);

    return consulta.watch().map((filas) {
      final conteo = <int, int>{};
      for (final fila in filas) {
        final id = fila.read(_db.tablaProductoProveedor.proveedorId);
        if (id != null) conteo[id] = fila.read(cantidad) ?? 0;
      }
      return conteo;
    });
  }

  @override
  Stream<({int total, int enStock, int stockBajo, int sinStock})>
      observarResumen({FiltroProductos filtro = const FiltroProductos()}) {
    exigir(Permiso.productosVer);
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
