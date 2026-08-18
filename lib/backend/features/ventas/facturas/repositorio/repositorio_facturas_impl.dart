import '../../../../share/consecutivos/documento_consecutivo.dart';
import '../../../../share/consecutivos/repositorio_consecutivos.dart';
import 'package:drift/drift.dart';

import '../../../../share/database/app_db.dart';
import '../enum/enum_facturas.dart';
import '../../../inventario/modelo/movimiento_inventario.dart';
import '../../../inventario/repositorio/repositorio_inventario.dart';
import '../../../inventario/repositorio/repositorio_inventario_impl.dart';
import '../mapper/facturas_mapper.dart';
import '../modelo/factura_detalle.dart';
import '../modelo/factura_resumen.dart';
import 'repositorio_facturas.dart';

class RepositorioFacturasImpl implements RepositorioFacturas {
  RepositorioFacturasImpl(this._db);

  final AppDb _db;

  /// El número de factura sale de la tabla `consecutivos`, dentro de la misma
  /// transacción: ver `RepositorioConsecutivos`.
  late final RepositorioConsecutivos _consecutivos =
      RepositorioConsecutivos(_db);

  /// Facturar, corregir una línea y anular mueven stock. Todo por aquí.
  late final RepositorioInventario _inventario = RepositorioInventarioImpl(_db);

  $TablaVentasTable get _tablaVentas => _db.tablaVentas;
  $TablaVentaDetallesTable get _tablaItems => _db.tablaVentaDetalles;

  // SQL base para resúmenes. El nombre del cliente vive en `personas`, no en
  // `clientes`, así que hacen falta los dos LEFT JOIN encadenados: la venta de
  // mostrador no tiene cliente.
  static const _sqlSelectResumen = '''
    SELECT
      v.*,
      COALESCE(pe.nombres || ' ' || COALESCE(pe.apellidos, ''), '— Sin cliente —') AS cliente_nombre
    FROM ventas v
    LEFT JOIN clientes c  ON c.id  = v.cliente_id
    LEFT JOIN personas pe ON pe.id = c.persona_id
  ''';

  @override
  Stream<List<FacturaResumen>> observarTodas() {
    return _db
        .customSelect(
          '$_sqlSelectResumen ORDER BY v.id DESC',
          readsFrom: {_tablaVentas, _db.tablaCliente, _db.tablaPersona},
        )
        .watch()
        .map((rows) =>
            FacturasMapper.resumenesDesdeMapas(rows.map((r) => r.data).toList()));
  }

  @override
  Future<List<FacturaResumen>> obtenerTodas() async {
    final rows =
        await _db.customSelect('$_sqlSelectResumen ORDER BY v.id DESC').get();
    return FacturasMapper.resumenesDesdeMapas(rows.map((r) => r.data).toList());
  }

  Future<FacturaResumen> _obtenerResumenPorId(int id) async {
    final row = await _db
        .customSelect(
          '$_sqlSelectResumen WHERE v.id = ?',
          variables: [Variable.withInt(id)],
        )
        .getSingleOrNull();
    if (row == null) throw Exception('Factura #$id no encontrada.');
    return FacturasMapper.resumenDesdeMap(row.data);
  }

  @override
  Future<FacturaDetalle> obtenerDetalle(int id) async {
    final ventaRow = await _db
        .customSelect(
          '$_sqlSelectResumen WHERE v.id = ?',
          variables: [Variable.withInt(id)],
        )
        .getSingleOrNull();
    if (ventaRow == null) throw Exception('Factura #$id no encontrada.');

    final itemsRows = await _db
        .customSelect(
          'SELECT * FROM venta_detalles WHERE venta_id = ? ORDER BY id',
          variables: [Variable.withInt(id)],
        )
        .get();

    return FacturasMapper.detalleDesdeMapas(
      ventaRow: ventaRow.data,
      itemsRows: itemsRows.map((r) => r.data).toList(),
    );
  }

