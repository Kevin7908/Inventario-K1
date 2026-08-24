import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import '../../../../core/resultado.dart';
import '../../../share/consecutivos/documento_consecutivo.dart';
import '../../../share/consecutivos/repositorio_consecutivos.dart';
import '../../../share/dominio/metodo_pago.dart';
import '../enum/enum_deudor.dart';
import '../mapper/deudor_mapper.dart';
import '../modelo/deudor_detalle.dart';
import '../modelo/deudor_pago.dart';
import '../modelo/deudor_resumen.dart';
import 'repositorio_deudores.dart';

class RepositorioDeudoresImpl implements RepositorioDeudores {
  RepositorioDeudoresImpl(this._db);

  final AppDb _db;

  /// Los números de documento salen de la tabla `consecutivos`, no de `MAX+1`
  /// ni del `id`: ver `RepositorioConsecutivos`.
  late final RepositorioConsecutivos _consecutivos =
      RepositorioConsecutivos(_db);

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
    ]);
  }

  DeudorResumen _filaAResumen(TypedResult row) {
    final d = row.readTable(_db.tablaDeudor);
    final cli = row.readTable(_db.tablaPersona);
    final nombreCliente = '${cli.nombres} ${cli.apellidos ?? ''}'.trim();
    return DeudorMapper.filaAResumen(d, nombreCliente: nombreCliente);
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
      innerJoin(_db.tablaCliente,
          _db.tablaCliente.id.equalsExp(_db.tablaDeudor.clienteId)),
      innerJoin(_db.tablaPersona,
          _db.tablaPersona.id.equalsExp(_db.tablaCliente.personaId)),
    ])
      ..addColumns([_db.tablaDeudor.id.count()]);
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
    final pagadas =
        t.id.count(filter: t.estado.equals(EstadoDeudor.pagada.valor));

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
    required String concepto,
    required int montoTotal,
    DateTime? fechaVencimiento,
    String? notas,
    int pagoInicial = 0,
    MetodoPago metodoPagoInicial = MetodoPago.efectivo,
    String? notasPagoInicial,
  }) {
    return _db.transaction(() async {
      final numero = await _consecutivos.siguiente(DocumentoConsecutivo.deuda);
      final montoPagadoInicial = pagoInicial.clamp(0, montoTotal);

      final id = await _db.into(_db.tablaDeudor).insert(
            DeudorMapper.nuevaACompanion(
              numero: numero,
              clienteId: clienteId,
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
  Future<Resultado> actualizar({
    required int id,
    required String concepto,
    required int montoTotal,
    DateTime? fechaVencimiento,
    String? notas,
  }) async {
    if (concepto.trim().isEmpty) {
      return const Fallo(MotivoFallo.validacion, 'La deuda necesita un concepto.');
    }
    if (montoTotal <= 0) {
      return const Fallo(
        MotivoFallo.validacion,
        'El monto de la deuda tiene que ser mayor que cero.',
      );
    }

    final deudor = await _fila(id);
    if (deudor == null) {
      return const Fallo(MotivoFallo.persistencia, 'La deuda ya no existe.');
    }
    if (montoTotal < deudor.montoPagado) {
      return Fallo(
        MotivoFallo.validacion,
        'El cliente ya entregó ${deudor.montoPagado} pesos: la deuda no puede '
        'quedar por debajo de eso.',
      );
    }

    return _envolver(() async {
      await _db.transaction(() async {
        await (_db.update(_db.tablaDeudor)..where((t) => t.id.equals(id))).write(
          TablaDeudorCompanion(
            concepto: Value(concepto.trim()),
            montoTotal: Value(montoTotal),
            fechaVencimiento: Value(fechaVencimiento),
            notas: Value(notas),
            actualizadoEn: Value(DateTime.now()),
          ),
        );
        // Subir el monto reabre una deuda que había quedado saldada; bajarlo
        // hasta lo ya cobrado la cierra. En los dos casos lo decide la suma de
        // los pagos, no quien editó la cabecera.
        await _recalcularPagado(id, restaurarActiva: true);
      });
    });
  }

  @override
  Future<Resultado> registrarPago({
    required int deudorId,
    required int monto,
    required MetodoPago metodoPago,
    String? notas,
  }) async {
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
        'Solo faltan $saldo pesos por cobrar de esta deuda.',
      );
    }

    return _envolver(() => _db.transaction(() async {
          await _db.into(_db.tablaDeudorPago).insert(
                DeudorMapper.pagoACompanion(
                  deudorId: deudorId,
                  monto: monto,
                  metodoPago: metodoPago,
                  notas: notas,
                ),
              );
          await _recalcularPagado(deudorId);
        }));
  }

  @override
  Future<Resultado> eliminarPago(int pagoId, int deudorId) {
    return _envolver(() => _db.transaction(() async {
          await (_db.delete(_db.tablaDeudorPago)
                ..where((t) => t.id.equals(pagoId)))
              .go();
          await _recalcularPagado(deudorId, restaurarActiva: true);
        }));
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

    return _envolver(() => _escribirEstado(id, nuevoEstado));
  }

  @override
  Future<Resultado> eliminar(int id) =>
      _envolver(() =>
          (_db.delete(_db.tablaDeudor)..where((t) => t.id.equals(id))).go());

  // ── Helpers privados ───────────────────────────────────────────────────────

  @override
  Future<Map<int, int>> descuadres() async {
    // Un solo `GROUP BY` contra todas las deudas. El `LEFT JOIN` incluye a las
    // que no tienen ningún pago: si una de esas figura como pagada, también
    // está descuadrada.
    final filas = await _db.customSelect(
      '''
      SELECT d.id AS id,
             d.monto_pagado - COALESCE(SUM(p.monto), 0) AS diferencia
      FROM deudores d
      LEFT JOIN deudor_pagos p ON p.deudor_id = d.id
      GROUP BY d.id
      HAVING diferencia <> 0
      ''',
      readsFrom: {_db.tablaDeudor, _db.tablaDeudorPago},
    ).get();

    return {
      for (final fila in filas)
        fila.read<int>('id'): fila.read<int>('diferencia'),
    };
  }

  Future<TablaDeudorData?> _fila(int id) =>
      (_db.select(_db.tablaDeudor)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  /// El caché se **recalcula entero** desde los pagos, nunca sumándole el
  /// delta al valor anterior: así no se desvía aunque una escritura falle a
  /// mitad (§7 de `REGLAS_BD.md`).
  Future<void> _recalcularPagado(
    int deudorId, {
    bool restaurarActiva = false,
  }) async {
    final deudor = await _fila(deudorId);
    if (deudor == null) return;

    final sumExpr = _db.tablaDeudorPago.monto.sum();
    final sumQuery = _db.selectOnly(_db.tablaDeudorPago)
      ..addColumns([sumExpr])
      ..where(_db.tablaDeudorPago.deudorId.equals(deudorId));
    final sumRow = await sumQuery.getSingleOrNull();
    final nuevoPagado = (sumRow?.read(sumExpr) ?? 0).clamp(0, deudor.montoTotal);

    final EstadoDeudor nuevoEstado;
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

  /// Traduce lo que SQLite rechace a un [Fallo] tipado. Las reglas que tienen
  /// mensaje propio ya se comprobaron antes: aquí solo queda lo imprevisto.
  Future<Resultado> _envolver(Future<void> Function() operacion) async {
    try {
      await operacion();
      return const Exito();
    } catch (e) {
      return Fallo(MotivoFallo.persistencia, 'No se pudo guardar: $e');
    }
  }
}
