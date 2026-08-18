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

class RepositorioReservasImpl implements RepositorioReservas {
  RepositorioReservasImpl(this._db);

  final AppDb _db;

  /// Los números de documento salen de la tabla `consecutivos`, no de `MAX+1`
  /// ni del `id`: ver `RepositorioConsecutivos`.
  late final RepositorioConsecutivos _consecutivos =
      RepositorioConsecutivos(_db);

  /// Reservar y liberar mueven stock, y eso solo se hace por aquí.
  late final RepositorioInventario _inventario = RepositorioInventarioImpl(_db);

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
    ]);
  }

  ReservaResumen _filaAResumen(TypedResult row) {
    final r = row.readTable(_db.tablaReserva);
    final cli = row.readTable(_db.tablaPersona);
    final moto = row.readTableOrNull(_db.tablaMoto);

    final nombreCliente = '${cli.nombres} ${cli.apellidos ?? ''}'.trim();
    final nombreMoto = moto != null
        ? '${moto.marca} ${moto.modelo}${moto.anio != null ? ' ${moto.anio}' : ''}'
        : null;

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
    return (_baseQuery
          ..orderBy([OrderingTerm.desc(_db.tablaReserva.creadoEn)]))
        .watch()
        .map((rows) => rows.map(_filaAResumen).toList());
  }

  @override
  Future<List<ReservaResumen>> obtenerTodas() async {
    final rows = await (_baseQuery
          ..orderBy([OrderingTerm.desc(_db.tablaReserva.creadoEn)]))
        .get();
    return rows.map(_filaAResumen).toList();
  }

  @override
  Future<ReservaDetalle> obtenerDetalle(int id) async {
    final rows = await (_baseQuery
          ..where(_db.tablaReserva.id.equals(id)))
        .get();
    if (rows.isEmpty) throw Exception('Reserva $id no encontrada');

    final resumen = _filaAResumen(rows.first);
    final items = await _cargarItems(id);
    final abonos = await _cargarAbonos(id);

    return ReservaDetalle(resumen: resumen, items: items, abonos: abonos);
  }

  Future<List<ReservaItem>> _cargarItems(int reservaId) async {
    final filas = await (_db.select(_db.tablaReservaItem).join([
      innerJoin(
        _db.tablaProducto,
        _db.tablaProducto.id.equalsExp(_db.tablaReservaItem.productoId),
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
    final filas = await (_db.select(_db.tablaReservaAbono)
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
    return _db.transaction(() async {
      final id = await _db.into(_db.tablaReserva).insert(
            ReservaMapper.nuevaACompanion(
              numero: await _consecutivos.siguiente(DocumentoConsecutivo.reserva),
              clienteId: clienteId,
              motoId: motoId,
              cotizacionId: cotizacionId,
              totalReserva: totalReserva,
              fechaLimite: fechaLimite,
            ),
          );

      await _insertarItems(id, items);
      await _descontarStock(id, items);

      // El abono inicial es un abono como cualquier otro: entra en la tabla y
      // el caché sale de ahí. Escribir `pagado_acumulado` a mano aquí era la
      // única vía por la que podía desviarse de la suma de los abonos.
      if (abonoInicial > 0) {
        await _db.into(_db.tablaReservaAbono).insert(
              ReservaMapper.abonoACompanion(
                reservaId: id,
                monto: abonoInicial.clamp(1, totalReserva),
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
      final anteriores = await _itemsDraft(id);
      await _restaurarStock(id, anteriores);

      await (_db.update(_db.tablaReserva)..where((t) => t.id.equals(id)))
          .write(TablaReservaCompanion(
        motoId: Value(motoId),
        cotizacionId: Value(cotizacionId),
        fechaLimite: Value(fechaLimite),
        totalReserva: Value(totalReserva),
        estado: const Value('ACTIVA'),
        actualizadoEn: Value(DateTime.now()),
      ));

      await (_db.delete(_db.tablaReservaItem)
            ..where((t) => t.reservaId.equals(id)))
          .go();

      await _insertarItems(id, items);
      await _descontarStock(id, items);
    });
  }

  @override
  Future<void> registrarAbono({
    required int reservaId,
    required int monto,
    required MetodoPago metodoPago,
    String? referenciaPago,
  }) {
    return _db.transaction(() async {
      await _db.into(_db.tablaReservaAbono).insert(
            ReservaMapper.abonoACompanion(
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
    if (nuevoEstado == EstadoReserva.cancelada) {
      await _db.transaction(() async {
        final items = await _itemsDraft(id);
        await _restaurarStock(id, items);
        await _escribirEstado(id, nuevoEstado);
      });
    } else {
      await _escribirEstado(id, nuevoEstado);
    }
  }

  @override
  Future<void> eliminar(int id) async {
    await _db.transaction(() async {
      final items = await _itemsDraft(id);
      final reserva = await (_db.select(_db.tablaReserva)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (reserva != null && reserva.estado == EstadoReserva.activa.valor) {
        await _restaurarStock(id, items);
      }
      await (_db.delete(_db.tablaReserva)..where((t) => t.id.equals(id))).go();
    });
  }

  // ── Helpers privados ───────────────────────────────────────────────────────


  Future<void> _insertarItems(int reservaId, List<ItemReservaDraft> items) async {
    for (final draft in items) {
      await _db.into(_db.tablaReservaItem).insert(
            ReservaMapper.itemACompanion(
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
    final filas = await (_db.select(_db.tablaReservaItem)
          ..where((t) => t.reservaId.equals(reservaId)))
        .get();
    return filas
        .map((f) => ItemReservaDraft(
              productoId: f.productoId,
              cantidad: f.cantidad,
              precioUnitario: f.precioUnitario,
            ))
        .toList();
  }



  @override
  Future<Map<int, int>> descuadres() async {
    // Un solo `GROUP BY` contra todas las reservas. El `LEFT JOIN` incluye a
    // las que no tienen ningún abono: si una de esas figura como pagada,
    // también está descuadrada.
    final filas = await _db.customSelect(
      '''
      SELECT r.id AS id,
             r.pagado_acumulado - COALESCE(SUM(a.monto), 0) AS diferencia
      FROM reservas r
      LEFT JOIN reserva_abonos a ON a.reserva_id = r.id
      GROUP BY r.id
      HAVING diferencia <> 0
      ''',
      readsFrom: {_db.tablaReserva, _db.tablaReservaAbono},
    ).get();

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
    final reserva = await (_db.select(_db.tablaReserva)
          ..where((t) => t.id.equals(reservaId)))
        .getSingleOrNull();
    if (reserva == null) return;

    final suma = _db.tablaReservaAbono.monto.sum();
    final fila = await (_db.selectOnly(_db.tablaReservaAbono)
          ..addColumns([suma])
          ..where(_db.tablaReservaAbono.reservaId.equals(reservaId)))
        .getSingleOrNull();

    final pagado = (fila?.read(suma) ?? 0).clamp(0, reserva.totalReserva);

    await (_db.update(_db.tablaReserva)..where((t) => t.id.equals(reservaId)))
        .write(TablaReservaCompanion(
      pagadoAcumulado: Value(pagado),
      actualizadoEn: Value(DateTime.now()),
      // Quien termina de pagar cierra la reserva sin tener que pedirlo.
      estado: pagado >= reserva.totalReserva
          ? Value(EstadoReserva.completada.valor)
          : const Value.absent(),
    ));
  }

  Future<void> _escribirEstado(int id, EstadoReserva estado) =>
      (_db.update(_db.tablaReserva)..where((t) => t.id.equals(id))).write(
        TablaReservaCompanion(
          estado: Value(estado.valor),
          actualizadoEn: Value(DateTime.now()),
        ),
      );
}
