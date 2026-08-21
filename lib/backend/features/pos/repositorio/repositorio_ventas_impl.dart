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

class RepositorioVentasImpl implements RepositorioVentas {
  RepositorioVentasImpl(this._db);

  final AppDb _db;

  /// El número de la venta sale de la tabla `consecutivos`, dentro de la misma
  /// transacción: ver `RepositorioConsecutivos`.
  late final RepositorioConsecutivos _consecutivos =
      RepositorioConsecutivos(_db);

  /// Cobrar y anular mueven stock. Todo por aquí.
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

  // Lecturas

  @override
  Stream<List<VentaResumen>> observarTodas() {
    return _db
        .customSelect(
          '$_sqlSelectResumen ORDER BY v.id DESC',
          readsFrom: {_tablaVentas, _db.tablaCliente, _db.tablaPersona},
        )
        .watch()
        .map((rows) =>
            VentasMapper.resumenesDesdeMapas(rows.map((r) => r.data).toList()));
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

        for (final item in items) {
          if (item.tipoItem == TipoItem.producto.aTexto &&
              item.productoId != null) {
            await _inventario.registrar(
              SolicitudMovimiento.entrada(
                productoId: item.productoId!,
                cantidad: item.cantidad,
                tipo: TipoMovimiento.devolucionVenta,
                ventaId: id,
                notas: 'Venta anulada',
              ),
            );
          }
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
    });
  }

  // Helpers

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
