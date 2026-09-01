import 'package:drift/drift.dart';

import '../../../../core/iva_app.dart';
import '../../../share/consecutivos/documento_consecutivo.dart';
import '../../../share/consecutivos/repositorio_consecutivos.dart';
import '../../../share/database/app_db.dart';
import '../../inventario/modelo/movimiento_inventario.dart';
import '../../inventario/repositorio/repositorio_inventario.dart';
import '../../inventario/repositorio/repositorio_inventario_impl.dart';
import '../enum/enum_ventas.dart';
import '../mapper/ventas_mapper.dart';
import '../modelo/linea_venta_mostrador.dart';
import '../modelo/venta_detalle.dart';
import '../modelo/venta_resumen.dart';
import 'repositorio_ventas.dart';
import '../../../share/dominio/sesion_actual.dart';
import '../../bitacora/modelo/entrada_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora_impl.dart';
import '../../../share/dominio/permiso.dart';

class RepositorioVentasImpl with FirmaDeSesion implements RepositorioVentas {
  RepositorioVentasImpl(this._db, this.sesion);

  /// Quién firma lo que este repositorio escribe. La inyecta Riverpod
  /// desde `sesionActualProvider`: es una dependencia del constructor, no
  /// un registro global que se consulte por dentro.
  @override
  final SesionActual? sesion;

  late final RepositorioBitacora _bitacora =
      RepositorioBitacoraImpl(_db, sesion);

  /// Deja el renglón de la bitácora, **dentro** de la transacción del cambio.
  Future<void> _anotar(
    AccionAuditada accion,
    int? id,
    String descripcion, {
    String? detalle,
  }) =>
      _bitacora.anotar(
        Anotacion(
          entidad: EntidadAuditada.venta,
          accion: accion,
          entidadId: id,
          descripcion: descripcion,
          detalle: detalle,
        ),
      );


  final AppDb _db;

  /// El número de la venta sale de la tabla `consecutivos`, dentro de la misma
  /// transacción: ver `RepositorioConsecutivos`.
  late final RepositorioConsecutivos _consecutivos =
      RepositorioConsecutivos(_db);

  /// Cobrar y anular mueven stock. Todo por aquí.
  late final RepositorioInventario _inventario = RepositorioInventarioImpl(_db, sesion);

  $TablaVentasTable get _tablaVentas => _db.tablaVentas;
  $TablaVentaDetallesTable get _tablaItems => _db.tablaVentaDetalles;

  // SQL base para resúmenes. El nombre del cliente vive en `personas`, no en
  // `clientes`, así que hacen falta los dos LEFT JOIN encadenados: la venta de
  // mostrador no tiene cliente.
  /// El `JOIN` con `usuarios` va siempre: una venta sin el nombre de quien la
  /// hizo no sirve para el historial, que es donde se mira. Es `INNER` porque
  /// `ventas.usuario_id` es `NOT NULL`.
  static const _sqlSelectResumen = '''
    SELECT
      v.*,
      COALESCE(pe.nombres || ' ' || COALESCE(pe.apellidos, ''), '— Sin cliente —') AS cliente_nombre,
      TRIM(pu.nombres || ' ' || COALESCE(pu.apellidos, '')) AS cajero,
      COALESCE((SELECT SUM(d.total) FROM devoluciones d WHERE d.venta_id = v.id), 0)
        AS total_devuelto
    FROM ventas v
    LEFT JOIN clientes c  ON c.id  = v.cliente_id
    LEFT JOIN personas pe ON pe.id = c.persona_id
    INNER JOIN usuarios u  ON u.id  = v.usuario_id
    INNER JOIN personas pu ON pu.id = u.persona_id
  ''';

  /// Las tablas que hacen re-emitir el stream. Si falta una, el historial no
  /// se entera de que cambió (`REGLAS_BD.md` §5).
  Set<TableInfo<Table, dynamic>> get _tablasDelResumen => {
        _tablaVentas,
        _db.tablaCliente,
        _db.tablaPersona,
        _db.tablaUsuario,
        // Sin esta, registrar una devolución no refrescaría el historial: el
        // `total_devuelto` de la columna sale de aquí.
        _db.tablaDevolucion,
      };

  // Lecturas

  @override
  Stream<List<VentaResumen>> observarTodas() {
    return _db
        .customSelect(
          '$_sqlSelectResumen ORDER BY v.id DESC',
          readsFrom: _tablasDelResumen,
        )
        .watch()
        .map((rows) =>
            VentasMapper.resumenesDesdeMapas(rows.map((r) => r.data).toList()));
  }

