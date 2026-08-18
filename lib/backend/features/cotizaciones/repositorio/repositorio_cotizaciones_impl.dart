import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import '../../../../core/iva_app.dart';
import '../enum/enum_cotizacion.dart';
import '../mapper/cotizacion_mapper.dart';
import '../modelo/cotizacion_detalle.dart';
import '../modelo/cotizacion_resumen.dart';
import 'repositorio_cotizaciones.dart';

class RepositorioCotizacionesImpl implements RepositorioCotizaciones {
  const RepositorioCotizacionesImpl(this._db);

  final AppDb _db;

  // ── JOIN base ─────────────────────────────────────────────────────────────

  JoinedSelectStatement<HasResultSet, dynamic> get _baseQuery {
    return _db.select(_db.tablaCotizacion).join([
      leftOuterJoin(
        _db.tablaCliente,
        _db.tablaCliente.id.equalsExp(_db.tablaCotizacion.clienteId),
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
    final cli = row.readTableOrNull(_db.tablaCliente);
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

  /// Días que faltan para que venza, en SQL.
  ///
  /// `vigencia_hasta` es texto 'YYYY-MM-DD', así que se compara con
  /// `julianday`: negativo = vencida, 0..3 = por vencer, más = vigente. Es la
  /// misma regla que `CotizacionResumen.estado` aplica en Dart, pero aquí
  /// puede entrar en el `WHERE` y en el `COUNT`.
  static const _diasParaVencer =
      "CAST(julianday(cotizaciones.vigencia_hasta) - julianday(date('now')) AS INTEGER)";

  static String _condicionEstado(EstadoCotizacion estado) => switch (estado) {
        EstadoCotizacion.vencida => '$_diasParaVencer < 0',
        EstadoCotizacion.porVencer => '$_diasParaVencer BETWEEN 0 AND 3',
        EstadoCotizacion.vigente => '$_diasParaVencer > 3',
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
              _db.tablaCliente.nombres.lower().like(patron) |
              _db.tablaCliente.apellidos.lower().like(patron));
    }

    final estado = filtro.estado;
    if (estado != null) {
      acumulado = acumulado & CustomExpression<bool>(_condicionEstado(estado));
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
    return _db
        .customSelect(
          '''
          SELECT
            COUNT(*) AS total,
            COUNT(*) FILTER (WHERE ${_condicionEstado(EstadoCotizacion.vigente)})
              AS vigentes,
            COUNT(*) FILTER (WHERE ${_condicionEstado(EstadoCotizacion.porVencer)})
              AS por_vencer,
            COUNT(*) FILTER (WHERE ${_condicionEstado(EstadoCotizacion.vencida)})
              AS vencidas,
            COALESCE(SUM(total) FILTER (WHERE $_diasParaVencer >= 0), 0)
              AS monto_vigente
          FROM cotizaciones
          ''',
          readsFrom: {_db.tablaCotizacion},
        )
        .watchSingleOrNull()
        .map(
          (fila) => (
            total: fila?.read<int>('total') ?? 0,
            vigentes: fila?.read<int>('vigentes') ?? 0,
            porVencer: fila?.read<int>('por_vencer') ?? 0,
            vencidas: fila?.read<int>('vencidas') ?? 0,
            montoVigente: fila?.read<int>('monto_vigente') ?? 0,
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
    required String vigenciaHasta,
    String? notas,
    required List<ItemDraft> items,
  }) {
    return _db.transaction(() async {
      final numero = await _generarNumero();
      final subtotal = items.fold(0, (s, d) => s + d.subtotal);
      final iva = ivaDe(subtotal);
      final total = subtotal + iva;

      final id = await _db.into(_db.tablaCotizacion).insert(
            CotizacionMapper.nuevaACompanion(
              numero: numero,
              clienteId: clienteId,
              motoId: motoId,
              subtotal: subtotal,
              iva: iva,
              total: total,
              vigenciaHasta: vigenciaHasta,
              notas: notas,
            ),
          );

      for (final draft in items) {
        await _db.into(_db.tablaCotizacionItem).insert(
              CotizacionMapper.itemACompanion(
                cotizacionId: id,
                tipoItem: draft.tipo.valor,
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
    required String vigenciaHasta,
    String? notas,
    required List<ItemDraft> items,
  }) {
    return _db.transaction(() async {
      final subtotal = items.fold(0, (s, d) => s + d.subtotal);
      final iva = ivaDe(subtotal);
      final total = subtotal + iva;
      await (_db.update(_db.tablaCotizacion)..where((t) => t.id.equals(id)))
          .write(TablaCotizacionCompanion(
        clienteId: Value(clienteId),
        motoId: Value(motoId),
        subtotal: Value(subtotal),
        iva: Value(iva),
        total: Value(total),
        vigenciaHasta: Value(vigenciaHasta),
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
                tipoItem: draft.tipo.valor,
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
              tipoItem: tipo.valor,
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
  Future<String> _generarNumero() async {
    final anio = DateTime.now().year;
    final prefix = 'COT-$anio-';

    final maxExpr = _db.tablaCotizacion.numero.max();
    final query = _db.selectOnly(_db.tablaCotizacion)
      ..addColumns([maxExpr])
      ..where(_db.tablaCotizacion.numero.like('$prefix%'));

    final row = await query.getSingleOrNull();
    final maxNumero = row?.read(maxExpr);
    final maxSeq = maxNumero != null
        ? (int.tryParse(maxNumero.replaceFirst(prefix, '')) ?? 0)
        : 0;

    return '$prefix${(maxSeq + 1).toString().padLeft(4, '0')}';
  }

  Future<void> _recalcularTotales(int cotizacionId) async {
    final filas = await (_db.select(_db.tablaCotizacionItem)
          ..where((t) => t.cotizacionId.equals(cotizacionId)))
        .get();
    final subtotal = filas.fold(0, (s, i) => s + i.subtotal);
    final iva = ivaDe(subtotal);
    final total = subtotal + iva;
    await (_db.update(_db.tablaCotizacion)
          ..where((t) => t.id.equals(cotizacionId)))
        .write(TablaCotizacionCompanion(
      subtotal: Value(subtotal),
      iva: Value(iva),
      total: Value(total),
    ));
  }
}
