import '../../../share/consecutivos/documento_consecutivo.dart';
import '../../../share/consecutivos/repositorio_consecutivos.dart';
import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import '../../../../core/iva_app.dart';
import '../enum/enum_cotizacion.dart';
import '../mapper/cotizacion_mapper.dart';
import '../modelo/cotizacion_detalle.dart';
import '../modelo/cotizacion_resumen.dart';
import 'repositorio_cotizaciones.dart';

class RepositorioCotizacionesImpl implements RepositorioCotizaciones {
  RepositorioCotizacionesImpl(this._db);

  final AppDb _db;

  /// Los números de documento salen de la tabla `consecutivos`, no de `MAX+1`
  /// ni del `id`: ver `RepositorioConsecutivos`.
  late final RepositorioConsecutivos _consecutivos =
      RepositorioConsecutivos(_db);

  // ── JOIN base ─────────────────────────────────────────────────────────────

  JoinedSelectStatement<HasResultSet, dynamic> get _baseQuery {
    return _db.select(_db.tablaCotizacion).join([
      leftOuterJoin(
        _db.tablaCliente,
        _db.tablaCliente.id.equalsExp(_db.tablaCotizacion.clienteId),
      ),
      // El nombre y el teléfono del cliente viven en `personas`.
      leftOuterJoin(
        _db.tablaPersona,
        _db.tablaPersona.id.equalsExp(_db.tablaCliente.personaId),
      ),
      leftOuterJoin(
        _db.tablaMoto,
        _db.tablaMoto.id.equalsExp(_db.tablaCotizacion.motoId),
      ),
    ])
      ..addColumns([_cantidadItems]);
  }

  /// Cuántas líneas tiene cada cotización, sin traerlas.
  ///
  /// Va como subconsulta y no como `GROUP BY` para no alterar el `JOIN` ni el
  /// `COUNT` del total de la paginación. El stream no observa
  /// `cotizacion_items`, pero no hace falta: toda ruta que agrega o quita una
  /// línea reescribe también los totales de la cotización, así que la fila
  /// padre cambia y el `watch` vuelve a emitir.
  static const _cantidadItems = CustomExpression<int>(
    '(SELECT COUNT(*) FROM cotizacion_items '
    'WHERE cotizacion_items.cotizacion_id = cotizaciones.id)',
  );

  CotizacionResumen _rowToResumen(TypedResult row) {
    final cot = row.readTable(_db.tablaCotizacion);
    final cli = row.readTableOrNull(_db.tablaPersona);
    final moto = row.readTableOrNull(_db.tablaMoto);

    final nombreCliente = cli != null
        ? '${cli.nombres} ${cli.apellidos ?? ''}'.trim()
        : 'Sin cliente';
    final nombreMoto = moto != null
        ? '${moto.marca} ${moto.modelo}${moto.anio != null ? ' ${moto.anio}' : ''}'
        : 'Sin moto';

    return CotizacionMapper.filaAResumen(
      cot,
      nombreCliente: nombreCliente,
      telefonoCliente: cli?.telefono,
      nombreMoto: nombreMoto,
      cantidadItems: row.read(_cantidadItems) ?? 0,
    );
  }

  // ── Lecturas ──────────────────────────────────────────────────────────────

  @override
  Stream<List<CotizacionResumen>> observarTodas() {
    return (_baseQuery..orderBy(_orden))
        .watch()
        .map((rows) => rows.map(_rowToResumen).toList());
  }

  // ── Paginación — WHERE, COUNT y LIMIT los resuelve SQLite ─────────────────

  /// Días que faltan para que venza, calculado en SQL.
  ///
  /// `vigencia_hasta` es un `DateTime`, y Drift lo guarda como segundos desde
  /// la época; la resta contra la medianoche de hoy y la división por 86400
  /// dan los días. Negativo = vencida.
  ///
  /// Es un `CustomExpression` y no texto suelto a propósito: así se compone
  /// con el resto del query builder —entra en un `where`, en un `count(filter:)`
  /// o en un `sum(filter:)`— en vez de obligar a escribir la consulta entera
  /// a mano. Es la misma regla que `CotizacionResumen.diasParaVencer` aplica
  /// en Dart.
  static final Expression<int> _diasParaVencer = const CustomExpression<int>(
    "CAST((cotizaciones.vigencia_hasta - "
    "unixepoch(date('now', 'localtime'))) / 86400 AS INTEGER)",
  );

