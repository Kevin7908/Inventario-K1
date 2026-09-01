import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import '../../../../core/resultado.dart';
import '../../../share/consecutivos/documento_consecutivo.dart';
import '../../../share/consecutivos/repositorio_consecutivos.dart';
import '../../../share/dominio/permiso.dart';
import '../../../share/dominio/sesion_actual.dart';
import '../../bitacora/modelo/entrada_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora_impl.dart';
import '../../inventario/modelo/movimiento_inventario.dart';
import '../../inventario/repositorio/repositorio_inventario.dart';
import '../../inventario/repositorio/repositorio_inventario_impl.dart';
import '../enum/enum_compras.dart';
import '../mapper/compra_mapper.dart';
import '../modelo/compra_item.dart';
import '../modelo/compra_resumen.dart';
import '../resultado/resultado_compra.dart';
import 'repositorio_compras.dart';

class RepositorioComprasImpl with FirmaDeSesion implements RepositorioCompras {
  RepositorioComprasImpl(this._db, this.sesion);

  final AppDb _db;

  /// Quién firma lo que este repositorio escribe. La inyecta Riverpod desde
  /// `sesionActualProvider`: es una dependencia del constructor, no un
  /// registro global que se consulte por dentro.
  @override
  final SesionActual? sesion;

  /// El número de la remisión sale de `consecutivos`, dentro de la misma
  /// transacción que la crea (§7.1).
  late final RepositorioConsecutivos _consecutivos = RepositorioConsecutivos(
    _db,
  );

  /// El **único** camino por el que cambia el stock (§7).
  late final RepositorioInventario _inventario = RepositorioInventarioImpl(
    _db,
    sesion,
  );

  late final RepositorioBitacora _bitacora = RepositorioBitacoraImpl(
    _db,
    sesion,
  );

  /// Deja el renglón de la bitácora, **dentro** de la transacción del cambio.
  Future<void> _anotar(
    AccionAuditada accion,
    int? id,
    String descripcion, {
    String? detalle,
  }) => _bitacora.anotar(
    Anotacion(
      entidad: EntidadAuditada.compra,
      accion: accion,
      entidadId: id,
      descripcion: descripcion,
      detalle: detalle,
    ),
  );

  // ── Join base ──────────────────────────────────────────────────────────────
  //
  // El nombre del proveedor vive en `personas`: la tabla `proveedores` solo
  // guarda lo propio del rol (§1.1).

  JoinedSelectStatement<HasResultSet, dynamic> get _baseQuery =>
      _db.select(_db.tablaCompra).join([
        innerJoin(
          _db.tablaProveedor,
          _db.tablaProveedor.id.equalsExp(_db.tablaCompra.proveedorId),
        ),
        innerJoin(
          _db.tablaPersona,
          _db.tablaPersona.id.equalsExp(_db.tablaProveedor.personaId),
        ),
      ]);

  CompraResumen _filaAResumen(TypedResult row, {int lineas = 0}) {
    final persona = row.readTable(_db.tablaPersona);
    return CompraMapper.filaAResumen(
      row.readTable(_db.tablaCompra),
      proveedorNombre: '${persona.nombres} ${persona.apellidos ?? ''}'.trim(),
      lineas: lineas,
    );
  }

  // ── Lecturas ───────────────────────────────────────────────────────────────

  @override
  Stream<PaginaCompras> observarPagina({
    required FiltroCompras filtro,
    required int pagina,
    required int tamano,
  }) {
    // Ver lo que costó cada remisión no lo mira cualquiera: es el margen del
    // taller. Esconder el ítem del sidebar es orden; esta línea es el control.
    exigir(Permiso.comprasVer);

    // El conteo de líneas va en una subconsulta correlacionada y no en un
    // `JOIN` + `GROUP BY`: con el `LIMIT` puesto, agrupar cambiaría las filas
    // que la página devuelve.
    final consulta = _baseQuery
      ..addColumns([_conteoLineas])
      ..orderBy([
        OrderingTerm.desc(_db.tablaCompra.fecha),
        // El id desempata: dos remisiones del mismo día caen en la misma
        // fecha y sin esto quedarían en orden arbitrario.
        OrderingTerm.desc(_db.tablaCompra.id),
      ]);

    _aplicarFiltro(consulta, filtro);
    consulta.limit(tamano, offset: pagina * tamano);

    return consulta.watch().asyncMap((filas) async {
      final items = filas
          .map((f) => _filaAResumen(f, lineas: f.read(_conteoLineas) ?? 0))
          .toList(growable: false);
      return PaginaCompras(items: items, total: await _total(filtro));
    });
  }