  @override
  Future<FacturaResumen> crear({
    required TipoVenta tipo,
    int? ordenId,
    int? clienteId,
    required MetodoPago metodoPago,
    required EstadoPago estadoPago,
    int iva = 0,
    int descuento = 0,
  }) {
    // El número se pide antes de insertar. Antes se guardaba `'FAC-TEMP'` y
    // se pisaba con el `id`: dos facturas a la vez chocaban contra el `UNIQUE`
    // y cualquier `INSERT` fallido se saltaba un número para siempre.
    return _db.transaction(() async {
      final id = await _db.into(_tablaVentas).insert(
            FacturasMapper.companionNuevo(
              numeroFactura: await _consecutivos.siguiente(
                DocumentoConsecutivo.factura,
              ),
              tipo: tipo,
              ordenId: ordenId,
              clienteId: clienteId,
              metodoPago: metodoPago,
              estadoPago: estadoPago,
              iva: iva,
              descuento: descuento,
            ),
          );

      return _obtenerResumenPorId(id);
    });
  }

  @override
  Future<FacturaResumen> crearDesdeOrden({
    required int ordenId,
    required int clienteId,
    required MetodoPago metodoPago,
    required EstadoPago estadoPago,
    int iva = 0,
  }) async {
    return _db.transaction(() async {
      // Validar que la orden tenga al menos un servicio
      final svcCount = await _db.customSelect(
        'SELECT COUNT(*) AS cnt FROM ordenes_tareas WHERE orden_id = ?',
        variables: [Variable.withInt(ordenId)],
      ).getSingleOrNull();
      if (((svcCount?.data['cnt'] as int?) ?? 0) == 0) {
        throw Exception('La orden no tiene servicios. Agrega al menos uno antes de facturar.');
      }

      // 1. Crear cabecera, ya con su número definitivo.
      final id = await _db.into(_tablaVentas).insert(
            FacturasMapper.companionNuevo(
              numeroFactura: await _consecutivos.siguiente(
                DocumentoConsecutivo.factura,
              ),
              tipo: TipoVenta.servicio,
              ordenId: ordenId,
              clienteId: clienteId,
              metodoPago: metodoPago,
              estadoPago: estadoPago,
              iva: iva,
            ),
          );

      // 2. Importar tareas como ítems SERVICIO
      final tareasRows = await _db.customSelect(
        '''
        SELECT ot.servicio_id, ot.tecnico_id, s.nombre AS servicio_nombre, ot.precio_pactado
        FROM ordenes_tareas ot
        JOIN servicios s ON s.id = ot.servicio_id
        WHERE ot.orden_id = ?
        ''',
        variables: [Variable.withInt(ordenId)],
      ).get();

      for (final row in tareasRows) {
        final data = row.data;
        await _db.into(_tablaItems).insert(
          FacturasMapper.itemCompanionNuevo(
            ventaId: id,
            tipoItem: TipoItem.servicio,
            servicioId: data['servicio_id'] as int?,
            tecnicoId: data['tecnico_id'] as int?,
            descripcion: data['servicio_nombre'] as String? ?? 'Servicio',
            cantidad: 1,
            precioUnitario: (data['precio_pactado'] as num? ?? 0).round(),
            costoUnitario: 0,
          ),
        );
      }

      // 3. Importar repuestos como ítems PRODUCTO
      // El stock ya fue descontado cuando se agregó el repuesto a la orden,
      // por eso aquí solo se registra el snapshot histórico sin tocar el stock.
      final repuestosRows = await _db.customSelect(
        '''
        SELECT orp.producto_id, p.nombre AS producto_nombre,
               orp.cantidad, orp.precio_unitario,
               COALESCE(p.precio_compra, 0) AS precio_compra
        FROM ordenes_repuestos orp
        JOIN productos p ON p.id = orp.producto_id
        WHERE orp.orden_id = ?
        ''',
        variables: [Variable.withInt(ordenId)],
      ).get();

      for (final row in repuestosRows) {
        final data = row.data;
        await _db.into(_tablaItems).insert(
          FacturasMapper.itemCompanionNuevo(
            ventaId: id,
            tipoItem: TipoItem.producto,
            productoId: data['producto_id'] as int,
            descripcion: data['producto_nombre'] as String? ?? 'Producto',
            cantidad: (data['cantidad'] as num).toDouble(),
            precioUnitario: (data['precio_unitario'] as num? ?? 0).round(),
            costoUnitario: (data['precio_compra'] as num? ?? 0).round(),
          ),
        );
      }

      await _recalcularTotales(id);

      // Cambiar estado de la orden a LISTA automáticamente
      await _db.customUpdate(
        "UPDATE ordenes_servicio SET estado = 'LISTA', actualizado_en = datetime('now','localtime') WHERE id = ?",
        variables: [Variable.withInt(ordenId)],
        updates: {_db.tablaOrdenesServicio},
      );

      return _obtenerResumenPorId(id);
    });
  }

