import '../../motos/repositorio/join_moto.dart';
import '../../../../core/resultado.dart';
import '../../../share/consecutivos/documento_consecutivo.dart';
import '../../../share/consecutivos/repositorio_consecutivos.dart';
import '../../../share/dominio/metodo_pago.dart';
import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import '../../inventario/modelo/movimiento_inventario.dart';
import '../../inventario/repositorio/repositorio_inventario.dart';
import '../../inventario/repositorio/repositorio_inventario_impl.dart';
import '../enum/enum_reserva.dart';
import '../mapper/reserva_mapper.dart';
import '../modelo/reserva_abono.dart';
import '../modelo/reserva_detalle.dart';
import '../modelo/reserva_item.dart';
import '../modelo/reserva_resumen.dart';
import 'repositorio_reservas.dart';
import '../../../share/dominio/sesion_actual.dart';
import '../../bitacora/modelo/entrada_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora_impl.dart';
import '../../../share/dominio/permiso.dart';

class RepositorioReservasImpl
    with FirmaDeSesion
    implements RepositorioReservas {
  RepositorioReservasImpl(this._db, this.sesion);

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
      entidad: EntidadAuditada.reserva,
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

  /// Reservar y liberar mueven stock, y eso solo se hace por aquí.
  late final RepositorioInventario _inventario = RepositorioInventarioImpl(
    _db,
    sesion,
  );

  // ── Join base ──────────────────────────────────────────────────────────────

  JoinedSelectStatement<HasResultSet, dynamic> get _baseQuery {
    return _db.select(_db.tablaReserva).join([
      innerJoin(
        _db.tablaCliente,
        _db.tablaCliente.id.equalsExp(_db.tablaReserva.clienteId),
      ),
      // El nombre del cliente vive en `personas`.
      innerJoin(
        _db.tablaPersona,
        _db.tablaPersona.id.equalsExp(_db.tablaCliente.personaId),
      ),
      leftOuterJoin(
        _db.tablaMoto,
        _db.tablaMoto.id.equalsExp(_db.tablaReserva.motoId),
      ),
      ..._db.joinsCatalogoMoto,
    ]);
  }

  ReservaResumen _filaAResumen(TypedResult row) {
    final r = row.readTable(_db.tablaReserva);
    final cli = row.readTable(_db.tablaPersona);
    final moto = row.readTableOrNull(_db.tablaMoto);

    final nombreCliente = '${cli.nombres} ${cli.apellidos ?? ''}'.trim();
    final nombreMoto = _db.nombreMotoDe(row);

    return ReservaMapper.filaAResumen(
      r,
      nombreCliente: nombreCliente,
      nombreMoto: nombreMoto,
      placaMoto: moto?.placa,
    );
  }

  // ── Lecturas ───────────────────────────────────────────────────────────────

  @override
  Stream<List<ReservaResumen>> observarTodas() {
    exigir(Permiso.reservasVer);
    return (_baseQuery..orderBy([OrderingTerm.desc(_db.tablaReserva.creadoEn)]))
        .watch()
        .map((rows) => rows.map(_filaAResumen).toList());
  }

  @override
  Stream<PaginaReservas> observarPagina({
    required FiltroReservas filtro,
    required int pagina,
    required int tamano,
  }) {
    exigir(Permiso.reservasVer);
    final consulta = _baseQuery
      ..orderBy([OrderingTerm.desc(_db.tablaReserva.creadoEn)]);
    _aplicarFiltro(consulta, filtro);
    consulta.limit(tamano, offset: pagina * tamano);

    // El total va aparte y sin `LIMIT`: es cuántas cumplen el filtro, no
    // cuántas caben en la página.
    final conteo = _db.selectOnly(_db.tablaReserva).join([
      innerJoin(
        _db.tablaCliente,
        _db.tablaCliente.id.equalsExp(_db.tablaReserva.clienteId),
      ),
      innerJoin(
        _db.tablaPersona,
        _db.tablaPersona.id.equalsExp(_db.tablaCliente.personaId),
      ),
    ])..addColumns([_db.tablaReserva.id.count()]);
    _aplicarFiltro(conteo, filtro);

    return consulta.watch().asyncMap((rows) async {
      final fila = await conteo.getSingle();
      return PaginaReservas(
        items: rows.map(_filaAResumen).toList(),
        total: fila.read(_db.tablaReserva.id.count()) ?? 0,
      );
    });
  }

  /// El mismo `WHERE` para la página y para el `COUNT`. Separarlos era la vía
  /// por la que el total podía contar reservas que la página no muestra.
  void _aplicarFiltro(
    JoinedSelectStatement<HasResultSet, dynamic> consulta,
    FiltroReservas filtro,
  ) {
    final estado = filtro.estado;
    if (estado != null) {
      consulta.where(_db.tablaReserva.estado.equals(estado.valor));
    }

    final texto = filtro.busqueda.trim();
    if (texto.isEmpty) return;

    final patron = '%${texto.toLowerCase()}%';
    consulta.where(
      _db.tablaReserva.numero.lower().like(patron) |
          _db.tablaPersona.nombres.lower().like(patron) |
          _db.tablaPersona.apellidos.lower().like(patron),
    );
  }

  @override
  Future<int?> reservaDeCotizacion(int cotizacionId) async {
    exigir(Permiso.reservasVer);
    final fila =
        await (_db.select(_db.tablaReserva)
              ..where((t) => t.cotizacionId.equals(cotizacionId))
              ..limit(1))
            .getSingleOrNull();
    return fila?.id;
  }

  @override
  Future<List<ReservaResumen>> obtenerTodas() async {
    exigir(Permiso.reservasVer);
    final rows =
        await (_baseQuery
              ..orderBy([OrderingTerm.desc(_db.tablaReserva.creadoEn)]))
            .get();
    return rows.map(_filaAResumen).toList();
  }

  @override
  Future<ReservaDetalle> obtenerDetalle(int id) async {
    exigir(Permiso.reservasVer);
    final rows = await (_baseQuery..where(_db.tablaReserva.id.equals(id)))
        .get();
    if (rows.isEmpty) throw Exception('Reserva $id no encontrada');

    final resumen = _filaAResumen(rows.first);
    final items = await _cargarItems(id);
    final abonos = await _cargarAbonos(id);

    return ReservaDetalle(resumen: resumen, items: items, abonos: abonos);
  }

  Future<List<ReservaItem>> _cargarItems(int reservaId) async {
    final filas =
        await (_db.select(_db.tablaReservaItem).join([
                innerJoin(
                  _db.tablaProducto,
                  _db.tablaProducto.id.equalsExp(
                    _db.tablaReservaItem.productoId,
                  ),
                ),
              ])
              ..where(_db.tablaReservaItem.reservaId.equals(reservaId))
              ..orderBy([OrderingTerm.asc(_db.tablaReservaItem.id)]))
            .get();

    return filas.map((row) {
      final item = row.readTable(_db.tablaReservaItem);
      final prod = row.readTable(_db.tablaProducto);
      return ReservaMapper.itemAModelo(
        item,
        nombreProducto: prod.nombre,
        sku: prod.sku,
        imagenUrl: prod.imagenUrl,
      );
    }).toList();
  }

  Future<List<ReservaAbono>> _cargarAbonos(int reservaId) async {
    final filas =
        await (_db.select(_db.tablaReservaAbono)
              ..where((t) => t.reservaId.equals(reservaId))
              ..orderBy([(t) => OrderingTerm.asc(t.fechaPago)]))
            .get();
    return filas.map(ReservaMapper.abonoAModelo).toList();
  }

  // ── Escrituras ─────────────────────────────────────────────────────────────

  @override
  Future<int> crear({
    required int clienteId,
    int? motoId,
    int? cotizacionId,
    required DateTime? fechaLimite,
    required int totalReserva,
    required List<ItemReservaDraft> items,
    int abonoInicial = 0,
    MetodoPago metodoPagoInicial = MetodoPago.efectivo,
    String? referenciaInicial,
  }) {
    exigir(Permiso.reservasCrear);

    return _db.transaction(() async {
      final id = await _db
          .into(_db.tablaReserva)
          .insert(
            ReservaMapper.nuevaACompanion(
              usuarioId: autorId,
              numero: await _consecutivos.siguiente(
                DocumentoConsecutivo.reserva,
              ),
              clienteId: clienteId,
              motoId: motoId,
              cotizacionId: cotizacionId,
              totalReserva: totalReserva,
              fechaLimite: fechaLimite,
            ),
          );

      await _insertarItems(id, items);
      await _descontarStock(id, items);

      // `totalReserva` entró como valor provisional porque la columna es NOT
      // NULL y la fila se inserta antes que sus líneas. El bueno es la suma de
      // las líneas, y lo pone esto: si no, el caché nacería descuadrado.
      await _recalcularTotales(id);
      final total = await _sumaItems(id);

      // El abono inicial es un abono como cualquier otro: entra en la tabla y
      // el caché sale de ahí. Escribir `pagado_acumulado` a mano aquí era la
      // única vía por la que podía desviarse de la suma de los abonos.
      if (abonoInicial > 0 && total > 0) {
        await _db
            .into(_db.tablaReservaAbono)
            .insert(
              ReservaMapper.abonoACompanion(
                usuarioId: autorId,
                reservaId: id,
                monto: abonoInicial.clamp(1, total),
                metodoPago: metodoPagoInicial,
                referenciaPago: referenciaInicial,
              ),
            );
        await _actualizarPagado(id);
      }

      return id;
    });
  }

  @override
  Future<void> actualizar({
    required int id,
    int? motoId,
    int? cotizacionId,
    required DateTime? fechaLimite,
    required int totalReserva,
    required List<ItemReservaDraft> items,
  }) {
    return _db.transaction(() async {
      // Antes esto forzaba `estado: 'ACTIVA'`, así que editar una reserva
      // cancelada la revivía en silencio y le volvía a descontar el stock.
      await _exigirActiva(id);

      final anteriores = await _itemsDraft(id);
      await _restaurarStock(id, anteriores);

      await (_db.update(_db.tablaReserva)..where((t) => t.id.equals(id))).write(
        TablaReservaCompanion(
          motoId: Value(motoId),
          cotizacionId: Value(cotizacionId),
          fechaLimite: Value(fechaLimite),
          actualizadoEn: Value(DateTime.now()),
        ),
      );

      await (_db.delete(
        _db.tablaReservaItem,
      )..where((t) => t.reservaId.equals(id))).go();

      await _insertarItems(id, items);
      await _descontarStock(id, items);

      // El total y la devolución, en un solo sitio para las dos vías de
      // edición: la de a una línea y esta, que reemplaza el documento entero.
      await _recalcularTotales(id);
    });
  }

  // ── Líneas, una a una ──────────────────────────────────────────────────────

  @override
  Future<Resultado> agregarItem({
    required int reservaId,
    required int productoId,
    required double cantidad,
    required int precioUnitario,
  }) async {
    try {
      await _db.transaction(() async {
        await _exigirActiva(reservaId);
        await _verificarStock(productoId, cantidad);

        // Si el producto ya está apartado en esta reserva se suma a su línea,
        // como hace el carrito: dos filas del mismo producto solo complican
        // la lectura y no dicen nada que la cantidad no diga.
        final existente =
            await (_db.select(_db.tablaReservaItem)
                  ..where(
                    (t) =>
                        t.reservaId.equals(reservaId) &
                        t.productoId.equals(productoId),
                  )
                  ..limit(1))
                .getSingleOrNull();

        if (existente == null) {
          await _db
              .into(_db.tablaReservaItem)
              .insert(
                ReservaMapper.itemACompanion(
                  usuarioId: autorId,
                  reservaId: reservaId,
                  productoId: productoId,
                  cantidad: cantidad,
                  precioUnitario: precioUnitario,
                ),
              );
        } else {
          await (_db.update(
            _db.tablaReservaItem,
          )..where((t) => t.id.equals(existente.id))).write(
            TablaReservaItemCompanion(
              cantidad: Value(existente.cantidad + cantidad),
              precioUnitario: Value(precioUnitario),
            ),
          );
        }

        await _descontarStock(reservaId, [
          ItemReservaDraft(
            productoId: productoId,
            cantidad: cantidad,
            precioUnitario: precioUnitario,
          ),
        ]);
        await _recalcularTotales(reservaId);
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
        final actual = await (_db.select(
          _db.tablaReservaItem,
        )..where((t) => t.id.equals(itemId))).getSingleOrNull();
        if (actual == null) throw Exception('La línea ya no existe.');
        await _exigirActiva(actual.reservaId);

        final cantidadNueva = cantidad ?? actual.cantidad;
        final delta = cantidadNueva - actual.cantidad;

        // Solo se mueve la diferencia: subir de 2 a 5 aparta tres más, bajar
        // de 5 a 2 devuelve tres. Registrar la cantidad entera duplicaría la
        // salida.
        if (delta > 0) {
          await _verificarStock(actual.productoId, delta);
          await _descontarStock(actual.reservaId, [
            ItemReservaDraft(
              productoId: actual.productoId,
              cantidad: delta,
              precioUnitario: actual.precioUnitario,
            ),
          ]);
        } else if (delta < 0) {
          await _restaurarStock(actual.reservaId, [
            ItemReservaDraft(
              productoId: actual.productoId,
              cantidad: -delta,
              precioUnitario: actual.precioUnitario,
            ),
          ]);
        }

        await (_db.update(
          _db.tablaReservaItem,
        )..where((t) => t.id.equals(itemId))).write(
          TablaReservaItemCompanion(
            cantidad: Value(cantidadNueva),
            precioUnitario: Value(precioUnitario ?? actual.precioUnitario),
          ),
        );

        await _recalcularTotales(actual.reservaId);
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
        final actual = await (_db.select(
          _db.tablaReservaItem,
        )..where((t) => t.id.equals(itemId))).getSingleOrNull();
        if (actual == null) return;
        await _exigirActiva(actual.reservaId);

        await _restaurarStock(actual.reservaId, [
          ItemReservaDraft(
            productoId: actual.productoId,
            cantidad: actual.cantidad,
            precioUnitario: actual.precioUnitario,
          ),
        ]);

        await (_db.delete(
          _db.tablaReservaItem,
        )..where((t) => t.id.equals(itemId))).go();

        await _recalcularTotales(actual.reservaId);
      });
      return const Exito();
    } catch (e) {
      return Fallo(MotivoFallo.persistencia, _mensaje(e));
    }
  }

  /// Una reserva completada o cancelada no se edita.
  ///
  /// La cancelada ya devolvió su mercancía al inventario y la completada se
  /// entregó: tocarles una línea volvería a mover stock de algo que salió del
  /// taller. La vista lo refleja apagando los controles; esto es la garantía.
  Future<void> _exigirActiva(int reservaId) async {
    final reserva = await (_db.select(
      _db.tablaReserva,
    )..where((t) => t.id.equals(reservaId))).getSingleOrNull();
    if (reserva == null) throw Exception('La reserva ya no existe.');
    if (reserva.estado != EstadoReserva.activa.valor) {
      throw Exception(
        'La reserva ${reserva.numero} está '
        '${reserva.estado == EstadoReserva.cancelada.valor ? 'cancelada' : 'completada'} '
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

  static String _cantidad(double valor) =>
      valor % 1 == 0 ? valor.toInt().toString() : valor.toStringAsFixed(2);

  static String _mensaje(Object e) =>
      e.toString().replaceFirst('Exception: ', '');

  @override
  Future<void> registrarAbono({
    required int reservaId,
    required int monto,
    required MetodoPago metodoPago,
    String? referenciaPago,
  }) {
    exigir(Permiso.reservasAbonar);

    return _db.transaction(() async {
      // El `CHECK (pagado_acumulado <= total_reserva)` también lo impediría,
      // pero su error no se le puede enseñar a nadie. Y desde que el caché ya
      // no se recorta, sin esto la transacción reventaría de verdad.
      final reserva = await (_db.select(
        _db.tablaReserva,
      )..where((t) => t.id.equals(reservaId))).getSingleOrNull();
      if (reserva == null) throw Exception('La reserva ya no existe.');

      final saldo = reserva.totalReserva - reserva.pagadoAcumulado;
      if (monto > saldo) {
        throw Exception(
          'El abono supera el saldo: faltan \$$saldo y se intentó abonar '
          '\$$monto.',
        );
      }

      await _db
          .into(_db.tablaReservaAbono)
          .insert(
            ReservaMapper.abonoACompanion(
              usuarioId: autorId,
              reservaId: reservaId,
              monto: monto,
              metodoPago: metodoPago,
              referenciaPago: referenciaPago,
            ),
          );
      await _actualizarPagado(reservaId);
    });
  }

  @override
  Future<void> cambiarEstado(int id, EstadoReserva nuevoEstado) async {
    // Cancelar es el mismo gesto que eliminar visto desde otro botón: devuelve
    // la mercancía apartada a la bodega. Sin esta línea, quien no podía borrar
    // una reserva la cancelaba y conseguía lo mismo.
    if (nuevoEstado == EstadoReserva.cancelada) {
      exigir(Permiso.reservasEliminar);
    }

    await _db.transaction(() async {
      if (nuevoEstado == EstadoReserva.cancelada) {
        await _restaurarStock(id, await _itemsDraft(id));
      }
      await _escribirEstado(id, nuevoEstado);

      await _anotar(
        nuevoEstado == EstadoReserva.cancelada
            ? AccionAuditada.anulo
            : AccionAuditada.modifico,
        id,
        await _numeroDe(id),
        detalle: 'Estado: ${nuevoEstado.valor}',
      );
    });
  }

  @override
  Future<void> eliminar(int id) async {
    exigir(Permiso.reservasEliminar);
    await _db.transaction(() async {
      final items = await _itemsDraft(id);
      final reserva = await (_db.select(
        _db.tablaReserva,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (reserva != null && reserva.estado == EstadoReserva.activa.valor) {
        await _restaurarStock(id, items);
      }
      await (_db.delete(_db.tablaReserva)..where((t) => t.id.equals(id))).go();

      await _anotar(
        AccionAuditada.elimino,
        id,
        reserva == null ? 'Reserva #$id' : 'Reserva ${reserva.numero}',
      );
    });
  }

  /// El número de una reserva, para nombrarla en la bitácora.
  Future<String> _numeroDe(int id) async {
    final fila = await (_db.select(
      _db.tablaReserva,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return fila == null ? 'Reserva #$id' : 'Reserva ${fila.numero}';
  }

  // ── Helpers privados ───────────────────────────────────────────────────────

  Future<void> _insertarItems(
    int reservaId,
    List<ItemReservaDraft> items,
  ) async {
    for (final draft in items) {
      await _db
          .into(_db.tablaReservaItem)
          .insert(
            ReservaMapper.itemACompanion(
              usuarioId: autorId,
              reservaId: reservaId,
              productoId: draft.productoId,
              cantidad: draft.cantidad,
              precioUnitario: draft.precioUnitario,
            ),
          );
    }
  }

  /// Reservar aparta mercancía: sale del inventario disponible aunque siga en
  /// la bodega. Por eso es un movimiento y no un cálculo aparte.
  Future<void> _descontarStock(int reservaId, List<ItemReservaDraft> items) =>
      _inventario.registrarVarios([
        for (final draft in items)
          SolicitudMovimiento.salida(
            productoId: draft.productoId,
            cantidad: draft.cantidad,
            tipo: TipoMovimiento.salidaReserva,
            reservaId: reservaId,
          ),
      ]);

  Future<void> _restaurarStock(int reservaId, List<ItemReservaDraft> items) =>
      _inventario.registrarVarios([
        for (final draft in items)
          SolicitudMovimiento.entrada(
            productoId: draft.productoId,
            cantidad: draft.cantidad,
            tipo: TipoMovimiento.devolucionReserva,
            reservaId: reservaId,
          ),
      ]);

  Future<List<ItemReservaDraft>> _itemsDraft(int reservaId) async {
    final filas = await (_db.select(
      _db.tablaReservaItem,
    )..where((t) => t.reservaId.equals(reservaId))).get();
    return filas
        .map(
          (f) => ItemReservaDraft(
            productoId: f.productoId,
            cantidad: f.cantidad,
            precioUnitario: f.precioUnitario,
          ),
        )
        .toList();
  }

  @override
  Future<Map<int, int>> descuadres() async {
    // Un solo `GROUP BY` contra todas las reservas. El `LEFT JOIN` incluye a
    // las que no tienen ningún abono: si una de esas figura como pagada,
    // también está descuadrada.
    final filas = await _db
        .customSelect(
          '''
      SELECT r.id AS id,
             r.pagado_acumulado - COALESCE(SUM(a.monto), 0) AS diferencia
      FROM reservas r
      LEFT JOIN reserva_abonos a ON a.reserva_id = r.id
      GROUP BY r.id
      HAVING diferencia <> 0
      ''',
          readsFrom: {_db.tablaReserva, _db.tablaReservaAbono},
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
      SELECT r.id AS id,
             r.total_reserva - COALESCE(
               SUM(CAST(ROUND(i.cantidad * i.precio_unitario) AS INTEGER)), 0
             ) AS diferencia
      FROM reservas r
      LEFT JOIN reserva_items i ON i.reserva_id = r.id
      GROUP BY r.id
      HAVING diferencia <> 0
      ''',
          readsFrom: {_db.tablaReserva, _db.tablaReservaItem},
        )
        .get();

    return {
      for (final fila in filas)
        fila.read<int>('id'): fila.read<int>('diferencia'),
    };
  }

  /// Recalcula el caché `pagado_acumulado` desde los abonos.
  ///
  /// Se recalcula entero en vez de sumarle el abono nuevo al valor anterior:
  /// así el caché no puede desviarse aunque una escritura falle a mitad, y
  /// `descuadres()` puede afirmar que siempre coincide con la suma.
  Future<void> _actualizarPagado(int reservaId) async {
    final reserva = await (_db.select(
      _db.tablaReserva,
    )..where((t) => t.id.equals(reservaId))).getSingleOrNull();
    if (reserva == null) return;

    final suma = _db.tablaReservaAbono.monto.sum();
    final fila =
        await (_db.selectOnly(_db.tablaReservaAbono)
              ..addColumns([suma])
              ..where(_db.tablaReservaAbono.reservaId.equals(reservaId)))
            .getSingleOrNull();

    // Sin `clamp`: recortar aquí dejaba el caché por debajo de la suma real de
    // los abonos y `descuadres()` lo delataba para siempre. Que no se pueda
    // recibir de más lo garantiza `registrarAbono`, que lo rechaza antes.
    final pagado = fila?.read(suma) ?? 0;

    await (_db.update(
      _db.tablaReserva,
    )..where((t) => t.id.equals(reservaId))).write(
      TablaReservaCompanion(
        pagadoAcumulado: Value(pagado),
        actualizadoEn: Value(DateTime.now()),
      ),
    );
  }

  /// Recalcula los dos cachés de la reserva y, si hace falta, devuelve plata.
  ///
  /// Se llama cada vez que una línea entra, cambia o sale. Dos cosas que no
  /// son evidentes:
  ///
  /// - **La devolución.** Si quitar mercancía deja el total por debajo de lo
  ///   que el cliente ya entregó, esa diferencia hay que regresarla. Se
  ///   escribe como un abono negativo —un movimiento más— en vez de corregir
  ///   los abonos viejos, igual que el libro mayor del inventario.
  /// - **Un solo `UPDATE`.** El `CHECK (pagado_acumulado <= total_reserva)` se
  ///   evalúa sobre la fila terminada, así que bajar el total y el pagado en
  ///   la misma escritura pasa; hacerlo en dos, no.
  Future<void> _recalcularTotales(int reservaId) async {
    final total = await _sumaItems(reservaId);
    var pagado = await _sumaAbonos(reservaId);

    if (pagado > total) {
      await _db
          .into(_db.tablaReservaAbono)
          .insert(
            ReservaMapper.abonoACompanion(
              usuarioId: autorId,
              reservaId: reservaId,
              monto: total - pagado, // negativo: sale plata
              metodoPago: MetodoPago.efectivo,
              referenciaPago: 'Devolución por ajuste de la reserva',
            ),
          );
      pagado = total;
    }

    await (_db.update(
      _db.tablaReserva,
    )..where((t) => t.id.equals(reservaId))).write(
      TablaReservaCompanion(
        totalReserva: Value(total),
        pagadoAcumulado: Value(pagado),
        actualizadoEn: Value(DateTime.now()),
      ),
    );
  }

  Future<int> _sumaItems(int reservaId) async {
    final fila = await _db
        .customSelect(
          'SELECT COALESCE(SUM(CAST(ROUND(cantidad * precio_unitario) AS INTEGER)), 0) AS s '
          'FROM reserva_items WHERE reserva_id = ?',
          variables: [Variable.withInt(reservaId)],
          readsFrom: {_db.tablaReservaItem},
        )
        .getSingle();
    return fila.read<int>('s');
  }

  Future<int> _sumaAbonos(int reservaId) async {
    final suma = _db.tablaReservaAbono.monto.sum();
    final fila =
        await (_db.selectOnly(_db.tablaReservaAbono)
              ..addColumns([suma])
              ..where(_db.tablaReservaAbono.reservaId.equals(reservaId)))
            .getSingleOrNull();
    return fila?.read(suma) ?? 0;
  }

  Future<void> _escribirEstado(int id, EstadoReserva estado) =>
      (_db.update(_db.tablaReserva)..where((t) => t.id.equals(id))).write(
        TablaReservaCompanion(
          estado: Value(estado.valor),
          actualizadoEn: Value(DateTime.now()),
        ),
      );
}
