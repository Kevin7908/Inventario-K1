import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../../../share/utils/fecha_sqlite.dart';
import '../enum/enum_ventas.dart';
import '../modelo/venta_detalle.dart';
import '../modelo/venta_resumen.dart';
import '../modelo/venta_item.dart';

abstract final class VentasMapper {
  // Resumen (lista)

  static VentaResumen resumenDesdeMap(Map<String, dynamic> row) {
    final ordenId = row['orden_id'] as int?;
    return VentaResumen(
      id: row['id'] as int,
      numeroFactura: row['numero_factura'] as String,
      tipo: TipoVenta.desdeTexto(row['tipo'] as String? ?? 'SERVICIO'),
      clienteNombre: row['cliente_nombre'] as String? ?? '— Sin cliente —',
      ordenId: ordenId,
      numeroOrden: ordenId != null
          ? '#ORD-${ordenId.toString().padLeft(4, '0')}'
          : null,
      total: _pesos(row['total']),
      iva: _pesos(row['iva']),
      descuento: _pesos(row['descuento']),
      estadoPago: EstadoPago.desdeTexto(row['estado_pago'] as String? ?? 'PENDIENTE'),
      metodoPago: MetodoPago.desdeCodigo(row['metodo_pago'] as String? ?? 'EFECTIVO'),
      creadoEn: fechaDeSqlite(row['creado_en']),
      cajero: (row['cajero'] as String?)?.trim() ?? '',
      totalDevuelto: _pesos(row['total_devuelto']),
    );
  }

  static List<VentaResumen> resumenesDesdeMapas(
    List<Map<String, dynamic>> rows,
  ) =>
      rows.map(resumenDesdeMap).toList(growable: false);

  // Detalle

  static VentaDetalle detalleDesdeMapas({
    required Map<String, dynamic> ventaRow,
    required List<Map<String, dynamic>> itemsRows,
  }) {
    final ordenId = ventaRow['orden_id'] as int?;
    return VentaDetalle(
      id: ventaRow['id'] as int,
      numeroFactura: ventaRow['numero_factura'] as String,
      tipo: TipoVenta.desdeTexto(ventaRow['tipo'] as String? ?? 'SERVICIO'),
      ordenId: ordenId,
      numeroOrden: ordenId != null
          ? '#ORD-${ordenId.toString().padLeft(4, '0')}'
          : null,
      clienteId: ventaRow['cliente_id'] as int?,
      clienteNombre: ventaRow['cliente_nombre'] as String? ?? '— Sin cliente —',
      clienteDocumento: _documento(ventaRow),
      clienteDireccion: _texto(ventaRow['cliente_direccion']),
      clienteCiudad: _texto(ventaRow['cliente_ciudad']),
      clienteTelefono: _texto(ventaRow['cliente_telefono']),
      clienteCorreo: _texto(ventaRow['cliente_correo']),
      subtotal: _pesos(ventaRow['subtotal']),
      iva: _pesos(ventaRow['iva']),
      descuento: _pesos(ventaRow['descuento']),
      total: _pesos(ventaRow['total']),
      totalPagado: _pesos(ventaRow['total_pagado']),
      metodoPago: MetodoPago.desdeCodigo(ventaRow['metodo_pago'] as String? ?? 'EFECTIVO'),
      estadoPago: EstadoPago.desdeTexto(ventaRow['estado_pago'] as String? ?? 'PENDIENTE'),
      creadoEn: fechaDeSqlite(ventaRow['creado_en']),
      items: itemsRows.map(_itemDesdeMap).toList(growable: false),
    );
  }

  // Companions (escritura)

  /// Cabecera de una venta de mostrador: siempre `MOSTRADOR` y siempre
  /// `PAGADO`. El mostrador no fía —para eso está Cuentas por cobrar— y la
  /// única otra forma de venta que existía, la de una orden de servicio, se
  /// fue con el módulo de Facturación.
  static TablaVentasCompanion companionNuevo({
    required int usuarioId,
    required String numeroFactura,
    int? clienteId,
    required MetodoPago metodoPago,
    int iva = 0,
    int descuento = 0,
  }) =>
      TablaVentasCompanion.insert(
        usuarioId: usuarioId,
        numeroFactura: numeroFactura,
        tipo: Value(TipoVenta.mostrador.aTexto),
        clienteId: Value(clienteId),
        metodoPago: Value(metodoPago.codigo),
        estadoPago: Value(EstadoPago.pagado.aTexto),
        iva: Value(iva),
        descuento: Value(descuento),
        creadoEn: Value(DateTime.now()),
        actualizadoEn: Value(DateTime.now()),
      );

  /// Una línea de mostrador. Siempre es un producto: los servicios se cobran
  /// por una orden.
  static TablaVentaDetallesCompanion itemCompanionNuevo({
    required int ventaId,
    required int productoId,
    required String descripcion,
    required double cantidad,
    required int precioUnitario,
    int costoUnitario = 0,
  }) =>
      TablaVentaDetallesCompanion.insert(
        ventaId: ventaId,
        tipoItem: TipoItem.producto.aTexto,
        productoId: Value(productoId),
        descripcion: descripcion,
        cantidad: Value(cantidad),
        precioUnitario: precioUnitario,
        costoUnitario: Value(costoUnitario),
        // La cantidad puede ser fraccionaria (litros, metros); el importe
        // que se cobra, no. El redondeo va aquí, en el único punto por el
        // que pasa toda línea de venta.
        subtotal: (cantidad * precioUnitario).round(),
      );

  // Helpers privados

  static VentaItem _itemDesdeMap(Map<String, dynamic> row) => VentaItem(
        id: row['id'] as int,
        ventaId: row['venta_id'] as int,
        tipoItem: TipoItem.desdeTexto(row['tipo_item'] as String? ?? 'PRODUCTO'),
        productoId: row['producto_id'] as int?,
        servicioId: row['servicio_id'] as int?,
        tecnicoId: row['tecnico_id'] as int?,
        descripcion: row['descripcion'] as String? ?? '',
        sku: _texto(row['sku']),
        unidad: _texto(row['unidad']),
        cantidad: (row['cantidad'] as num? ?? 1).toDouble(),
        precioUnitario: _pesos(row['precio_unitario']),
        costoUnitario: _pesos(row['costo_unitario']),
        subtotal: _pesos(row['subtotal']),
      );

  /// El documento del cliente con su tipo delante: «CC 1.098.765.432».
  ///
  /// El tipo solo se pega si hay número: «CC» a secas no identifica a nadie y
  /// en la factura se leería como un dato cargado a medias.
  static String _documento(Map<String, dynamic> row) {
    final numero = _texto(row['cliente_documento']);
    if (numero.isEmpty) return '';
    final tipo = _texto(row['cliente_tipo_documento']);
    return tipo.isEmpty ? numero : '$tipo $numero';
  }

  static String _texto(dynamic valor) => (valor as String? ?? '').trim();

  /// Lee un importe de una fila cruda.
  ///
  /// Redondea en vez de castear porque las filas vienen de `customSelect`, y
  /// un `SUM` sobre una columna entera puede llegar como `num`. Truncar
  /// perdería el peso; redondear es lo que espera quien lo va a cobrar.
  static int _pesos(dynamic valor) => (valor as num? ?? 0).round();

}