  @override
  Future<FacturaResumen?> obtenerPorOrden(int ordenId) async {
    final row = await _db
        .customSelect(
          '$_sqlSelectResumen WHERE v.orden_id = ? LIMIT 1',
          variables: [Variable.withInt(ordenId)],
        )
        .getSingleOrNull();
    return row == null ? null : FacturasMapper.resumenDesdeMap(row.data);
  }

  @override
  Future<FacturaResumen> actualizarDesdeOrden({
    required int facturaId,
    required int ordenId,
    int?         clienteId,
    required MetodoPago metodoPago,
    required EstadoPago estadoPago,
    int iva       = 0,
    int descuento = 0,
  }) async {
    return _db.transaction(() async {
      // 1. Validar que la orden tenga al menos un servicio
      final svcCount = await _db.customSelect(
        'SELECT COUNT(*) AS cnt FROM ordenes_tareas WHERE orden_id = ?',
        variables: [Variable.withInt(ordenId)],
      ).getSingleOrNull();
      if (((svcCount?.data['cnt'] as int?) ?? 0) == 0) {
        throw Exception('La orden no tiene servicios. Agrega al menos uno antes de facturar.');
      }

      // 2. Actualizar cabecera
      await (_db.update(_tablaVentas)..where((t) => t.id.equals(facturaId))).write(
        TablaVentasCompanion(
          metodoPago:    Value(metodoPago.codigo),
          estadoPago:    Value(estadoPago.aTexto),
          iva:           Value(iva),
          descuento:     Value(descuento),
          clienteId:     clienteId != null ? Value(clienteId) : const Value.absent(),
          actualizadoEn: Value(DateTime.now()),
        ),
      );

      // 3. Borrar ítems anteriores (sin restaurar stock, gestionado en la orden)
      await (_db.delete(_tablaItems)
            ..where((t) => t.ventaId.equals(facturaId)))
          .go();

      // 4. Re-importar tareas
      final tareasRows = await _db.customSelect(
        '''
        SELECT ot.servicio_id, ot.tecnico_id, s.nombre AS servicio_nombre, ot.precio_pactado
        FROM ordenes_tareas ot
        JOIN servicios s ON s.id = ot.servicio_id
        WHERE ot.orden_id = ?
        ''',
        variables: [Variable.withInt(ordenId)],
      ).get();

      for (final row in tareasRows) {
        final data = row.data;
        await _db.into(_tablaItems).insert(
          FacturasMapper.itemCompanionNuevo(
            ventaId:        facturaId,
            tipoItem:       TipoItem.servicio,
            servicioId:     data['servicio_id'] as int?,
            tecnicoId:      data['tecnico_id'] as int?,
            descripcion:    data['servicio_nombre'] as String? ?? 'Servicio',
            cantidad:       1,
            precioUnitario: (data['precio_pactado'] as num? ?? 0).round(),
            costoUnitario:  0,
          ),
        );
      }

      // 5. Re-importar repuestos (sin descontar stock)
      final repuestosRows = await _db.customSelect(
        '''
        SELECT orp.producto_id, p.nombre AS producto_nombre,
               orp.cantidad, orp.precio_unitario,
               COALESCE(p.precio_compra, 0) AS precio_compra
        FROM ordenes_repuestos orp
        JOIN productos p ON p.id = orp.producto_id
        WHERE orp.orden_id = ?
        ''',
        variables: [Variable.withInt(ordenId)],
      ).get();

      for (final row in repuestosRows) {
        final data = row.data;
        await _db.into(_tablaItems).insert(
          FacturasMapper.itemCompanionNuevo(
            ventaId:        facturaId,
            tipoItem:       TipoItem.producto,
            productoId:     data['producto_id'] as int,
            descripcion:    data['producto_nombre'] as String? ?? 'Producto',
            cantidad:       (data['cantidad'] as num).toDouble(),
            precioUnitario: (data['precio_unitario'] as num? ?? 0).round(),
            costoUnitario:  (data['precio_compra'] as num? ?? 0).round(),
          ),
        );
      }

      await _recalcularTotales(facturaId);
      return _obtenerResumenPorId(facturaId);
    });
  }