  @override
  Stream<PaginaVentas> observarPagina({
    required FiltroVentas filtro,
    required int pagina,
    required int tamano,
  }) {
    final (where, variables) = _condicion(filtro);

    // Dos consultas: el total no lo puede recortar el `LIMIT`, o el paginador
    // diría que hay una página cuando hay veinte.
    //
    // El `SUM` viaja con el `COUNT` y no en una tercera consulta: los dos
    // hablan del mismo conjunto filtrado y separarlos abriría la puerta a que
    // un día filtren distinto. Se resta lo devuelto y se descartan las
    // anuladas: lo que interesa es la plata que quedó en el cajón.
    final consultaTotal = _db.customSelect(
      'SELECT COUNT(*) AS total, '
      "COALESCE(SUM(CASE WHEN v.estado_pago = 'ANULADA' THEN 0 ELSE "
      'v.total - COALESCE((SELECT SUM(d.total) FROM devoluciones d '
      'WHERE d.venta_id = v.id), 0) END), 0) AS suma_neta '
      'FROM ventas v '
      'LEFT JOIN clientes c ON c.id = v.cliente_id '
      'LEFT JOIN personas pe ON pe.id = c.persona_id '
      'INNER JOIN usuarios u ON u.id = v.usuario_id '
      'INNER JOIN personas pu ON pu.id = u.persona_id $where',
      variables: variables,
      readsFrom: _tablasDelResumen,
    );

    return _db
        .customSelect(
          '$_sqlSelectResumen $where ORDER BY v.id DESC LIMIT ?? OFFSET ??'
              .replaceAll('??', '?'),
          variables: [
            ...variables,
            Variable.withInt(tamano),
            Variable.withInt(pagina * tamano),
          ],
          readsFrom: _tablasDelResumen,
        )
        .watch()
        .asyncMap((filas) async {
      final agregados = await consultaTotal.getSingleOrNull();
      return PaginaVentas(
        items:
            VentasMapper.resumenesDesdeMapas(filas.map((f) => f.data).toList()),
        total: agregados?.data['total'] as int? ?? 0,
        // `SUM` sobre columnas enteras devuelve entero, pero SQLite no lo
        // promete si algún día alguna fuera REAL: se lee como `num`.
        sumaNeta: (agregados?.data['suma_neta'] as num?)?.round() ?? 0,
      );
    });
  }

  /// El `WHERE` y sus variables, para que la página y el total filtren igual.
  (String, List<Variable<Object>>) _condicion(FiltroVentas filtro) {
    final condiciones = <String>[];
    final variables = <Variable<Object>>[];

    if (filtro.tipo != null) {
      condiciones.add('v.tipo = ?');
      variables.add(Variable.withString(filtro.tipo!.aTexto));
    }
    if (filtro.estado != null) {
      condiciones.add('v.estado_pago = ?');
      variables.add(Variable.withString(filtro.estado!.aTexto));
    }
    if (filtro.usuarioId != null) {
      condiciones.add('v.usuario_id = ?');
      variables.add(Variable.withInt(filtro.usuarioId!));
    }
    if (filtro.desde != null) {
      condiciones.add('v.creado_en >= ?');
      variables.add(Variable.withDateTime(filtro.desde!));
    }
    if (filtro.hasta != null) {
      condiciones.add('v.creado_en <= ?');
      variables.add(Variable.withDateTime(filtro.hasta!));
    }

    final busqueda = filtro.busqueda.trim().toLowerCase();
    if (busqueda.isNotEmpty) {
      condiciones.add(
        '(LOWER(v.numero_factura) LIKE ?1 '
        "OR LOWER(COALESCE(pe.nombres, '')) LIKE ?1 "
        "OR LOWER(COALESCE(pe.apellidos, '')) LIKE ?1 "
        'OR LOWER(pu.nombres) LIKE ?1)',
      );
      variables.add(Variable.withString('%$busqueda%'));
    }

    if (condiciones.isEmpty) return ('', variables);
    return ('WHERE ${condiciones.join(' AND ')}', variables);
  }

  @override
  Future<VentaDetalle> obtenerDetalle(int id) async {
    final ventaRow = await _db
        .customSelect(
          '$_sqlSelectResumen WHERE v.id = ?',
          variables: [Variable.withInt(id)],
        )
        .getSingleOrNull();
    if (ventaRow == null) throw Exception('Venta #$id no encontrada.');

    final itemsRows = await _db
        .customSelect(
          'SELECT * FROM venta_detalles WHERE venta_id = ? ORDER BY id',
          variables: [Variable.withInt(id)],
        )
        .get();

    return VentasMapper.detalleDesdeMapas(
      ventaRow: ventaRow.data,
      itemsRows: itemsRows.map((r) => r.data).toList(),
    );
  }

  Future<VentaResumen> _obtenerResumenPorId(int id) async {
    final row = await _db
        .customSelect(
          '$_sqlSelectResumen WHERE v.id = ?',
          variables: [Variable.withInt(id)],
        )
        .getSingleOrNull();
    if (row == null) throw Exception('Venta #$id no encontrada.');
    return VentasMapper.resumenDesdeMap(row.data);
  }