  /// Cuántas líneas tiene la remisión, resuelto por SQLite en la misma pasada.
  ///
  /// **Una sola instancia**, y no un getter que la construya cada vez: la fila
  /// del resultado se lee con la misma expresión que se agregó a la consulta,
  /// y dos instancias distintas no se reconocen entre sí.
  late final Expression<int> _conteoLineas = subqueryExpression<int>(
        _db.selectOnly(_db.tablaCompraDetalle)
          ..addColumns([_db.tablaCompraDetalle.id.count()])
          ..where(
            _db.tablaCompraDetalle.compraId.equalsExp(_db.tablaCompra.id),
          ),
      );

  /// El total real, sin el `LIMIT`: es lo que necesita el paginador para saber
  /// cuántas páginas hay.
  Future<int> _total(FiltroCompras filtro) async {
    final conteo = _db.tablaCompra.id.count();
    final consulta = _baseQuery..addColumns([conteo]);
    _aplicarFiltro(consulta, filtro);
    final fila = await consulta.getSingleOrNull();
    return fila?.read(conteo) ?? 0;
  }

  /// El `WHERE`, compartido por la página y por el `COUNT`: si divergieran, el
  /// paginador contaría filas que la página no muestra.
  void _aplicarFiltro(
    JoinedSelectStatement<HasResultSet, dynamic> consulta,
    FiltroCompras filtro,
  ) {
    final c = _db.tablaCompra;

    if (filtro.proveedorId != null) {
      consulta.where(c.proveedorId.equals(filtro.proveedorId!));
    }
    if (filtro.estado != null) {
      consulta.where(c.estado.equals(filtro.estado!.codigo));
    }
    if (filtro.desde != null) {
      consulta.where(c.fecha.isBiggerOrEqualValue(filtro.desde!));
    }
    if (filtro.hasta != null) {
      consulta.where(c.fecha.isSmallerOrEqualValue(filtro.hasta!));
    }

    final busqueda = filtro.busqueda.trim();
    if (busqueda.isEmpty) return;

    final patron = '%$busqueda%';
    consulta.where(
      c.numero.like(patron) |
          c.numeroFactura.like(patron) |
          _db.tablaPersona.nombres.like(patron) |
          _db.tablaPersona.apellidos.like(patron),
    );
  }

  @override
  Stream<ResumenCompras> observarResumen() {
    exigir(Permiso.comprasVer);

    final c = _db.tablaCompra;
    final ahora = DateTime.now();
    final inicioMes = DateTime(ahora.year, ahora.month);

    final delMes = c.fecha.isBiggerOrEqualValue(inicioMes) &
        c.estado.equals(EstadoCompra.registrada.codigo);

    final compras = c.id.count(filter: delMes);
    final invertido = c.total.sum(filter: delMes);
    final proveedores = c.proveedorId.count(distinct: true, filter: delMes);
    final anuladas = c.id.count(
      filter: c.estado.equals(EstadoCompra.anulada.codigo),
    );

    final consulta = _db.selectOnly(c)
      ..addColumns([compras, invertido, proveedores, anuladas]);

    return consulta.watchSingleOrNull().map(
          (fila) => (
            comprasMes: fila?.read(compras) ?? 0,
            invertidoMes: fila?.read(invertido) ?? 0,
            proveedoresMes: fila?.read(proveedores) ?? 0,
            anuladas: fila?.read(anuladas) ?? 0,
          ),
        );
  }