  @override
  Future<bool> tieneFactura(int ordenId) async {
    final row = await _db.customSelect(
      'SELECT COUNT(*) AS cnt FROM ventas WHERE orden_id = ?',
      variables: [Variable.withInt(ordenId)],
    ).getSingleOrNull();
    return ((row?.data['cnt'] as int?) ?? 0) > 0;
  }

  @override
  Future<FacturaResumen> actualizar({
    required int id,
    required MetodoPago metodoPago,
    required EstadoPago estadoPago,
    int? iva,
    int? descuento,
    bool actualizarCliente = false,
    int? clienteId,
  }) async {
    // Obtener orden vinculada antes de actualizar (para propagar cliente)
    int? ordenVinculadaId;
    if (actualizarCliente && clienteId != null) {
      final ventaRow = await (_db.select(_tablaVentas)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      ordenVinculadaId = ventaRow?.ordenId;
    }

    await (_db.update(_tablaVentas)..where((t) => t.id.equals(id))).write(
      TablaVentasCompanion(
        metodoPago:    Value(metodoPago.codigo),
        estadoPago:    Value(estadoPago.aTexto),
        iva:           iva != null ? Value(iva) : const Value.absent(),
        descuento:     descuento != null ? Value(descuento) : const Value.absent(),
        clienteId:     actualizarCliente ? Value(clienteId) : const Value.absent(),
        actualizadoEn: Value(DateTime.now()),
      ),
    );

    // Propagar cambio de cliente a la orden vinculada (si existe)
    if (ordenVinculadaId != null) {
      await _db.customUpdate(
        'UPDATE ordenes_servicio SET cliente_id = ? WHERE id = ?',
        variables: [Variable.withInt(clienteId!), Variable.withInt(ordenVinculadaId)],
        updates: {_db.tablaOrdenesServicio},
      );
    }

    await _recalcularTotales(id);
    return _obtenerResumenPorId(id);
  }

  @override
  Future<void> anular(int id) async {
    await _db.transaction(() async {
      final factura = await (_db.select(_tablaVentas)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (factura == null) throw Exception('Factura #$id no existe.');

      if (factura.estadoPago == EstadoPago.anulada.aTexto) {
        throw Exception('La factura ${factura.numeroFactura} ya está anulada.');
      }

      // Las facturas ligadas a una orden no gestionan el stock directamente
      // (fue descontado al agregar el repuesto a la orden).
      // Solo se devuelve el stock de las facturas sin orden asociada.
      if (factura.ordenId == null) {
        final items = await (_db.select(_tablaItems)
              ..where((t) => t.ventaId.equals(id)))
            .get();

        for (final item in items) {
          if (item.tipoItem == TipoItem.producto.aTexto &&
              item.productoId != null) {
            await _inventario.registrar(
              SolicitudMovimiento.entrada(
                productoId: item.productoId!,
                cantidad: item.cantidad,
                tipo: TipoMovimiento.devolucionVenta,
                ventaId: id,
                notas: 'Factura anulada',
              ),
            );
          }
        }
      }

      // La factura no se borra: es un documento contable. Se marca anulada y
      // ahí queda, con su número y su historial. El `DELETE` lo impide además
      // una guarda de la base (`guardas_sql.dart`), por si alguien lo intenta
      // desde otro camino.
      await (_db.update(_tablaVentas)..where((t) => t.id.equals(id))).write(
        TablaVentasCompanion(
          estadoPago: Value(EstadoPago.anulada.aTexto),
          actualizadoEn: Value(DateTime.now()),
        ),
      );
    });
  }

  // Items

  @override
  Future<void> agregarItem({
    required int ventaId,
    required TipoItem tipoItem,
    int? productoId,
    int? servicioId,
    int? tecnicoId,
    required String descripcion,
    required double cantidad,
    required int precioUnitario,
    int costoUnitario = 0,
  }) {
    // Cuatro escrituras que tienen que pasar juntas: la línea, la salida de
    // inventario, los totales de la factura y —si viene de una orden— el
    // precio pactado de la tarea. Antes iban sueltas, y un fallo a mitad
    // dejaba la factura cobrando algo que nunca salió del inventario.
    return _db.transaction(() async {
      if (tipoItem == TipoItem.producto && productoId != null) {
        await _verificarStock(productoId, cantidad);
      }

      await _db.into(_tablaItems).insert(
          FacturasMapper.itemCompanionNuevo(
            ventaId: ventaId,
            tipoItem: tipoItem,
            productoId: productoId,
            servicioId: servicioId,
            tecnicoId: tecnicoId,
            descripcion: descripcion,
            cantidad: cantidad,
            precioUnitario: precioUnitario,
            costoUnitario: costoUnitario,
          ),
        );

      if (tipoItem == TipoItem.producto && productoId != null) {
        await _inventario.registrar(
          SolicitudMovimiento.salida(
            productoId: productoId,
            cantidad: cantidad,
            tipo: TipoMovimiento.salidaVenta,
            ventaId: ventaId,
          ),
        );
      }

      await _recalcularTotales(ventaId);

      // Si la factura viene de una orden y el ítem es un servicio, el precio
      // que se cobró se refleja en la tarea: es el mismo trabajo.
      if (tipoItem == TipoItem.servicio && servicioId != null) {
        final factura = await (_db.select(_tablaVentas)
              ..where((t) => t.id.equals(ventaId)))
            .getSingleOrNull();
        final ordenId = factura?.ordenId;
        if (ordenId != null) {
          await (_db.update(_db.tablaOrdenesTarea)
                ..where((t) =>
                    t.ordenId.equals(ordenId) &
                    t.servicioId.equals(servicioId)))
              .write(TablaOrdenesTareaCompanion(
            precioPactado: Value(precioUnitario),
            tecnicoId:
                tecnicoId != null ? Value(tecnicoId) : const Value.absent(),
          ));
        }
      }
    });
  }

  /// Lanza si no alcanza el stock, con el mensaje que ve el usuario.
  ///
  /// La base también lo impediría, pero su error no se le puede enseñar a
  /// nadie.
  Future<void> _verificarStock(int productoId, double cantidad) async {
    final fila = await _db
        .customSelect(
          'SELECT stock_actual FROM productos WHERE id = ?',
          variables: [Variable.withInt(productoId)],
        )
        .getSingleOrNull();

    final disponible = (fila?.data['stock_actual'] as num?)?.toDouble() ?? 0;
    if (disponible >= cantidad) return;

    final texto = disponible % 1 == 0
        ? disponible.toInt().toString()
        : disponible.toStringAsFixed(2);
    throw Exception('Stock insuficiente. Disponible: $texto unidades.');
  }

  @override
  Future<void> actualizarItem(
    int itemId, {
    double? cantidad,
    int? precioUnitario,
  }) async {
    final current = await (_db.select(_tablaItems)
          ..where((t) => t.id.equals(itemId)))
        .getSingleOrNull();
    if (current == null) return;

    final cantidadNueva = cantidad ?? current.cantidad;
    final precioNuevo = precioUnitario ?? current.precioUnitario;
    final delta = cantidadNueva - current.cantidad;

    // Solo se mueve la diferencia: positivo = se cobró más y sale del
    // inventario, negativo = se devolvió parte.
    if (current.tipoItem == TipoItem.producto.aTexto &&
        current.productoId != null &&
        delta != 0) {
      await _inventario.registrar(
        SolicitudMovimiento(
          productoId: current.productoId!,
          cantidad: -delta,
          tipo: delta > 0
              ? TipoMovimiento.salidaVenta
              : TipoMovimiento.devolucionVenta,
          ventaId: current.ventaId,
          notas: 'Cambio de cantidad en la factura',
        ),
      );
    }

    await (_db.update(_tablaItems)..where((t) => t.id.equals(itemId))).write(
      TablaVentaDetallesCompanion(
        cantidad: Value(cantidadNueva),
        precioUnitario: Value(precioNuevo),
        // El importe cobrado es entero aunque la cantidad no lo sea.
        subtotal: Value((cantidadNueva * precioNuevo).round()),
      ),
    );

    await _recalcularTotales(current.ventaId);

    // Si la factura está ligada a una orden y el item es un producto,
    // sincronizar precio/cantidad en ordenes_repuestos (sin tocar stock,
    // ya fue ajustado arriba).
    if (current.tipoItem == TipoItem.producto.aTexto &&
        current.productoId != null) {
      final factura = await (_db.select(_tablaVentas)
            ..where((t) => t.id.equals(current.ventaId)))
          .getSingleOrNull();
      if (factura?.ordenId != null) {
        await (_db.update(_db.tablaOrdenesRepuesto)
              ..where((t) =>
                  t.ordenId.equals(factura!.ordenId!) &
                  t.productoId.equals(current.productoId!)))
            .write(TablaOrdenesRepuestoCompanion(
          cantidad: Value(cantidadNueva),
          precioUnitario: Value(precioNuevo),
        ));
      }
    }
  }

  @override
  Future<void> eliminarItem(int itemId) {
    // Tres escrituras que van juntas. Si el recálculo del total falla —por
    // ejemplo, porque dejaría la factura cobrando más de lo que suma— la
    // línea tiene que volver y el stock también.
    return _db.transaction(() async {
      final current = await (_db.select(_tablaItems)
            ..where((t) => t.id.equals(itemId)))
          .getSingleOrNull();
      if (current == null) return;

      await (_db.delete(_tablaItems)..where((t) => t.id.equals(itemId))).go();

      if (current.tipoItem == TipoItem.producto.aTexto &&
          current.productoId != null) {
        await _inventario.registrar(
          SolicitudMovimiento.entrada(
            productoId: current.productoId!,
            cantidad: current.cantidad,
            tipo: TipoMovimiento.devolucionVenta,
            ventaId: current.ventaId,
            notas: 'Línea eliminada de la factura',
          ),
        );
      }

      await _recalcularTotales(current.ventaId);
    });
  }

  @override
  Future<FacturaResumen> actualizarPago({
    required int id,
    required int totalPagado,
    required EstadoPago estadoPago,
    required MetodoPago metodoPago,
  }) async {
    await (_db.update(_tablaVentas)..where((t) => t.id.equals(id))).write(
      TablaVentasCompanion(
        totalPagado:   Value(totalPagado),
        estadoPago:    Value(estadoPago.aTexto),
        metodoPago:    Value(metodoPago.codigo),
        actualizadoEn: Value(DateTime.now()),
      ),
    );
    return _obtenerResumenPorId(id);
  }

  // Helpers

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
    final subtotal  = (subtotalRow?.data['sub'] as num? ?? 0).round();
    final iva       = ventaRow.iva;
    final descuento = ventaRow.descuento;
    final total     = subtotal - descuento + iva;

    await (_db.update(_tablaVentas)..where((t) => t.id.equals(ventaId))).write(
      TablaVentasCompanion(
        subtotal: Value(subtotal),
        total: Value(total),
        actualizadoEn: Value(DateTime.now()),
      ),
    );
  }
}