  // Escrituras

  @override
  Future<VentaResumen> registrarVentaMostrador({
    required List<LineaVentaMostrador> lineas,
    required MetodoPago metodoPago,
    int? clienteId,
    int iva = 0,
    int descuento = 0,
  }) {
    exigir(Permiso.posVender);

    // Rebajar el total es una decisión aparte de cobrar: es la plata del
    // taller. Solo se exige cuando de verdad hay rebaja, para que una cuenta
    // sin el permiso siga pudiendo cobrar a precio de lista.
    if (descuento > 0) exigir(Permiso.posDescuento);

    if (lineas.isEmpty) {
      throw Exception('La venta no tiene productos.');
    }

    // Una sola transacción para las tres etapas: cabecera, líneas y cobro.
    return _db.transaction(() async {
      final ventaId = await _crearCabecera(
        clienteId: clienteId,
        metodoPago: metodoPago,
        iva: iva,
        descuento: descuento,
      );

      for (final linea in lineas) {
        await _agregarLinea(ventaId: ventaId, linea: linea);
      }

      await _recalcularTotales(ventaId);

      // Los totales se leen de la fila, no del carrito: es lo que garantiza
      // que `total_pagado == total` y que el CHECK `total_pagado <= total`
      // nunca se pueda romper desde la vista.
      final conTotales = await _obtenerResumenPorId(ventaId);

      await (_db.update(_tablaVentas)..where((t) => t.id.equals(ventaId)))
          .write(
        TablaVentasCompanion(
          totalPagado: Value(conTotales.total),
          estadoPago: Value(EstadoPago.pagado.aTexto),
          metodoPago: Value(metodoPago.codigo),
          actualizadoEn: Value(DateTime.now()),
        ),
      );

      return _obtenerResumenPorId(ventaId);
    });
  }

  /// Inserta la cabecera y devuelve su `id`.
  ///
  /// El número se pide **antes** de insertar. Antes se guardaba `'FAC-TEMP'` y
  /// se pisaba con el `id`: dos ventas a la vez chocaban contra el `UNIQUE` y
  /// cualquier `INSERT` fallido se saltaba un número para siempre.
  Future<int> _crearCabecera({
    int? clienteId,
    required MetodoPago metodoPago,
    required int iva,
    required int descuento,
  }) async {
    return _db.into(_tablaVentas).insert(
          VentasMapper.companionNuevo(
            usuarioId: autorId,
            numeroFactura:
                await _consecutivos.siguiente(DocumentoConsecutivo.factura),
            clienteId: clienteId,
            metodoPago: metodoPago,
            iva: iva,
            descuento: descuento,
          ),
        );
  }

  /// La línea y su salida de inventario, que tienen que pasar juntas: sin la
  /// segunda la venta cobraría algo que nunca salió del estante.
  Future<void> _agregarLinea({
    required int ventaId,
    required LineaVentaMostrador linea,
  }) async {
    await _verificarStock(linea.productoId, linea.cantidad);

    await _db.into(_tablaItems).insert(
          VentasMapper.itemCompanionNuevo(
            ventaId: ventaId,
            productoId: linea.productoId,
            descripcion: linea.descripcion,
            cantidad: linea.cantidad,
            precioUnitario: linea.precioUnitario,
            costoUnitario: linea.costoUnitario,
          ),
        );

    await _inventario.registrar(
      SolicitudMovimiento.salida(
        productoId: linea.productoId,
        cantidad: linea.cantidad,
        tipo: TipoMovimiento.salidaVenta,
        ventaId: ventaId,
      ),
    );
  }

