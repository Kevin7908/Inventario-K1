import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import '../enum/enum_compras.dart';
import '../modelo/compra_item.dart';
import '../modelo/compra_resumen.dart';

/// Traduce entre las filas de `compras` / `compra_detalles` y los modelos de
/// dominio. Es el único que conoce las dos formas (§8).
abstract final class CompraMapper {
  CompraMapper._();

  static CompraResumen filaAResumen(
    TablaCompraData fila, {
    required String proveedorNombre,
    int lineas = 0,
  }) {
    return CompraResumen(
      id: fila.id,
      numero: fila.numero,
      proveedorId: fila.proveedorId,
      proveedorNombre: proveedorNombre,
      numeroFactura: fila.numeroFactura,
      fecha: fila.fecha,
      total: fila.total,
      estado: EstadoCompra.desdeCodigo(fila.estado),
      lineas: lineas,
      notas: fila.notas,
      creadoEn: fila.creadoEn,
    );
  }

  /// La descripción sale de la **fila**, no del catálogo: es el snapshot del
  /// día en que llegó la mercancía (§1.2). El SKU y la foto sí son de hoy.
  static CompraItem itemAModelo(
    TablaCompraDetalleData fila, {
    String? sku,
    String? imagenUrl,
  }) {
    return CompraItem(
      id: fila.id,
      compraId: fila.compraId,
      productoId: fila.productoId,
      descripcion: fila.descripcion,
      sku: sku,
      imagenUrl: imagenUrl,
      cantidad: fila.cantidad,
      costoUnitario: fila.costoUnitario,
    );
  }

  /// El total nace en cero: lo escribe el repositorio recalculándolo desde las
  /// líneas, nunca sumándole el delta a lo que hubiera.
  static TablaCompraCompanion nuevaACompanion({
    required int usuarioId,
    required String numero,
    required int proveedorId,
    required DateTime fecha,
    String? numeroFactura,
    String? notas,
  }) {
    return TablaCompraCompanion.insert(
      usuarioId: usuarioId,
      numero: numero,
      proveedorId: proveedorId,
      fecha: Value(fecha),
      numeroFactura: Value(numeroFactura),
      notas: Value(notas),
    );
  }

  static TablaCompraDetalleCompanion itemACompanion({
    required int compraId,
    required int productoId,
    required String descripcion,
    required double cantidad,
    required int costoUnitario,
  }) {
    return TablaCompraDetalleCompanion.insert(
      compraId: compraId,
      productoId: productoId,
      descripcion: descripcion,
      cantidad: cantidad,
      costoUnitario: costoUnitario,
    );
  }
}