  @override
  Future<CompraDetalle> obtenerDetalle(int id) async {
    exigir(Permiso.comprasVer);

    final fila =
        await (_baseQuery..where(_db.tablaCompra.id.equals(id)))
            .getSingleOrNull();
    if (fila == null) throw Exception('La compra #$id no existe.');

    return CompraDetalle(
      resumen: _filaAResumen(fila, lineas: 0),
      items: await _cargarItems(id),
    );
  }

  /// Las líneas con el SKU y la foto de su producto, en un solo `JOIN`: una
  /// consulta por línea sería el N+1 que prohíbe §5.
  Future<List<CompraItem>> _cargarItems(int compraId) async {
    final filas =
        await (_db.select(_db.tablaCompraDetalle).join([
                innerJoin(
                  _db.tablaProducto,
                  _db.tablaProducto.id.equalsExp(
                    _db.tablaCompraDetalle.productoId,
                  ),
                ),
              ])
              ..where(_db.tablaCompraDetalle.compraId.equals(compraId))
              ..orderBy([OrderingTerm.asc(_db.tablaCompraDetalle.id)]))
            .get();

    return filas.map((row) {
      final producto = row.readTable(_db.tablaProducto);
      return CompraMapper.itemAModelo(
        row.readTable(_db.tablaCompraDetalle),
        sku: producto.sku,
        imagenUrl: producto.imagenUrl,
      );
    }).toList(growable: false);
  }

  @override
  Stream<UltimaCompra?> observarUltimaCompra(int productoId) {
    // Sin `exigir`: esto es el «última compra hace 12 días» de la ficha del
    // producto, y lo mira quien puede ver el producto. Lo que el permiso de
    // compras protege es el documento entero, no el costo de una línea, que
    // ya está en `productos.precio_compra` a la vista de todos.
    return _db
        .customSelect(
          '''
      SELECT c.id, c.numero, c.fecha, d.costo_unitario, d.cantidad,
             TRIM(pe.nombres || ' ' || COALESCE(pe.apellidos, '')) AS proveedor
      FROM compra_detalles d
      JOIN compras     c  ON c.id  = d.compra_id
      JOIN proveedores pr ON pr.id = c.proveedor_id
      JOIN personas    pe ON pe.id = pr.persona_id
      WHERE d.producto_id = ? AND c.estado = ?
      ORDER BY c.fecha DESC, c.id DESC
      LIMIT 1
      ''',
          variables: [
            Variable.withInt(productoId),
            Variable.withString(EstadoCompra.registrada.codigo),
          ],
          readsFrom: {
            _db.tablaCompraDetalle,
            _db.tablaCompra,
            _db.tablaProveedor,
            _db.tablaPersona,
          },
        )
        .watchSingleOrNull()
        .map(
          (fila) => fila == null
              ? null
              : UltimaCompra(
                  compraId: fila.read<int>('id'),
                  numero: fila.read<String>('numero'),
                  fecha: fila.read<DateTime>('fecha'),
                  costoUnitario: fila.read<int>('costo_unitario'),
                  cantidad: fila.read<double>('cantidad'),
                  proveedorNombre: fila.read<String>('proveedor'),
                ),
        );
  }

  @override
  Stream<ResumenProveedorCompras> observarResumenProveedor(int proveedorId) {
    exigir(Permiso.comprasVer);

    final c = _db.tablaCompra;
    final ahora = DateTime.now();
    final inicioMes = DateTime(ahora.year, ahora.month);

    final vivas = c.proveedorId.equals(proveedorId) &
        c.estado.equals(EstadoCompra.registrada.codigo);
    final delMes = vivas & c.fecha.isBiggerOrEqualValue(inicioMes);

    final compras = c.id.count(filter: delMes);
    final invertidoMes = c.total.sum(filter: delMes);
    final invertidoTotal = c.total.sum(filter: vivas);
    final ultima = c.fecha.max(filter: vivas);

    final consulta = _db.selectOnly(c)
      ..addColumns([compras, invertidoMes, invertidoTotal, ultima]);

    return consulta.watchSingleOrNull().map(
          (fila) => (
            comprasMes: fila?.read(compras) ?? 0,
            invertidoMes: fila?.read(invertidoMes) ?? 0,
            invertidoTotal: fila?.read(invertidoTotal) ?? 0,
            ultimaCompra: fila?.read(ultima),
          ),
        );
  }

