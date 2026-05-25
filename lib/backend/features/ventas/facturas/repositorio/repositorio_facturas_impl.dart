import 'package:drift/drift.dart';

import '../../../../share/database/app_db.dart';
import '../enum/enum_facturas.dart';
import '../mapper/facturas_mapper.dart';
import '../modelo/factura_detalle.dart';
import '../modelo/factura_resumen.dart';
import 'repositorio_facturas.dart';

class RepositorioFacturasImpl implements RepositorioFacturas {
  const RepositorioFacturasImpl(this._db);

  final AppDb _db;

  $TablaVentasTable get _tablaVentas => _db.tablaVentas;
  $TablaVentaDetallesTable get _tablaItems => _db.tablaVentaDetalles;

  // SQL base para resúmenes (LEFT JOIN para clientes opcionales)
  static const _sqlSelectResumen = '''
    SELECT
      v.*,
      COALESCE(c.nombres || ' ' || COALESCE(c.apellidos, ''), '— Sin cliente —') AS cliente_nombre
    FROM ventas v
    LEFT JOIN clientes c ON c.id = v.cliente_id
  ''';

  @override
  Stream<List<FacturaResumen>> observarTodas() {
    return _db
        .customSelect(
          '$_sqlSelectResumen ORDER BY v.id DESC',
          readsFrom: {_tablaVentas, _db.tablaCliente},
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
    double iva = 0,
  }) async {
    // Número temporal — se actualiza tras conocer el id
    final id = await _db.into(_tablaVentas).insert(
          FacturasMapper.companionNuevo(
            numeroFactura: 'FAC-TEMP',
            tipo: tipo,
            ordenId: ordenId,
            clienteId: clienteId,
            metodoPago: metodoPago,
            estadoPago: estadoPago,
            iva: iva,
          ),
        );

    final numeroFactura = FacturasMapper.formatearNumero(id);
    await (_db.update(_tablaVentas)..where((t) => t.id.equals(id))).write(
      TablaVentasCompanion(numeroFactura: Value(numeroFactura)),
    );

    return _obtenerResumenPorId(id);
  }