  static Expression<bool> _condicionEstado(EstadoCotizacion estado) =>
      switch (estado) {
        EstadoCotizacion.vencida => _diasParaVencer.isSmallerThanValue(0),
        EstadoCotizacion.porVencer => _diasParaVencer.isBetweenValues(0, 3),
        EstadoCotizacion.vigente => _diasParaVencer.isBiggerThanValue(3),
      };

  /// La más reciente primero. El `id` desempata: dos cotizaciones creadas en el
  /// mismo instante tendrían un orden arbitrario, y con `LIMIT`/`OFFSET` eso
  /// hace que una fila salga en dos páginas o en ninguna.
  List<OrderingTerm> get _orden => [
        OrderingTerm.desc(_db.tablaCotizacion.creadoEn),
        OrderingTerm.desc(_db.tablaCotizacion.id),
      ];

  Expression<bool> _condicion(FiltroCotizaciones filtro) {
    Expression<bool> acumulado = const Constant(true);

    final busqueda = filtro.busqueda.trim();
    if (busqueda.isNotEmpty) {
      final patron = '%${busqueda.toLowerCase()}%';
      acumulado = acumulado &
          (_db.tablaCotizacion.numero.lower().like(patron) |
              _db.tablaPersona.nombres.lower().like(patron) |
              _db.tablaPersona.apellidos.lower().like(patron));
    }

    final estado = filtro.estado;
    if (estado != null) {
      acumulado = acumulado & _condicionEstado(estado);
    }

    return acumulado;
  }

  @override
  Stream<PaginaCotizaciones> observarPagina({
    required FiltroCotizaciones filtro,
    required int pagina,
    required int tamano,
  }) {
    final condicion = _condicion(filtro);

    final consultaPagina = _baseQuery
      ..where(condicion)
      ..orderBy(_orden)
      ..limit(tamano, offset: pagina * tamano);

    // El total va en su propia consulta: el `limit` no debe afectarlo. Repite
    // el JOIN porque la búsqueda mira el nombre del cliente.
    final total = _db.tablaCotizacion.id.count();
    final consultaTotal = _db.selectOnly(_db.tablaCotizacion).join([
      leftOuterJoin(
        _db.tablaCliente,
        _db.tablaCliente.id.equalsExp(_db.tablaCotizacion.clienteId),
      ),
      leftOuterJoin(
        _db.tablaPersona,
        _db.tablaPersona.id.equalsExp(_db.tablaCliente.personaId),
      ),
    ])
      ..addColumns([total])
      ..where(condicion);

    return consultaPagina.watch().asyncMap((filas) async {
      final fila = await consultaTotal.getSingleOrNull();
      return PaginaCotizaciones(
        items: filas.map(_rowToResumen).toList(),
        total: fila?.read(total) ?? 0,
      );
    });
  }

  @override
  Stream<ResumenCotizaciones> observarResumen() {
    // Todo en una consulta y con el query builder: antes era SQL crudo con
    // cinco `COUNT(*) FILTER` interpolados a mano, que el analizador no podía
    // revisar y que se rompía en silencio si cambiaba una columna.
    final t = _db.tablaCotizacion;
    final total = t.id.count();
    final vigentes =
        t.id.count(filter: _condicionEstado(EstadoCotizacion.vigente));
    final porVencer =
        t.id.count(filter: _condicionEstado(EstadoCotizacion.porVencer));
    final vencidas =
        t.id.count(filter: _condicionEstado(EstadoCotizacion.vencida));
    // El total de cada cotización es `subtotal - descuento`: no hay columna
    // `total` porque se deduce de esas dos, y el IVA ya va dentro del precio.
    final montoVigente = (t.subtotal - t.descuento)
        .sum(filter: _diasParaVencer.isBiggerOrEqualValue(0));

    final consulta = _db.selectOnly(t)
      ..addColumns([total, vigentes, porVencer, vencidas, montoVigente]);

    return consulta.watchSingleOrNull().map(
          (fila) => (
            total: fila?.read(total) ?? 0,
            vigentes: fila?.read(vigentes) ?? 0,
            porVencer: fila?.read(porVencer) ?? 0,
            vencidas: fila?.read(vencidas) ?? 0,
            montoVigente: fila?.read(montoVigente) ?? 0,
          ),
        );
  }