  // ── Escrituras ─────────────────────────────────────────────────────────────

  @override
  Future<ResultadoCompra> crear({
    required int proveedorId,
    DateTime? fecha,
    String? numeroFactura,
    String? notas,
  }) async {
    if (!puede(Permiso.comprasCrear)) {
      return const CompraRechazada(
        MotivoFallo.validacion,
        'Tu cuenta no tiene permiso para registrar compras. Pídeselo a un '
        'administrador del taller.',
      );
    }

    final factura = _limpio(numeroFactura);

    try {
      return await _db.transaction(() async {
        if (factura != null && await _facturaRepetida(proveedorId, factura)) {
          return CompraRechazada(
            MotivoFallo.remisionDuplicada,
            'Ese proveedor ya tiene registrada la factura $factura.',
          );
        }

        // El número se pide **dentro** de la transacción que inserta la
        // compra: si el `INSERT` falla, el consecutivo se devuelve y la serie
        // sigue sin huecos (§7.1).
        final numero = await _consecutivos.siguiente(
          DocumentoConsecutivo.compra,
        );
        final compraId = await _db
            .into(_db.tablaCompra)
            .insert(
              CompraMapper.nuevaACompanion(
                usuarioId: autorId,
                numero: numero,
                proveedorId: proveedorId,
                fecha: fecha ?? DateTime.now(),
                numeroFactura: factura,
                notas: _limpio(notas),
              ),
            );

        await _anotar(
          AccionAuditada.creo,
          compraId,
          'Compra $numero',
          detalle: factura == null ? null : 'Factura $factura',
        );

        return CompraRegistrada(compraId: compraId, numero: numero);
      });
    } catch (e) {
      return CompraRechazada(MotivoFallo.persistencia, _mensaje(e));
    }
  }

  @override
  Future<Resultado> actualizarCabecera({
    required int id,
    int? proveedorId,
    DateTime? fecha,
    String? numeroFactura,
    String? notas,
  }) async {
    final compra = await _fila(id);
    if (compra == null) {
      return const Fallo(MotivoFallo.persistencia, 'La compra ya no existe.');
    }

    final proveedor = proveedorId ?? compra.proveedorId;
    final factura = _limpio(numeroFactura);

    // El `UNIQUE` lo impediría igual; esto es para poder señalar el campo.
    if (factura != null &&
        (factura != compra.numeroFactura || proveedor != compra.proveedorId) &&
        await _facturaRepetida(proveedor, factura)) {
      return Fallo(
        MotivoFallo.remisionDuplicada,
        'Ese proveedor ya tiene registrada la factura $factura.',
      );
    }

    return _envolver(
      () => (_db.update(_db.tablaCompra)..where((t) => t.id.equals(id))).write(
        TablaCompraCompanion(
          proveedorId: Value(proveedor),
          fecha: Value(fecha ?? compra.fecha),
          numeroFactura: Value(factura),
          notas: Value(_limpio(notas)),
          actualizadoEn: Value(DateTime.now()),
        ),
      ),
    );
  }

  // ── Líneas ─────────────────────────────────────────────────────────────────

