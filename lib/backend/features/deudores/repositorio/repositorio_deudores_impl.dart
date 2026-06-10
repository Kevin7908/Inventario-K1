import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import '../enum/enum_deudor.dart';
import '../mapper/deudor_mapper.dart';
import '../modelo/deudor_detalle.dart';
import '../modelo/deudor_pago.dart';
import '../modelo/deudor_resumen.dart';
import 'repositorio_deudores.dart';

class RepositorioDeudoresImpl implements RepositorioDeudores {
  const RepositorioDeudoresImpl(this._db);

  final AppDb _db;

  // ── Join base ──────────────────────────────────────────────────────────────

  JoinedSelectStatement<HasResultSet, dynamic> get _baseQuery {
    return _db.select(_db.tablaDeudor).join([
      innerJoin(
        _db.tablaCliente,
        _db.tablaCliente.id.equalsExp(_db.tablaDeudor.clienteId),
      ),
    ]);
  }

  DeudorResumen _filaAResumen(TypedResult row) {
    final d = row.readTable(_db.tablaDeudor);
    final cli = row.readTable(_db.tablaCliente);
    final nombreCliente = '${cli.nombres} ${cli.apellidos ?? ''}'.trim();
    return DeudorMapper.filaAResumen(d, nombreCliente: nombreCliente);
  }

  // ── Lecturas ───────────────────────────────────────────────────────────────

  @override
  Stream<List<DeudorResumen>> observarTodas() {
    return (_baseQuery
          ..orderBy([OrderingTerm.desc(_db.tablaDeudor.creadoEn)]))
        .watch()
        .map((rows) => rows.map(_filaAResumen).toList());
  }

  @override
  Future<List<DeudorResumen>> obtenerTodas() async {
    final rows = await (_baseQuery
          ..orderBy([OrderingTerm.desc(_db.tablaDeudor.creadoEn)]))
        .get();
    return rows.map(_filaAResumen).toList();
  }

  @override
  Future<DeudorDetalle> obtenerDetalle(int id) async {
    final rows = await (_baseQuery
          ..where(_db.tablaDeudor.id.equals(id)))
        .get();
    if (rows.isEmpty) throw Exception('Deudor $id no encontrado');

    final resumen = _filaAResumen(rows.first);
    final pagos = await _cargarPagos(id);
    return DeudorDetalle(resumen: resumen, pagos: pagos);
  }

  Future<List<DeudorPago>> _cargarPagos(int deudorId) async {
    final filas = await (_db.select(_db.tablaDeudorPago)
          ..where((t) => t.deudorId.equals(deudorId))
          ..orderBy([(t) => OrderingTerm.asc(t.fechaPago)]))
        .get();
    return filas.map(DeudorMapper.pagoAModelo).toList();
  }

  // ── Escrituras ─────────────────────────────────────────────────────────────

  @override
  Future<int> crear({
    required int clienteId,
    int? ventaId,
    required String concepto,
    required int montoTotal,
    String? fechaVencimiento,
    String? notas,
    int pagoInicial = 0,
    String metodoPagoInicial = 'Efectivo',
    String? notasPagoInicial,
  }) {
    return _db.transaction(() async {
      final numero = await _generarNumero();
      final montoPagadoInicial = pagoInicial.clamp(0, montoTotal);

      final id = await _db.into(_db.tablaDeudor).insert(
            DeudorMapper.nuevaACompanion(
              numero: numero,
              clienteId: clienteId,
              ventaId: ventaId,
              concepto: concepto,
              montoTotal: montoTotal,
              fechaVencimiento: fechaVencimiento,
              notas: notas,
            ).copyWith(montoPagado: Value(montoPagadoInicial)),
          );

      if (pagoInicial > 0) {
        await _db.into(_db.tablaDeudorPago).insert(
              DeudorMapper.pagoACompanion(
                deudorId: id,
                monto: montoPagadoInicial,
                metodoPago: metodoPagoInicial,
                notas: notasPagoInicial,
              ),
            );
      }

      if (montoPagadoInicial >= montoTotal) {
        await _escribirEstado(id, EstadoDeudor.pagada);
      }

      return id;
    });
  }