  @override
  Future<List<CotizacionResumen>> obtenerTodas() async {
    final rows = await (_baseQuery
          ..orderBy([OrderingTerm.desc(_db.tablaCotizacion.creadoEn)]))
        .get();
    return rows.map(_rowToResumen).toList();
  }

  @override
  Future<CotizacionDetalle> obtenerDetalle(int id) async {
    final rows = await (_baseQuery
          ..where(_db.tablaCotizacion.id.equals(id)))
        .get();
    if (rows.isEmpty) throw Exception('Cotización $id no encontrada');

    final resumen = _rowToResumen(rows.first);

    final itemsRows = await (_db.select(_db.tablaCotizacionItem)
          ..where((t) => t.cotizacionId.equals(id))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();

    return CotizacionDetalle(
      resumen: resumen,
      items: itemsRows.map(CotizacionMapper.itemAModelo).toList(),
    );
  }

  // ── Escrituras ────────────────────────────────────────────────────────────
  //
  // Una cotización **no toca el inventario**. Es una propuesta: el stock se
  // compromete recién al pasarla a reserva o al facturarla. Antes `crear` lo
  // descontaba y `actualizar` lo restauraba para volver a descontarlo, pero
  // `eliminar` no lo devolvía nunca: borrar una cotización dejaba el stock
  // hundido para siempre.

  @override
  Future<int> crear({
    int? clienteId,
    int? motoId,
    required DateTime vigenciaHasta,
    String? notas,
    required List<ItemDraft> items,
    int descuento = 0,
  }) {
    return _db.transaction(() async {
      final numero = await _consecutivos.siguiente(DocumentoConsecutivo.cotizacion);
      final subtotal = items.fold(0, (s, d) => s + d.subtotal);
      final rebaja = _recortarDescuento(descuento, subtotal);
      // Los precios ya traen el IVA dentro: se extrae del total, no se suma.
      final iva = ivaIncluidoEn(subtotal - rebaja);

      final id = await _db.into(_db.tablaCotizacion).insert(
            CotizacionMapper.nuevaACompanion(
              numero: numero,
              clienteId: clienteId,
              motoId: motoId,
              subtotal: subtotal,
              descuento: rebaja,
              iva: iva,
              vigenciaHasta: vigenciaHasta,
              notas: notas,
            ),
          );

      for (final draft in items) {
        await _db.into(_db.tablaCotizacionItem).insert(
              CotizacionMapper.itemACompanion(
                cotizacionId: id,
                tipo: draft.tipo,
                referenciaId: draft.referenciaId,
                descripcion: draft.descripcion,
                cantidad: draft.cantidad,
                precioUnitario: draft.precioUnitario,
                subtotal: draft.subtotal,
              ),
            );
      }
      return id;
    });
  }

  @override
  Future<void> actualizar({
    required int id,
    int? clienteId,
    int? motoId,
    required DateTime vigenciaHasta,
    String? notas,
    required List<ItemDraft> items,
    int descuento = 0,
  }) {
    return _db.transaction(() async {
      final subtotal = items.fold(0, (s, d) => s + d.subtotal);
      final rebaja = _recortarDescuento(descuento, subtotal);
      // Los precios ya traen el IVA dentro: se extrae del total, no se suma.
      final iva = ivaIncluidoEn(subtotal - rebaja);
      await (_db.update(_db.tablaCotizacion)..where((t) => t.id.equals(id)))
          .write(TablaCotizacionCompanion(
        clienteId: Value(clienteId),
        motoId: Value(motoId),
        subtotal: Value(subtotal),
        descuento: Value(rebaja),
        iva: Value(iva),
        vigenciaHasta: Value(vigenciaHasta),
        actualizadoEn: Value(DateTime.now()),
        notas: Value(notas),
      ));

      // Los ítems se reemplazan enteros: es más simple que diferenciar altas,
      // bajas y cambios de cantidad, y no hay stock que conciliar.
      await (_db.delete(_db.tablaCotizacionItem)
            ..where((t) => t.cotizacionId.equals(id)))
          .go();
      for (final draft in items) {
        await _db.into(_db.tablaCotizacionItem).insert(
              CotizacionMapper.itemACompanion(
                cotizacionId: id,
                tipo: draft.tipo,
                referenciaId: draft.referenciaId,
                descripcion: draft.descripcion,
                cantidad: draft.cantidad,
                precioUnitario: draft.precioUnitario,
                subtotal: draft.subtotal,
              ),
            );
      }
    });
  }

  @override
  Future<void> eliminar(int id) =>
      (_db.delete(_db.tablaCotizacion)..where((t) => t.id.equals(id))).go();

  @override
  Future<void> agregarItem({
    required int cotizacionId,
    required TipoItemCotizacion tipo,
    int? referenciaId,
    required String descripcion,
    required double cantidad,
    required int precioUnitario,
  }) {
    final subtotal = (cantidad * precioUnitario).round();
    return _db.transaction(() async {
      await _db.into(_db.tablaCotizacionItem).insert(
            CotizacionMapper.itemACompanion(
              cotizacionId: cotizacionId,
              tipo: tipo,
              referenciaId: referenciaId,
              descripcion: descripcion,
              cantidad: cantidad,
              precioUnitario: precioUnitario,
              subtotal: subtotal,
            ),
          );
      await _recalcularTotales(cotizacionId);
    });
  }

  @override
  Future<void> eliminarItem(int itemId, int cotizacionId) {
    return _db.transaction(() async {
      await (_db.delete(_db.tablaCotizacionItem)
            ..where((t) => t.id.equals(itemId)))
          .go();
      await _recalcularTotales(cotizacionId);
    });
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  /// O(1): una sola consulta MAX() en lugar de cargar todas las filas.

  Future<void> _recalcularTotales(int cotizacionId) async {
    final filas = await (_db.select(_db.tablaCotizacionItem)
          ..where((t) => t.cotizacionId.equals(cotizacionId)))
        .get();
    final subtotal = filas.fold(0, (s, i) => s + i.subtotal);

    // Al quitar una línea el subtotal baja, y el descuento que ya estaba
    // guardado puede quedar por encima. Sin recortarlo aquí, el `CHECK`
    // rechazaría el `UPDATE` y quitar una línea fallaría sin explicación.
    final cotizacion = await (_db.select(_db.tablaCotizacion)
          ..where((t) => t.id.equals(cotizacionId)))
        .getSingleOrNull();
    final rebaja = _recortarDescuento(cotizacion?.descuento ?? 0, subtotal);

    await (_db.update(_db.tablaCotizacion)
          ..where((t) => t.id.equals(cotizacionId)))
        .write(TablaCotizacionCompanion(
      subtotal: Value(subtotal),
      descuento: Value(rebaja),
      iva: Value(ivaIncluidoEn(subtotal - rebaja)),
      actualizadoEn: Value(DateTime.now()),
    ));
  }

  /// Deja el descuento entre 0 y el subtotal.
  ///
  /// La validación de verdad es el `CHECK` de la tabla; esto evita llegar a
  /// él, porque su error no se le puede mostrar al usuario.
  static int _recortarDescuento(int valor, int subtotal) =>
      valor < 0 ? 0 : (valor > subtotal ? subtotal : valor);
}