  @override
  Future<Resultado> agregarLinea({
    required int compraId,
    required int productoId,
    required double cantidad,
    required int costoUnitario,
  }) async {
    if (!puede(Permiso.comprasCrear)) {
      return const Fallo(
        MotivoFallo.validacion,
        'Tu cuenta no tiene permiso para registrar compras. Pídeselo a un '
        'administrador del taller.',
      );
    }
    if (cantidad <= 0) {
      return const Fallo(
        MotivoFallo.validacion,
        'La cantidad tiene que ser mayor que cero.',
      );
    }

    try {
      await _db.transaction(() async {
        await _exigirAbierta(compraId);
        final producto = await _producto(productoId);

        // Si el producto ya está en la remisión se le suma a su línea, como
        // hace el carrito: dos filas del mismo producto solo complican la
        // lectura. La `UNIQUE` de la tabla es la garantía; esto es lo que
        // evita el choque.
        final existente =
            await (_db.select(_db.tablaCompraDetalle)
                  ..where(
                    (t) =>
                        t.compraId.equals(compraId) &
                        t.productoId.equals(productoId),
                  )
                  ..limit(1))
                .getSingleOrNull();

        if (existente == null) {
          await _db
              .into(_db.tablaCompraDetalle)
              .insert(
                CompraMapper.itemACompanion(
                  compraId: compraId,
                  productoId: productoId,
                  // El nombre se congela aquí y no lo manda la vista: es el
                  // snapshot de §1.2.
                  descripcion: producto.nombre,
                  cantidad: cantidad,
                  costoUnitario: costoUnitario,
                ),
              );
        } else {
          await (_db.update(
            _db.tablaCompraDetalle,
          )..where((t) => t.id.equals(existente.id))).write(
            TablaCompraDetalleCompanion(
              cantidad: Value(existente.cantidad + cantidad),
              costoUnitario: Value(costoUnitario),
            ),
          );
        }

        await _meterAlInventario(compraId, productoId, cantidad);
        await _fijarCosto(productoId, costoUnitario);
        await _recalcularTotal(compraId);
      });
      return const Exito();
    } catch (e) {
      return Fallo(MotivoFallo.persistencia, _mensaje(e));
    }
  }

  @override
  Future<Resultado> actualizarLinea(
    int lineaId, {
    double? cantidad,
    int? costoUnitario,
  }) async {
    try {
      await _db.transaction(() async {
        final actual = await _filaLinea(lineaId);
        if (actual == null) throw Exception('La línea ya no existe.');
        await _exigirAbierta(actual.compraId);

        final cantidadNueva = cantidad ?? actual.cantidad;
        if (cantidadNueva <= 0) {
          throw Exception('La cantidad tiene que ser mayor que cero.');
        }
        final delta = cantidadNueva - actual.cantidad;

        // Solo se mueve la diferencia: subir de 2 a 5 mete tres más, bajar de
        // 5 a 2 saca tres. Registrar la cantidad entera duplicaría la entrada.
        if (delta > 0) {
          await _meterAlInventario(actual.compraId, actual.productoId, delta);
        } else if (delta < 0) {
          await _sacarDelInventario(
            actual.compraId,
            actual.productoId,
            -delta,
          );
        }

        await (_db.update(
          _db.tablaCompraDetalle,
        )..where((t) => t.id.equals(lineaId))).write(
          TablaCompraDetalleCompanion(
            cantidad: Value(cantidadNueva),
            costoUnitario: Value(costoUnitario ?? actual.costoUnitario),
          ),
        );

        if (costoUnitario != null) {
          await _fijarCosto(actual.productoId, costoUnitario);
        }
        await _recalcularTotal(actual.compraId);
      });
      return const Exito();
    } catch (e) {
      return Fallo(MotivoFallo.persistencia, _mensaje(e));
    }
  }

  @override
  Future<Resultado> eliminarLinea(int lineaId) async {
    try {
      await _db.transaction(() async {
        final actual = await _filaLinea(lineaId);
        if (actual == null) return;
        await _exigirAbierta(actual.compraId);

        await _sacarDelInventario(
          actual.compraId,
          actual.productoId,
          actual.cantidad,
        );

        await (_db.delete(
          _db.tablaCompraDetalle,
        )..where((t) => t.id.equals(lineaId))).go();

        await _recalcularTotal(actual.compraId);
      });
      return const Exito();
    } catch (e) {
      return Fallo(MotivoFallo.persistencia, _mensaje(e));
    }
  }

