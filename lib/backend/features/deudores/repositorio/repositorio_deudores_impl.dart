import '../../motos/repositorio/join_moto.dart';
import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import '../../../../core/resultado.dart';
import '../../../share/consecutivos/documento_consecutivo.dart';
import '../../../share/consecutivos/repositorio_consecutivos.dart';
import '../../../share/dominio/metodo_pago.dart';
import '../../inventario/modelo/movimiento_inventario.dart';
import '../../inventario/repositorio/repositorio_inventario.dart';
import '../../inventario/repositorio/repositorio_inventario_impl.dart';
import '../enum/enum_deudor.dart';
import '../mapper/deudor_mapper.dart';
import '../modelo/deudor_detalle.dart';
import '../modelo/deudor_item.dart';
import '../modelo/deudor_pago.dart';
import '../modelo/deudor_resumen.dart';
import 'repositorio_deudores.dart';
import '../../../share/dominio/sesion_actual.dart';
import '../../bitacora/modelo/entrada_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora_impl.dart';
import '../../../share/dominio/permiso.dart';

class RepositorioDeudoresImpl
    with FirmaDeSesion
    implements RepositorioDeudores {
  RepositorioDeudoresImpl(this._db, this.sesion);

  /// Quién firma lo que este repositorio escribe. La inyecta Riverpod
  /// desde `sesionActualProvider`: es una dependencia del constructor, no
  /// un registro global que se consulte por dentro.
  @override
  final SesionActual? sesion;

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
      entidad: EntidadAuditada.deuda,
      accion: accion,
      entidadId: id,
      descripcion: descripcion,
      detalle: detalle,
    ),
  );

  final AppDb _db;

  /// Los números de documento salen de la tabla `consecutivos`, no de `MAX+1`
  /// ni del `id`: ver `RepositorioConsecutivos`.
  late final RepositorioConsecutivos _consecutivos = RepositorioConsecutivos(
    _db,
  );

  /// El **único** camino por el que cambia el stock (§7 de `REGLAS_BD.md`).
  late final RepositorioInventario _inventario = RepositorioInventarioImpl(
    _db,
    sesion,
  );

  // ── Join base ──────────────────────────────────────────────────────────────

  JoinedSelectStatement<HasResultSet, dynamic> get _baseQuery {
    return _db.select(_db.tablaDeudor).join([
      innerJoin(
        _db.tablaCliente,
        _db.tablaCliente.id.equalsExp(_db.tablaDeudor.clienteId),
      ),
      // El nombre del cliente vive en `personas`.
      innerJoin(
        _db.tablaPersona,
        _db.tablaPersona.id.equalsExp(_db.tablaCliente.personaId),
      ),
      // `useColumns: false` no aplica: la moto se lee para la cabecera. Va en
      // `leftOuterJoin` porque hay fiados de mostrador sin moto.
      leftOuterJoin(
        _db.tablaMoto,
        _db.tablaMoto.id.equalsExp(_db.tablaDeudor.motoId),
      ),
      ..._db.joinsCatalogoMoto,
    ]);
  }

  DeudorResumen _filaAResumen(TypedResult row) {
    final d = row.readTable(_db.tablaDeudor);
    final cli = row.readTable(_db.tablaPersona);
    final moto = row.readTableOrNull(_db.tablaMoto);
    final nombreCliente = '${cli.nombres} ${cli.apellidos ?? ''}'.trim();

    return DeudorMapper.filaAResumen(
      d,
      nombreCliente: nombreCliente,
      nombreMoto: _db.nombreMotoDe(row, conAnio: false),
      placaMoto: moto?.placa,
    );
  }

  // ── Lecturas ───────────────────────────────────────────────────────────────

  @override
  Stream<PaginaDeudores> observarPagina({
    required FiltroDeudores filtro,
    required int pagina,
    required int tamano,
  }) {
    final consulta = _baseQuery
      ..orderBy([OrderingTerm.desc(_db.tablaDeudor.creadoEn)]);
    _aplicarFiltro(consulta, filtro);
    consulta.limit(tamano, offset: pagina * tamano);

    // El total va aparte y sin `LIMIT`: es cuántas cumplen el filtro, no
    // cuántas caben en la página.
    final conteo = _db.selectOnly(_db.tablaDeudor).join([
      innerJoin(
        _db.tablaCliente,
        _db.tablaCliente.id.equalsExp(_db.tablaDeudor.clienteId),
      ),
      innerJoin(
        _db.tablaPersona,
        _db.tablaPersona.id.equalsExp(_db.tablaCliente.personaId),
      ),
    ])..addColumns([_db.tablaDeudor.id.count()]);
    _aplicarFiltro(conteo, filtro);

    return consulta.watch().asyncMap((rows) async {
      final fila = await conteo.getSingle();
      return PaginaDeudores(
        items: rows.map(_filaAResumen).toList(),
        total: fila.read(_db.tablaDeudor.id.count()) ?? 0,
      );
    });
  }

  /// El mismo `WHERE` para la página y para el `COUNT`. Separarlos era la vía
  /// por la que el total podía contar deudas que la página no muestra.
  ///
  /// La búsqueda **no mira la moto**, aunque la cabecera la enseñe: el `COUNT`
  /// no hace el `JOIN` con motos, y colar aquí una columna que solo existe en
  /// una de las dos consultas es justo cómo se descuadran.
  void _aplicarFiltro(
    JoinedSelectStatement<HasResultSet, dynamic> consulta,
    FiltroDeudores filtro,
  ) {
    final t = _db.tablaDeudor;
    switch (filtro.vista) {
      case VistaDeudores.todas:
        break;
      case VistaDeudores.alDia:
        consulta.where(_viva & _vencida.not());
      case VistaDeudores.vencidas:
        consulta.where(_viva & _vencida);
      case VistaDeudores.pagadas:
        consulta.where(t.estado.equals(EstadoDeudor.pagada.valor));
    }

    final texto = filtro.busqueda.trim();
    if (texto.isEmpty) return;

    final patron = '%${texto.toLowerCase()}%';
    consulta.where(
      t.numero.lower().like(patron) |
          t.concepto.lower().like(patron) |
          _db.tablaPersona.nombres.lower().like(patron) |
          _db.tablaPersona.apellidos.lower().like(patron),
    );
  }

  /// Sigue esperando plata: ni cobrada ni dada por perdida.
  Expression<bool> get _viva => _db.tablaDeudor.estado.isIn([
    EstadoDeudor.activa.valor,
    EstadoDeudor.vencida.valor,
  ]);

  /// Se le pasó el plazo, o alguien la dio por vencida antes de tiempo.
  ///
  /// Es la traducción literal de `DeudorResumen.estaVencida`, y tiene que
  /// seguir siéndolo: si las dos se separan, el contador de la cabecera dice
  /// una cosa y el badge de la fila otra.
  Expression<bool> get _vencida {
    final t = _db.tablaDeudor;
    final hoy = DateTime.now();
    final medianoche = DateTime(hoy.year, hoy.month, hoy.day);
    return t.estado.equals(EstadoDeudor.vencida.valor) |
        (t.fechaVencimiento.isNotNull() &
            t.fechaVencimiento.isSmallerThanValue(medianoche));
  }

  @override
  Stream<ResumenCartera> observarResumen() {
    final t = _db.tablaDeudor;

    // Una sola pasada: un `SUM` y tres `COUNT` con su propio `filter`.
    final porCobrar = (t.montoTotal - t.montoPagado).sum(filter: _viva);
    final alDia = t.id.count(filter: _viva & _vencida.not());
    final vencidas = t.id.count(filter: _viva & _vencida);
    final pagadas = t.id.count(
      filter: t.estado.equals(EstadoDeudor.pagada.valor),
    );

    final consulta = _db.selectOnly(t)
      ..addColumns([porCobrar, alDia, vencidas, pagadas]);

    return consulta.watchSingleOrNull().map(
      (fila) => (
        porCobrar: fila?.read(porCobrar) ?? 0,
        alDia: fila?.read(alDia) ?? 0,
        vencidas: fila?.read(vencidas) ?? 0,
        pagadas: fila?.read(pagadas) ?? 0,
      ),
    );
  }

  @override
  Future<DeudorDetalle> obtenerDetalle(int id) async {
    final rows = await (_baseQuery..where(_db.tablaDeudor.id.equals(id))).get();
    if (rows.isEmpty) throw Exception('Deudor $id no encontrado');

    return DeudorDetalle(
      resumen: _filaAResumen(rows.first),
      items: await _cargarItems(id),
      pagos: await _cargarPagos(id),
    );
  }

  /// Las líneas con el nombre y la foto de su producto, en un solo `JOIN`: una
  /// consulta por línea sería el N+1 que prohíbe §5.
  Future<List<DeudorItem>> _cargarItems(int deudorId) async {
    final filas =
        await (_db.select(_db.tablaDeudorItem).join([
                innerJoin(
                  _db.tablaProducto,
                  _db.tablaProducto.id.equalsExp(
                    _db.tablaDeudorItem.productoId,
                  ),
                ),
              ])
              ..where(_db.tablaDeudorItem.deudorId.equals(deudorId))
              ..orderBy([OrderingTerm.asc(_db.tablaDeudorItem.id)]))
            .get();

    return filas.map((row) {
      final item = row.readTable(_db.tablaDeudorItem);
      final prod = row.readTable(_db.tablaProducto);
      return DeudorMapper.itemAModelo(
        item,
        nombreProducto: prod.nombre,
        sku: prod.sku,
        imagenUrl: prod.imagenUrl,
      );
    }).toList();
  }

  Future<List<DeudorPago>> _cargarPagos(int deudorId) async {
    final filas =
        await (_db.select(_db.tablaDeudorPago)
              ..where((t) => t.deudorId.equals(deudorId))
              ..orderBy([(t) => OrderingTerm.asc(t.fechaPago)]))
            .get();
    return filas.map(DeudorMapper.pagoAModelo).toList();
  }

  // ── Cabecera ───────────────────────────────────────────────────────────────

  @override
  Future<int> crear({
    required int clienteId,
    int? motoId,
    String? concepto,
    DateTime? fechaVencimiento,
    String? notas,
  }) {
    exigir(Permiso.deudoresCrear);

    return _db.transaction(() async {
      final numero = await _consecutivos.siguiente(DocumentoConsecutivo.deuda);
      return _db
          .into(_db.tablaDeudor)
          .insert(
            DeudorMapper.nuevaACompanion(
              usuarioId: autorId,
              numero: numero,
              clienteId: clienteId,
              motoId: motoId,
              concepto: _limpio(concepto),
              fechaVencimiento: fechaVencimiento,
              notas: _limpio(notas),
            ),
          );
    });
  }

  @override
  Future<Resultado> actualizar({
    required int id,
    int? motoId,
    String? concepto,
    DateTime? fechaVencimiento,
    String? notas,
  }) async {
    final deudor = await _fila(id);
    if (deudor == null) {
      return const Fallo(MotivoFallo.persistencia, 'La deuda ya no existe.');
    }

    return _envolver(
      () => (_db.update(_db.tablaDeudor)..where((t) => t.id.equals(id))).write(
        TablaDeudorCompanion(
          motoId: Value(motoId),
          concepto: Value(_limpio(concepto)),
          fechaVencimiento: Value(fechaVencimiento),
          notas: Value(_limpio(notas)),
          actualizadoEn: Value(DateTime.now()),
        ),
      ),
    );
  }

  // ── Líneas ─────────────────────────────────────────────────────────────────

  @override
  Future<Resultado> agregarItem({
    required int deudorId,
    required int productoId,
    required double cantidad,
    required int precioUnitario,
  }) async {
    try {
      await _db.transaction(() async {
        await _exigirViva(deudorId);
        await _verificarStock(productoId, cantidad);

        // Si el producto ya está fiado en esta deuda se suma a su línea, como
        // hace el carrito: dos filas del mismo producto solo complican la
        // lectura y no dicen nada que la cantidad no diga. La `UNIQUE` de la
        // tabla es la garantía; esto es lo que evita el choque.
        final existente =
            await (_db.select(_db.tablaDeudorItem)
                  ..where(
                    (t) =>
                        t.deudorId.equals(deudorId) &
                        t.productoId.equals(productoId),
                  )
                  ..limit(1))
                .getSingleOrNull();

        if (existente == null) {
          await _db
              .into(_db.tablaDeudorItem)
              .insert(
                DeudorMapper.itemACompanion(
                  usuarioId: autorId,
                  deudorId: deudorId,
                  productoId: productoId,
                  cantidad: cantidad,
                  precioUnitario: precioUnitario,
                ),
              );
        } else {
          await (_db.update(
            _db.tablaDeudorItem,
          )..where((t) => t.id.equals(existente.id))).write(
            TablaDeudorItemCompanion(
              cantidad: Value(existente.cantidad + cantidad),
              precioUnitario: Value(precioUnitario),
            ),
          );
        }

        await _sacarDelInventario(deudorId, productoId, cantidad);
        await _recalcularTotales(deudorId);
      });
      return const Exito();
    } catch (e) {
      return Fallo(MotivoFallo.persistencia, _mensaje(e));
    }
  }

  @override
  Future<Resultado> actualizarItem(
    int itemId, {
    double? cantidad,
    int? precioUnitario,
  }) async {
    try {
      await _db.transaction(() async {
        final actual = await _filaItem(itemId);
        if (actual == null) throw Exception('La línea ya no existe.');
        await _exigirViva(actual.deudorId);

        final cantidadNueva = cantidad ?? actual.cantidad;
        final delta = cantidadNueva - actual.cantidad;

        // Solo se mueve la diferencia: subir de 2 a 5 saca tres más, bajar de
        // 5 a 2 devuelve tres. Registrar la cantidad entera duplicaría la
        // salida.
        if (delta > 0) {
          await _verificarStock(actual.productoId, delta);
          await _sacarDelInventario(actual.deudorId, actual.productoId, delta);
        } else if (delta < 0) {
          await _devolverAlInventario(
            actual.deudorId,
            actual.productoId,
            -delta,
          );
        }

        await (_db.update(
          _db.tablaDeudorItem,
        )..where((t) => t.id.equals(itemId))).write(
          TablaDeudorItemCompanion(
            cantidad: Value(cantidadNueva),
            precioUnitario: Value(precioUnitario ?? actual.precioUnitario),
          ),
        );

        await _recalcularTotales(actual.deudorId);
      });
      return const Exito();
    } catch (e) {
      return Fallo(MotivoFallo.persistencia, _mensaje(e));
    }
  }

  @override
  Future<Resultado> eliminarItem(int itemId) async {
    try {
      await _db.transaction(() async {
        final actual = await _filaItem(itemId);
        if (actual == null) return;
        await _exigirViva(actual.deudorId);

        await _devolverAlInventario(
          actual.deudorId,
          actual.productoId,
          actual.cantidad,
        );

        await (_db.delete(
          _db.tablaDeudorItem,
        )..where((t) => t.id.equals(itemId))).go();

        await _recalcularTotales(actual.deudorId);
      });
      return const Exito();
    } catch (e) {
      return Fallo(MotivoFallo.persistencia, _mensaje(e));
    }
  }

  // ── Dinero ─────────────────────────────────────────────────────────────────

  @override
  Future<Resultado> registrarPago({
    required int deudorId,
    required int monto,
    required MetodoPago metodoPago,
    String? notas,
  }) async {
    // Este método sí devuelve `Resultado`, así que la falta de permiso viaja
    // como un `Fallo` en vez de una excepción: la vista ya sabe pintarlo.
    if (!puede(Permiso.deudoresCobrar)) {
      return const Fallo(
        MotivoFallo.validacion,
        'Tu cuenta no tiene permiso para recibir pagos. Pídeselo a un '
        'administrador del taller.',
      );
    }

    if (monto <= 0) {
      return const Fallo(
        MotivoFallo.validacion,
        'El abono tiene que ser mayor que cero.',
      );
    }

    final deudor = await _fila(deudorId);
    if (deudor == null) {
      return const Fallo(MotivoFallo.persistencia, 'La deuda ya no existe.');
    }

    final saldo = deudor.montoTotal - deudor.montoPagado;
    if (monto > saldo) {
      return Fallo(
        MotivoFallo.validacion,
        saldo <= 0
            ? 'Esta deuda no tiene saldo por cobrar.'
            : 'Solo faltan $saldo pesos por cobrar de esta deuda.',
      );
    }

    return _envolver(
      () => _db.transaction(() async {
        await _db
            .into(_db.tablaDeudorPago)
            .insert(
              DeudorMapper.pagoACompanion(
                usuarioId: autorId,
                deudorId: deudorId,
                monto: monto,
                metodoPago: metodoPago,
                notas: notas,
              ),
            );
        await _recalcularPagado(deudorId);
      }),
    );
  }

  @override
  Future<Resultado> eliminarPago(int pagoId, int deudorId) {
    return _envolver(
      () => _db.transaction(() async {
        await (_db.delete(
          _db.tablaDeudorPago,
        )..where((t) => t.id.equals(pagoId))).go();
        await _recalcularPagado(deudorId, restaurarActiva: true);
      }),
    );
  }

  @override
  Future<Resultado> cambiarEstado(int id, EstadoDeudor nuevoEstado) async {
    final deudor = await _fila(id);
    if (deudor == null) {
      return const Fallo(MotivoFallo.persistencia, 'La deuda ya no existe.');
    }
    // Marcar como pagada una deuda que no se cobró descuadraría el caché
    // contra la suma de sus pagos, que es justo lo que `descuadres()` afirma
    // que no pasa. Cerrarla se hace cobrando el saldo, no cambiando el estado.
    if (nuevoEstado == EstadoDeudor.pagada &&
        deudor.montoPagado < deudor.montoTotal) {
      return const Fallo(
        MotivoFallo.validacion,
        'Todavía queda saldo: una deuda se da por pagada registrando el '
        'último abono, no cambiándole el estado.',
      );
    }

    // **Dar por perdida no devuelve nada al inventario**, y es la diferencia
    // de fondo con cancelar una reserva: lo apartado sigue en la bodega, lo
    // fiado se fue montado en una moto. Si el cliente no paga, el taller
    // pierde la plata; la pieza ya no está.
    return _envolver(() => _escribirEstado(id, nuevoEstado));
  }

  @override
  Future<Resultado> eliminar(int id) {
    // Borrar la deuda es decir que **nunca existió**, así que sí devuelve lo
    // que sacó: es lo contrario de darla por perdida, que reconoce que la
    // mercancía salió y no vuelve.
    if (!puede(Permiso.deudoresEliminar)) {
      return Future.value(
        const Fallo(
          MotivoFallo.validacion,
          'Tu cuenta no tiene permiso para eliminar deudas. Pídeselo a un '
          'administrador del taller.',
        ),
      );
    }

    return _envolver(
      () => _db.transaction(() async {
        final deudor = await _fila(id);
        if (deudor != null &&
            (deudor.estado == EstadoDeudor.activa.valor ||
                deudor.estado == EstadoDeudor.vencida.valor)) {
          for (final item in await _itemsCrudos(id)) {
            await _devolverAlInventario(id, item.productoId, item.cantidad);
          }
        }
        await (_db.delete(_db.tablaDeudor)..where((t) => t.id.equals(id))).go();

        await _anotar(
          AccionAuditada.elimino,
          id,
          deudor == null ? 'Deuda #$id' : 'Deuda ${deudor.numero}',
          detalle: deudor == null
              ? null
              : 'Saldo al borrarla: ${deudor.montoTotal - deudor.montoPagado}',
        );
      }),
    );
  }

  // ── Descuadres ─────────────────────────────────────────────────────────────

  @override
  Future<Map<int, int>> descuadres() async {
    // Un solo `GROUP BY` contra todas las deudas. El `LEFT JOIN` incluye a las
    // que no tienen ningún pago: si una de esas figura como pagada, también
    // está descuadrada.
    final filas = await _db
        .customSelect(
          '''
      SELECT d.id AS id,
             d.monto_pagado - COALESCE(SUM(p.monto), 0) AS diferencia
      FROM deudores d
      LEFT JOIN deudor_pagos p ON p.deudor_id = d.id
      GROUP BY d.id
      HAVING diferencia <> 0
      ''',
          readsFrom: {_db.tablaDeudor, _db.tablaDeudorPago},
        )
        .get();

    return {
      for (final fila in filas)
        fila.read<int>('id'): fila.read<int>('diferencia'),
    };
  }

  @override
  Future<Map<int, int>> descuadresTotal() async {
    final filas = await _db
        .customSelect(
          '''
      SELECT d.id AS id,
             d.monto_total - COALESCE(
               SUM(CAST(ROUND(i.cantidad * i.precio_unitario) AS INTEGER)), 0
             ) AS diferencia
      FROM deudores d
      LEFT JOIN deudor_items i ON i.deudor_id = d.id
      GROUP BY d.id
      HAVING diferencia <> 0
      ''',
          readsFrom: {_db.tablaDeudor, _db.tablaDeudorItem},
        )
        .get();

    return {
      for (final fila in filas)
        fila.read<int>('id'): fila.read<int>('diferencia'),
    };
  }

  // ── Helpers privados ───────────────────────────────────────────────────────

  static String? _limpio(String? texto) {
    final t = texto?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  Future<TablaDeudorData?> _fila(int id) => (_db.select(
    _db.tablaDeudor,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<TablaDeudorItemData?> _filaItem(int id) => (_db.select(
    _db.tablaDeudorItem,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<TablaDeudorItemData>> _itemsCrudos(int deudorId) => (_db.select(
    _db.tablaDeudorItem,
  )..where((t) => t.deudorId.equals(deudorId))).get();

  /// Una deuda cobrada o dada por perdida no se edita.
  ///
  /// La pagada ya se saldó y la incobrable se cerró con pérdida: tocarles una
  /// línea movería stock de mercancía que salió del taller hace tiempo. La
  /// vista lo refleja apagando los controles; esto es la garantía.
  Future<void> _exigirViva(int deudorId) async {
    final deudor = await _fila(deudorId);
    if (deudor == null) throw Exception('La deuda ya no existe.');
    if (deudor.estado == EstadoDeudor.pagada.valor ||
        deudor.estado == EstadoDeudor.incobrable.valor) {
      throw Exception(
        'La deuda ${deudor.numero} está '
        '${deudor.estado == EstadoDeudor.pagada.valor ? 'pagada' : 'dada por perdida'} '
        'y ya no admite cambios.',
      );
    }
  }

  /// Lanza si no alcanza el stock, con el mensaje que ve el usuario.
  Future<void> _verificarStock(int productoId, double cantidad) async {
    final fila = await _db
        .customSelect(
          'SELECT stock_actual, nombre FROM productos WHERE id = ?',
          variables: [Variable.withInt(productoId)],
        )
        .getSingleOrNull();

    final disponible = (fila?.data['stock_actual'] as num?)?.toDouble() ?? 0;
    if (disponible >= cantidad) return;

    final nombre = fila?.data['nombre'] as String? ?? 'el producto';
    throw Exception(
      'No hay stock de "$nombre": se necesitan ${_cantidad(cantidad)} y '
      'quedan ${_cantidad(disponible)}.',
    );
  }

  /// Fiar **saca la mercancía del taller**. No es una salida contable como la
  /// de una reserva: el repuesto se fue montado en una moto.
  Future<void> _sacarDelInventario(
    int deudorId,
    int productoId,
    double cantidad,
  ) => _inventario.registrar(
    SolicitudMovimiento.salida(
      productoId: productoId,
      cantidad: cantidad,
      tipo: TipoMovimiento.salidaFiado,
      deudorId: deudorId,
    ),
  );

  /// La única entrada legítima: **corregir lo que se anotó mal**. Nada de lo
  /// que el cliente se llevó vuelve solo, así que esto no lo dispara ningún
  /// cambio de estado, solo quitar o bajar una línea.
  Future<void> _devolverAlInventario(
    int deudorId,
    int productoId,
    double cantidad,
  ) => _inventario.registrar(
    SolicitudMovimiento.entrada(
      productoId: productoId,
      cantidad: cantidad,
      tipo: TipoMovimiento.devolucionFiado,
      deudorId: deudorId,
    ),
  );

  static String _cantidad(double valor) =>
      valor % 1 == 0 ? valor.toInt().toString() : valor.toStringAsFixed(2);

  static String _mensaje(Object e) =>
      e.toString().replaceFirst('Exception: ', '');

  /// Recalcula los dos cachés de la deuda y, si hace falta, devuelve plata.
  ///
  /// Se llama cada vez que una línea entra, cambia o sale. Dos cosas que no
  /// son evidentes, y son las mismas de reservas:
  ///
  /// - **La devolución.** Si quitar una línea deja el total por debajo de lo
  ///   que el cliente ya abonó, esa diferencia hay que regresarla. Se escribe
  ///   como un pago negativo —un movimiento más— en vez de corregir los pagos
  ///   viejos, igual que el libro mayor del inventario.
  /// - **Un solo `UPDATE`.** El `CHECK (monto_pagado <= monto_total)` se
  ///   evalúa sobre la fila terminada, así que bajar el total y el pagado en
  ///   la misma escritura pasa; hacerlo en dos, no.
  Future<void> _recalcularTotales(int deudorId) async {
    final total = await _sumaItems(deudorId);
    var pagado = await _sumaPagos(deudorId);

    if (pagado > total) {
      await _db
          .into(_db.tablaDeudorPago)
          .insert(
            DeudorMapper.pagoACompanion(
              usuarioId: autorId,
              deudorId: deudorId,
              monto: total - pagado, // negativo: sale plata
              metodoPago: MetodoPago.efectivo,
              notas: 'Devolución por ajuste de la deuda',
            ),
          );
      pagado = total;
    }

    final estado = pagado >= total && total > 0
        ? EstadoDeudor.pagada
        : await _estadoConSaldo(deudorId);

    await (_db.update(
      _db.tablaDeudor,
    )..where((t) => t.id.equals(deudorId))).write(
      TablaDeudorCompanion(
        montoTotal: Value(total),
        montoPagado: Value(pagado),
        estado: Value(estado.valor),
        actualizadoEn: Value(DateTime.now()),
      ),
    );
  }

  /// Qué estado le toca a una deuda que todavía tiene saldo.
  ///
  /// Solo reabre la que estaba `PAGADA`: agregarle una línea a una deuda
  /// saldada la vuelve a dejar debiendo. Una `VENCIDA` se queda vencida —el
  /// plazo no cambia porque se le anote un repuesto—.
  Future<EstadoDeudor> _estadoConSaldo(int deudorId) async {
    final deudor = await _fila(deudorId);
    if (deudor == null) return EstadoDeudor.activa;
    final actual = EstadoDeudor.desdeValor(deudor.estado);
    return actual == EstadoDeudor.pagada ? EstadoDeudor.activa : actual;
  }

  /// Recalcula el caché `monto_pagado` desde los pagos.
  ///
  /// Se recalcula **entero** en vez de sumarle el abono nuevo al valor
  /// anterior: así no puede desviarse aunque una escritura falle a mitad, y
  /// `descuadres()` puede afirmar que siempre coincide con la suma.
  Future<void> _recalcularPagado(
    int deudorId, {
    bool restaurarActiva = false,
  }) async {
    final deudor = await _fila(deudorId);
    if (deudor == null) return;

    final pagado = await _sumaPagos(deudorId);

    final EstadoDeudor nuevoEstado;
    if (pagado >= deudor.montoTotal && deudor.montoTotal > 0) {
      nuevoEstado = EstadoDeudor.pagada;
    } else if (restaurarActiva && deudor.estado == EstadoDeudor.pagada.valor) {
      nuevoEstado = EstadoDeudor.activa;
    } else {
      nuevoEstado = EstadoDeudor.desdeValor(deudor.estado);
    }

    await (_db.update(
      _db.tablaDeudor,
    )..where((t) => t.id.equals(deudorId))).write(
      TablaDeudorCompanion(
        montoPagado: Value(pagado),
        estado: Value(nuevoEstado.valor),
        actualizadoEn: Value(DateTime.now()),
      ),
    );
  }

  Future<int> _sumaItems(int deudorId) async {
    final fila = await _db
        .customSelect(
          'SELECT COALESCE(SUM(CAST(ROUND(cantidad * precio_unitario) AS INTEGER)), 0) AS s '
          'FROM deudor_items WHERE deudor_id = ?',
          variables: [Variable.withInt(deudorId)],
          readsFrom: {_db.tablaDeudorItem},
        )
        .getSingle();
    return fila.read<int>('s');
  }

  Future<int> _sumaPagos(int deudorId) async {
    final suma = _db.tablaDeudorPago.monto.sum();
    final fila =
        await (_db.selectOnly(_db.tablaDeudorPago)
              ..addColumns([suma])
              ..where(_db.tablaDeudorPago.deudorId.equals(deudorId)))
            .getSingleOrNull();
    return fila?.read(suma) ?? 0;
  }

  Future<void> _escribirEstado(int id, EstadoDeudor estado) =>
      (_db.update(_db.tablaDeudor)..where((t) => t.id.equals(id))).write(
        TablaDeudorCompanion(
          estado: Value(estado.valor),
          actualizadoEn: Value(DateTime.now()),
        ),
      );

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
}
