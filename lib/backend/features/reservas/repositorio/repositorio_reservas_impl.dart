import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import '../enum/enum_reserva.dart';
import '../mapper/reserva_mapper.dart';
import '../modelo/reserva_abono.dart';
import '../modelo/reserva_detalle.dart';
import '../modelo/reserva_item.dart';
import '../modelo/reserva_resumen.dart';
import 'repositorio_reservas.dart';

class RepositorioReservasImpl implements RepositorioReservas {
  const RepositorioReservasImpl(this._db);

  final AppDb _db;

  // ── Join base ──────────────────────────────────────────────────────────────

  JoinedSelectStatement<HasResultSet, dynamic> get _baseQuery {
    return _db.select(_db.tablaReserva).join([
      innerJoin(
        _db.tablaCliente,
        _db.tablaCliente.id.equalsExp(_db.tablaReserva.clienteId),
      ),
      leftOuterJoin(
        _db.tablaMoto,
        _db.tablaMoto.id.equalsExp(_db.tablaReserva.motoId),
      ),
    ]);
  }

  ReservaResumen _filaAResumen(TypedResult row) {
    final r = row.readTable(_db.tablaReserva);
    final cli = row.readTable(_db.tablaCliente);
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
    required String fechaLimite,
    required int totalReserva,
    required List<ItemReservaDraft> items,
    int abonoInicial = 0,
    String metodoPagoInicial = 'Efectivo',
    String? referenciaInicial,
  }) {
    return _db.transaction(() async {
      final numero = await _generarNumero();
      final pagadoAcumulado = abonoInicial.clamp(0, totalReserva);

      final id = await _db.into(_db.tablaReserva).insert(
            ReservaMapper.nuevaACompanion(
              numero: numero,
              clienteId: clienteId,
              motoId: motoId,
              cotizacionId: cotizacionId,
              totalReserva: totalReserva,
              fechaLimite: fechaLimite,
            ).copyWith(pagadoAcumulado: Value(pagadoAcumulado)),
          );

      await _insertarItems(id, items);
      await _descontarStock(items);

      if (abonoInicial > 0) {
        await _db.into(_db.tablaReservaAbono).insert(
              ReservaMapper.abonoACompanion(
                reservaId: id,
                monto: abonoInicial,
                metodoPago: metodoPagoInicial,
                referenciaPago: referenciaInicial,
              ),
            );
      }

      if (pagadoAcumulado >= totalReserva) {
        await _escribirEstado(id, EstadoReserva.completada);
      }

      return id;
    });
  }

  @override
  Future<void> actualizar({
    required int id,
    int? motoId,
    int? cotizacionId,
    required String fechaLimite,
    required int totalReserva,
    required List<ItemReservaDraft> items,
  }) {
    return _db.transaction(() async {
      final anteriores = await _itemsDraft(id);
      await _restaurarStock(anteriores);

      await (_db.update(_db.tablaReserva)..where((t) => t.id.equals(id)))
          .write(TablaReservaCompanion(
        motoId: Value(motoId),
        cotizacionId: Value(cotizacionId),
        fechaLimite: Value(fechaLimite),
        totalReserva: Value(totalReserva),
        actualizadoEn: Value(DateTime.now()),
      ));

      await (_db.delete(_db.tablaReservaItem)
            ..where((t) => t.reservaId.equals(id)))
          .go();

      await _insertarItems(id, items);
      await _descontarStock(items);
    });
  }

  @override
  Future<void> registrarAbono({
    required int reservaId,
    required int monto,
    required String metodoPago,
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
      await _actualizarPagado(reservaId, monto);
    });
  }

  @override
  Future<void> cambiarEstado(int id, EstadoReserva nuevoEstado) async {
    if (nuevoEstado == EstadoReserva.cancelada) {
      await _db.transaction(() async {
        final items = await _itemsDraft(id);
        await _restaurarStock(items);
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
        await _restaurarStock(items);
      }
      await (_db.delete(_db.tablaReserva)..where((t) => t.id.equals(id))).go();
    });
  }

  // ── Helpers privados ───────────────────────────────────────────────────────

  Future<String> _generarNumero() async {
    final anio = DateTime.now().year;
    final prefix = 'RES-$anio-';

    final maxExpr = _db.tablaReserva.numero.max();
    final query = _db.selectOnly(_db.tablaReserva)
      ..addColumns([maxExpr])
      ..where(_db.tablaReserva.numero.like('$prefix%'));

    final row = await query.getSingleOrNull();
    final maxNumero = row?.read(maxExpr);
    final maxSeq = maxNumero != null
        ? (int.tryParse(maxNumero.replaceFirst(prefix, '')) ?? 0)
        : 0;

    return '$prefix${(maxSeq + 1).toString().padLeft(4, '0')}';
  }

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

  Future<void> _descontarStock(List<ItemReservaDraft> items) async {
    for (final draft in items) {
      await _ajustarStock(draft.productoId, -draft.cantidad);
    }
  }

  Future<void> _restaurarStock(List<ItemReservaDraft> items) async {
    for (final draft in items) {
      await _ajustarStock(draft.productoId, draft.cantidad);
    }
  }

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

  Future<void> _ajustarStock(int productoId, double delta) =>
      _db.customUpdate(
        'UPDATE productos SET stock_actual = stock_actual + ?, actualizado_en = ? WHERE id = ?',
        variables: [
          Variable.withReal(delta),
          Variable.withDateTime(DateTime.now()),
          Variable.withInt(productoId),
        ],
        updates: {_db.tablaProducto},
      );

  Future<void> _actualizarPagado(int reservaId, int monto) async {
    final reserva = await (_db.select(_db.tablaReserva)
          ..where((t) => t.id.equals(reservaId)))
        .getSingleOrNull();
    if (reserva == null) return;

    final nuevoPagado =
        (reserva.pagadoAcumulado + monto).clamp(0, reserva.totalReserva);

    await (_db.update(_db.tablaReserva)
          ..where((t) => t.id.equals(reservaId)))
        .write(TablaReservaCompanion(
      pagadoAcumulado: Value(nuevoPagado),
      actualizadoEn: Value(DateTime.now()),
      estado: nuevoPagado >= reserva.totalReserva
          ? const Value('COMPLETADA')
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