  @override
  Future<Resultado> anular(int id) async {
    if (!puede(Permiso.comprasAnular)) {
      return const Fallo(
        MotivoFallo.validacion,
        'Tu cuenta no tiene permiso para anular compras. Pídeselo a un '
        'administrador del taller.',
      );
    }

    try {
      await _db.transaction(() async {
        final compra = await (_db.select(
          _db.tablaCompra,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (compra == null) throw Exception('La compra #$id no existe.');
        if (compra.estado == EstadoCompra.anulada.codigo) {
          throw Exception('La compra ${compra.numero} ya está anulada.');
        }

        // Sacar primero y marcar después: si la mercancía ya se vendió, esto
        // lanza y la compra se queda como estaba en vez de quedar anulada con
        // el stock sin devolver.
        for (final item in await _cargarItems(id)) {
          await _sacarDelInventario(
            id,
            item.productoId,
            item.cantidad,
            notas: 'Anulación de la compra ${compra.numero}',
          );
        }

        await (_db.update(
          _db.tablaCompra,
        )..where((t) => t.id.equals(id))).write(
          TablaCompraCompanion(
            estado: Value(EstadoCompra.anulada.codigo),
            actualizadoEn: Value(DateTime.now()),
          ),
        );

        await _anotar(
          AccionAuditada.anulo,
          id,
          'Compra ${compra.numero}',
          detalle: 'Salieron del inventario ${compra.total} pesos de mercancía',
        );
      });
      return const Exito();
    } catch (e) {
      return Fallo(MotivoFallo.persistencia, _mensaje(e));
    }
  }

  @override
  Future<Map<int, int>> descuadres() async {
    final filas = await _db
        .customSelect(
          '''
      SELECT c.id AS id,
             c.total - COALESCE(
               SUM(CAST(ROUND(d.cantidad * d.costo_unitario) AS INTEGER)), 0
             ) AS diferencia
      FROM compras c
      LEFT JOIN compra_detalles d ON d.compra_id = c.id
      GROUP BY c.id
      HAVING diferencia <> 0
      ''',
          readsFrom: {_db.tablaCompra, _db.tablaCompraDetalle},
        )
        .get();

    return {
      for (final fila in filas)
        fila.read<int>('id'): fila.read<int>('diferencia'),
    };
  }

  // ── Helpers privados ───────────────────────────────────────────────────────

  Future<TablaCompraData?> _fila(int id) => (_db.select(
        _db.tablaCompra,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<TablaCompraDetalleData?> _filaLinea(int id) => (_db.select(
        _db.tablaCompraDetalle,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Una compra anulada no se toca. La guarda de la base lo impide igual;
  /// esto existe para poder decir por qué.
  Future<void> _exigirAbierta(int compraId) async {
    final compra = await _fila(compraId);
    if (compra == null) throw Exception('La compra ya no existe.');
    if (compra.estado == EstadoCompra.anulada.codigo) {
      throw Exception(
        'La compra ${compra.numero} está anulada y ya no admite cambios.',
      );
    }
  }

  Future<TablaProductoData> _producto(int productoId) async {
    final producto = await (_db.select(
      _db.tablaProducto,
    )..where((t) => t.id.equals(productoId))).getSingleOrNull();
    if (producto == null) {
      throw Exception('El producto ya no está en el catálogo.');
    }
    return producto;
  }

  Future<void> _meterAlInventario(
    int compraId,
    int productoId,
    double cantidad,
  ) => _inventario.registrar(
    SolicitudMovimiento.entrada(
      productoId: productoId,
      cantidad: cantidad,
      tipo: TipoMovimiento.entradaCompra,
      compraId: compraId,
    ),
  );

  /// La salida que corrige una entrada: bajar una línea, quitarla o anular la
  /// remisión entera. Falla si esa mercancía ya salió del taller.
  Future<void> _sacarDelInventario(
    int compraId,
    int productoId,
    double cantidad, {
    String? notas,
  }) async {
    await _verificarStock(productoId, cantidad);
    await _inventario.registrar(
      SolicitudMovimiento.salida(
        productoId: productoId,
        cantidad: cantidad,
        tipo: TipoMovimiento.ajusteNegativo,
        compraId: compraId,
        notas: notas,
      ),
    );
  }

  /// **El costo de referencia pasa a ser el que se acaba de pagar.** Antes
  /// `precio_compra` era un número que alguien tecleó una vez, así que el
  /// margen que muestra la app no era el real. El histórico no se pierde:
  /// sigue línea por línea en `compra_detalles`.
  Future<void> _fijarCosto(int productoId, int costo) =>
      (_db.update(_db.tablaProducto)..where((t) => t.id.equals(productoId)))
          .write(
        TablaProductoCompanion(
          precioCompra: Value(costo),
          actualizadoEn: Value(DateTime.now()),
        ),
      );

  /// Recalcula el caché **entero** desde las líneas, nunca sumándole el delta
  /// al valor anterior: así no puede desviarse aunque una escritura falle a
  /// mitad, y `descuadres()` puede afirmar que siempre coincide.
  Future<void> _recalcularTotal(int compraId) async {
    final total = await _sumaLineas(compraId);
    await (_db.update(_db.tablaCompra)..where((t) => t.id.equals(compraId)))
        .write(
      TablaCompraCompanion(
        total: Value(total),
        actualizadoEn: Value(DateTime.now()),
      ),
    );
  }

  /// Traduce lo que SQLite rechace a un [Fallo] tipado. Las reglas que tienen
  /// mensaje propio ya se comprobaron antes: aquí solo queda lo imprevisto.
  Future<Resultado> _envolver(Future<void> Function() operacion) async {
    try {
      await operacion();
      return const Exito();
    } catch (e) {
      return Fallo(
        MotivoFallo.persistencia,
        'No se pudo guardar: ${_mensaje(e)}',
      );
    }
  }

  /// El `UNIQUE (proveedor_id, numero_factura)` lo impediría igual; esto es
  /// para poder decir cuál es la remisión que ya está.
  Future<bool> _facturaRepetida(int proveedorId, String factura) async {
    final fila =
        await (_db.select(_db.tablaCompra)
              ..where(
                (t) =>
                    t.proveedorId.equals(proveedorId) &
                    t.numeroFactura.equals(factura),
              )
              ..limit(1))
            .getSingleOrNull();
    return fila != null;
  }

  Future<int> _sumaLineas(int compraId) async {
    final fila = await _db
        .customSelect(
          'SELECT COALESCE(SUM(CAST(ROUND(cantidad * costo_unitario) AS '
          'INTEGER)), 0) AS s FROM compra_detalles WHERE compra_id = ?',
          variables: [Variable.withInt(compraId)],
          readsFrom: {_db.tablaCompraDetalle},
        )
        .getSingle();
    return fila.read<int>('s');
  }

  /// Lanza si deshacer una entrada dejaría el stock en negativo, con el
  /// mensaje que ve el usuario. La mercancía que ya se vendió no se puede
  /// «des-recibir».
  Future<void> _verificarStock(int productoId, double cantidad) async {
    final fila = await _db
        .customSelect(
          'SELECT stock_actual, nombre FROM productos WHERE id = ?',
          variables: [Variable.withInt(productoId)],
          readsFrom: {_db.tablaProducto},
        )
        .getSingleOrNull();

    final disponible = (fila?.data['stock_actual'] as num?)?.toDouble() ?? 0;
    if (disponible >= cantidad) return;

    final nombre = fila?.data['nombre'] as String? ?? 'un producto';
    throw Exception(
      'De "$nombre" entraron ${_cantidad(cantidad)} y solo quedan '
      '${_cantidad(disponible)}: lo demás ya salió del taller, así que la '
      'corrección es un ajuste de inventario.',
    );
  }

  static String? _limpio(String? texto) {
    final t = texto?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  static String _cantidad(double valor) =>
      valor % 1 == 0 ? valor.toInt().toString() : valor.toStringAsFixed(2);

  static String _mensaje(Object e) =>
      e.toString().replaceFirst('Exception: ', '');
}