  @override
  Future<void> actualizar({
    required int id,
    int? ventaId,
    required String concepto,
    required int montoTotal,
    String? fechaVencimiento,
    String? notas,
    required EstadoDeudor estado,
  }) async {
    await (_db.update(_db.tablaDeudor)..where((t) => t.id.equals(id))).write(
      TablaDeudorCompanion(
        ventaId: Value(ventaId),
        concepto: Value(concepto),
        montoTotal: Value(montoTotal),
        fechaVencimiento: Value(fechaVencimiento),
        notas: Value(notas),
        estado: Value(estado.valor),
        actualizadoEn: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> registrarPago({
    required int deudorId,
    required int monto,
    required String metodoPago,
    String? notas,
  }) {
    return _db.transaction(() async {
      await _db.into(_db.tablaDeudorPago).insert(
            DeudorMapper.pagoACompanion(
              deudorId: deudorId,
              monto: monto,
              metodoPago: metodoPago,
              notas: notas,
            ),
          );
      await _recalcularPagado(deudorId);
    });
  }

  @override
  Future<void> eliminarPago(int pagoId, int deudorId) {
    return _db.transaction(() async {
      await (_db.delete(_db.tablaDeudorPago)
            ..where((t) => t.id.equals(pagoId)))
          .go();
      await _recalcularPagado(deudorId, restaurarActiva: true);
    });
  }

  @override
  Future<void> cambiarEstado(int id, EstadoDeudor nuevoEstado) =>
      _escribirEstado(id, nuevoEstado);

  @override
  Future<void> eliminar(int id) async {
    await (_db.delete(_db.tablaDeudor)..where((t) => t.id.equals(id))).go();
  }

  // ── Helpers privados ───────────────────────────────────────────────────────

  Future<String> _generarNumero() async {
    const prefix = 'DEU-';
    final maxExpr = _db.tablaDeudor.numero.max();
    final query = _db.selectOnly(_db.tablaDeudor)
      ..addColumns([maxExpr])
      ..where(_db.tablaDeudor.numero.like('$prefix%'));

    final row = await query.getSingleOrNull();
    final maxNumero = row?.read(maxExpr);
    final maxSeq = maxNumero != null
        ? (int.tryParse(maxNumero.replaceFirst(prefix, '')) ?? 0)
        : 0;
    return '$prefix${(maxSeq + 1).toString().padLeft(3, '0')}';
  }

  Future<void> _recalcularPagado(int deudorId, {bool restaurarActiva = false}) async {
    final deudor = await (_db.select(_db.tablaDeudor)
          ..where((t) => t.id.equals(deudorId)))
        .getSingleOrNull();
    if (deudor == null) return;

    final sumExpr = _db.tablaDeudorPago.monto.sum();
    final sumQuery = _db.selectOnly(_db.tablaDeudorPago)
      ..addColumns([sumExpr])
      ..where(_db.tablaDeudorPago.deudorId.equals(deudorId));
    final sumRow = await sumQuery.getSingleOrNull();
    final nuevoPagado = (sumRow?.read(sumExpr) ?? 0).clamp(0, deudor.montoTotal);

    EstadoDeudor nuevoEstado;
    if (nuevoPagado >= deudor.montoTotal) {
      nuevoEstado = EstadoDeudor.pagada;
    } else if (restaurarActiva && deudor.estado == EstadoDeudor.pagada.valor) {
      nuevoEstado = EstadoDeudor.activa;
    } else {
      nuevoEstado = EstadoDeudor.desdeValor(deudor.estado);
    }

    await (_db.update(_db.tablaDeudor)..where((t) => t.id.equals(deudorId)))
        .write(TablaDeudorCompanion(
      montoPagado: Value(nuevoPagado),
      estado: Value(nuevoEstado.valor),
      actualizadoEn: Value(DateTime.now()),
    ));
  }

  Future<void> _escribirEstado(int id, EstadoDeudor estado) =>
      (_db.update(_db.tablaDeudor)..where((t) => t.id.equals(id))).write(
        TablaDeudorCompanion(
          estado: Value(estado.valor),
          actualizadoEn: Value(DateTime.now()),
        ),
      );
}