  @override
  Future<void> anular(int id) async {
    exigir(Permiso.posAnular);
    await _db.transaction(() async {
      final venta = await (_db.select(_tablaVentas)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (venta == null) throw Exception('La venta #$id no existe.');

      if (venta.estadoPago == EstadoPago.anulada.aTexto) {
        throw Exception('La venta ${venta.numeroFactura} ya está anulada.');
      }

      // Las ventas ligadas a una orden no gestionan el stock directamente: lo
      // movió la orden al cerrarse. Solo se devuelve el de las de mostrador.
      if (venta.ordenId == null) {
        final items = await (_db.select(_tablaItems)
              ..where((t) => t.ventaId.equals(id)))
            .get();

        // Lo que el cliente ya trajo de vuelta **no vuelve otra vez**. Sin
        // este descuento, vender 5, devolver 2 y anular después dejaba 7 en la
        // estantería: el libro mayor lo contaba dos veces.
        //
        // Se descuenta lo devuelto **aunque no haya repuesto stock**
        // (`devoluciones.reingresa_stock` en `false`, la pieza rota que se le
        // reclama al proveedor): esas unidades tampoco están en manos del
        // cliente, así que anular no tiene nada que reponer por ellas.
        final yaDevuelto = await _devueltoPorLinea(id);

        for (final item in items) {
          if (item.tipoItem != TipoItem.producto.aTexto ||
              item.productoId == null) {
            continue;
          }

          final pendiente = item.cantidad - (yaDevuelto[item.id] ?? 0);
          // Una línea devuelta entera no deja nada por reponer.
          if (pendiente <= 0.0001) continue;

          await _inventario.registrar(
            SolicitudMovimiento.entrada(
              productoId: item.productoId!,
              cantidad: pendiente,
              tipo: TipoMovimiento.devolucionVenta,
              ventaId: id,
              notas: 'Venta anulada',
            ),
          );
        }
      }

      // La venta no se borra: es un documento contable. Se marca anulada y ahí
      // queda, con su número y su historial. El `DELETE` lo impide además una
      // guarda de la base (`guardas_sql.dart`), por si alguien lo intenta
      // desde otro camino.
      await (_db.update(_tablaVentas)..where((t) => t.id.equals(id))).write(
        TablaVentasCompanion(
          estadoPago: Value(EstadoPago.anulada.aTexto),
          actualizadoEn: Value(DateTime.now()),
        ),
      );

      await _anotar(
        AccionAuditada.anulo,
        id,
        'Venta ${venta.numeroFactura}',
        detalle: 'Total: ${venta.total}',
      );
    });
  }

  // Helpers

  /// Cuánto se devolvió ya de cada línea de la venta, por `venta_detalles.id`.
  ///
  /// Una consulta agregada y no una por línea: es el N+1 que prohíbe §5. Va en
  /// SQL crudo porque cruza dos módulos y este repositorio no debe cargar con
  /// el de devoluciones solo para esto.
  Future<Map<int, double>> _devueltoPorLinea(int ventaId) async {
    final filas = await _db.customSelect(
      '''
      SELECT dd.venta_detalle_id AS linea, SUM(dd.cantidad) AS devuelta
      FROM devolucion_detalles dd
      INNER JOIN venta_detalles vd ON vd.id = dd.venta_detalle_id
      WHERE vd.venta_id = ?
      GROUP BY dd.venta_detalle_id
      ''',
      variables: [Variable.withInt(ventaId)],
      readsFrom: {_db.tablaDevolucionDetalle, _tablaItems},
    ).get();

    return {
      for (final f in filas) f.read<int>('linea'): f.read<double>('devuelta'),
    };
  }

  /// Lanza si no alcanza el stock, con el mensaje que ve el usuario.
  ///
  /// La base también lo impediría, pero su error no se le puede enseñar a
  /// nadie.
  Future<void> _verificarStock(int productoId, double cantidad) async {
    final fila = await _db
        .customSelect(
          'SELECT nombre, stock_actual FROM productos WHERE id = ?',
          variables: [Variable.withInt(productoId)],
        )
        .getSingleOrNull();

    final disponible = (fila?.data['stock_actual'] as num?)?.toDouble() ?? 0;
    if (disponible >= cantidad) return;

    final nombre = fila?.data['nombre'] as String? ?? 'El producto';
    final texto = disponible % 1 == 0
        ? disponible.toInt().toString()
        : disponible.toStringAsFixed(2);
    throw Exception('Stock insuficiente de «$nombre». Disponible: $texto.');
  }

  Future<void> _recalcularTotales(int ventaId) async {
    final ventaRow = await (_db.select(_tablaVentas)
          ..where((t) => t.id.equals(ventaId)))
        .getSingleOrNull();
    if (ventaRow == null) return;

    final subtotalRow = await _db
        .customSelect(
          'SELECT COALESCE(SUM(subtotal), 0) AS sub FROM venta_detalles WHERE venta_id = ?',
          variables: [Variable.withInt(ventaId)],
        )
        .getSingleOrNull();
    final subtotal = (subtotalRow?.data['sub'] as num? ?? 0).round();

    // Un descuento mayor que el subtotal dejaría el total en negativo y el
    // `CHECK (total >= 0)` rechazaría el `UPDATE` sin explicación.
    final descuento = ventaRow.descuento > subtotal
        ? subtotal
        : (ventaRow.descuento < 0 ? 0 : ventaRow.descuento);

    // Los precios ya traen el IVA dentro (`iva_app.dart`): el total no se lo
    // suma, y la columna `iva` guarda cuánto va contenido en él.
    final total = subtotal - descuento;

    await (_db.update(_tablaVentas)..where((t) => t.id.equals(ventaId))).write(
      TablaVentasCompanion(
        subtotal: Value(subtotal),
        descuento: Value(descuento),
        iva: Value(ivaIncluidoEn(total)),
        total: Value(total),
        actualizadoEn: Value(DateTime.now()),
      ),
    );
  }
}