  @override
  Future<FacturaResumen> crearDesdeOrden({
    required int ordenId,
    required int clienteId,
    required MetodoPago metodoPago,
    required EstadoPago estadoPago,
    double iva = 0,
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

      // 1. Crear cabecera
      final id = await _db.into(_tablaVentas).insert(
            FacturasMapper.companionNuevo(
              numeroFactura: 'FAC-TEMP',
              tipo: TipoVenta.servicio,
              ordenId: ordenId,
              clienteId: clienteId,
              metodoPago: metodoPago,
              estadoPago: estadoPago,
              iva: iva,
            ),
          );
      final numeroFactura = FacturasMapper.formatearNumero(id);
      await (_db.update(_tablaVentas)..where((t) => t.id.equals(id))).write(
        TablaVentasCompanion(numeroFactura: Value(numeroFactura)),
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
            precioUnitario: (data['precio_pactado'] as num? ?? 0).toDouble(),
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
            precioUnitario: (data['precio_unitario'] as num? ?? 0).toDouble(),
            costoUnitario: (data['precio_compra'] as num? ?? 0).toDouble(),
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
    required MetodoPago metodoPago,
    required EstadoPago estadoPago,
    double iva = 0,
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
          metodoPago:   Value(metodoPago.aTexto),
          estadoPago:   Value(estadoPago.aTexto),
          iva:          Value(iva),
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
            precioUnitario: (data['precio_pactado'] as num? ?? 0).toDouble(),
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
            precioUnitario: (data['precio_unitario'] as num? ?? 0).toDouble(),
            costoUnitario:  (data['precio_compra'] as num? ?? 0).toDouble(),
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
    double? iva,
  }) async {
    await (_db.update(_tablaVentas)..where((t) => t.id.equals(id))).write(
      TablaVentasCompanion(
        metodoPago: Value(metodoPago.aTexto),
        estadoPago: Value(estadoPago.aTexto),
        iva: iva != null ? Value(iva) : const Value.absent(),
        actualizadoEn: Value(DateTime.now()),
      ),
    );
    await _recalcularTotales(id);
    return _obtenerResumenPorId(id);
  }

  @override
  Future<void> eliminar(int id) async {
    await _db.transaction(() async {
      final factura = await (_db.select(_tablaVentas)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (factura == null) throw Exception('Factura #$id no existe.');

      // Las facturas ligadas a una orden no gestionan el stock directamente
      // (fue descontado al agregar el repuesto a la orden).
      // Solo se restaura el stock para facturas sin orden asociada.
      if (factura.ordenId == null) {
        final items = await (_db.select(_tablaItems)
              ..where((t) => t.ventaId.equals(id)))
            .get();

        for (final item in items) {
          if (item.tipoItem == TipoItem.producto.aTexto &&
              item.productoId != null) {
            await _db.customUpdate(
              'UPDATE productos SET stock_actual = stock_actual + ? WHERE id = ?',
              variables: [
                Variable.withReal(item.cantidad),
                Variable.withInt(item.productoId!),
              ],
              updates: {_db.tablaProducto},
            );
          }
        }
      }

      await (_db.delete(_tablaVentas)..where((t) => t.id.equals(id))).go();
    });
  }

  // ── Items ────────────────────────────────────────────────────────────────

  @override
  Future<void> agregarItem({
    required int ventaId,
    required TipoItem tipoItem,
    int? productoId,
    int? servicioId,
    int? tecnicoId,
    required String descripcion,
    required double cantidad,
    required double precioUnitario,
    double costoUnitario = 0,
  }) async {
    // Validar stock si es producto
    if (tipoItem == TipoItem.producto && productoId != null) {
      final stockRow = await _db
          .customSelect(
            'SELECT stock_actual FROM productos WHERE id = ?',
            variables: [Variable.withInt(productoId)],
          )
          .getSingleOrNull();
      final stockActual =
          (stockRow?.data['stock_actual'] as num?)?.toDouble() ?? 0;
      if (stockActual < cantidad) {
        final disp = stockActual % 1 == 0
            ? stockActual.toInt().toString()
            : stockActual.toStringAsFixed(2);
        throw Exception('Stock insuficiente. Disponible: $disp unidades.');
      }
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

    // Descontar stock
    if (tipoItem == TipoItem.producto && productoId != null) {
      await _db.customUpdate(
        'UPDATE productos SET stock_actual = stock_actual - ? WHERE id = ?',
        variables: [Variable.withReal(cantidad), Variable.withInt(productoId)],
        updates: {_db.tablaProducto},
      );
    }

    await _recalcularTotales(ventaId);

    // Si la factura está ligada a una orden y el item es un servicio,
    // sincronizar precio_pactado y tecnico_id en ordenes_tareas.
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
          tecnicoId: tecnicoId != null ? Value(tecnicoId) : const Value.absent(),
        ));
      }
    }
  }

  @override
  Future<void> actualizarItem(
    int itemId, {
    double? cantidad,
    double? precioUnitario,
  }) async {
    final current = await (_db.select(_tablaItems)
          ..where((t) => t.id.equals(itemId)))
        .getSingleOrNull();
    if (current == null) return;

    final cantidadNueva = cantidad ?? current.cantidad;
    final precioNuevo = precioUnitario ?? current.precioUnitario;
    final delta = cantidadNueva - current.cantidad;

    // Ajustar stock si es producto
    if (current.tipoItem == TipoItem.producto.aTexto &&
        current.productoId != null &&
        delta != 0) {
      await _db.customUpdate(
        'UPDATE productos SET stock_actual = stock_actual - ? WHERE id = ?',
        variables: [
          Variable.withReal(delta),
          Variable.withInt(current.productoId!),
        ],
        updates: {_db.tablaProducto},
      );
    }

    await (_db.update(_tablaItems)..where((t) => t.id.equals(itemId))).write(
      TablaVentaDetallesCompanion(
        cantidad: Value(cantidadNueva),
        precioUnitario: Value(precioNuevo),
        subtotal: Value(cantidadNueva * precioNuevo),
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
  Future<void> eliminarItem(int itemId) async {
    final current = await (_db.select(_tablaItems)
          ..where((t) => t.id.equals(itemId)))
        .getSingleOrNull();
    if (current == null) return;

    await (_db.delete(_tablaItems)..where((t) => t.id.equals(itemId))).go();

    // Restaurar stock si era producto
    if (current.tipoItem == TipoItem.producto.aTexto &&
        current.productoId != null) {
      await _db.customUpdate(
        'UPDATE productos SET stock_actual = stock_actual + ? WHERE id = ?',
        variables: [
          Variable.withReal(current.cantidad),
          Variable.withInt(current.productoId!),
        ],
        updates: {_db.tablaProducto},
      );
    }

    await _recalcularTotales(current.ventaId);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

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
    final subtotal = (subtotalRow?.data['sub'] as num? ?? 0).toDouble();
    final iva = ventaRow.iva;
    final total = subtotal + iva;

    await (_db.update(_tablaVentas)..where((t) => t.id.equals(ventaId))).write(
      TablaVentasCompanion(
        subtotal: Value(subtotal),
        total: Value(total),
        actualizadoEn: Value(DateTime.now()),
      ),
    );
  }
}
