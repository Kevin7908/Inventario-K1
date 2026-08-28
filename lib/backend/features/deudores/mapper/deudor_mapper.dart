import '../../../share/dominio/metodo_pago.dart';
import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import '../enum/enum_deudor.dart';
import '../modelo/deudor_item.dart';
import '../modelo/deudor_pago.dart';
import '../modelo/deudor_resumen.dart';

class DeudorMapper {
  DeudorMapper._();

  static DeudorResumen filaAResumen(
    TablaDeudorData row, {
    required String nombreCliente,
    String? nombreMoto,
    String? placaMoto,
  }) {
    return DeudorResumen(
      id: row.id,
      numero: row.numero,
      clienteId: row.clienteId,
      nombreCliente: nombreCliente,
      motoId: row.motoId,
      nombreMoto: nombreMoto,
      placaMoto: placaMoto,
      concepto: row.concepto,
      montoTotal: row.montoTotal,
      montoPagado: row.montoPagado,
      estado: EstadoDeudor.desdeValor(row.estado),
      fechaVencimiento: row.fechaVencimiento,
      notas: row.notas,
      creadoEn: row.creadoEn,
    );
  }

  static DeudorPago pagoAModelo(TablaDeudorPagoData row) {
    return DeudorPago(
      id: row.id,
      deudorId: row.deudorId,
      monto: row.monto,
      metodoPago: MetodoPago.desdeCodigo(row.metodoPago),
      notas: row.notas,
      fechaPago: row.fechaPago,
    );
  }

  static DeudorItem itemAModelo(
    TablaDeudorItemData row, {
    required String nombreProducto,
    required String sku,
    String? imagenUrl,
  }) {
    return DeudorItem(
      id: row.id,
      deudorId: row.deudorId,
      productoId: row.productoId,
      nombreProducto: nombreProducto,
      sku: sku,
      imagenUrl: imagenUrl,
      cantidad: row.cantidad,
      precioUnitario: row.precioUnitario,
    );
  }

  static TablaDeudorCompanion nuevaACompanion({
    required int usuarioId,
    required String numero,
    required int clienteId,
    int? motoId,
    String? concepto,
    DateTime? fechaVencimiento,
    String? notas,
  }) {
    return TablaDeudorCompanion.insert(
      usuarioId: usuarioId,
      numero: numero,
      clienteId: clienteId,
      motoId: Value(motoId),
      concepto: Value(concepto),
      fechaVencimiento: Value(fechaVencimiento),
      notas: Value(notas),
    );
  }

  static TablaDeudorItemCompanion itemACompanion({
    required int deudorId,
    required int productoId,
    required double cantidad,
    required int precioUnitario,
  }) {
    return TablaDeudorItemCompanion.insert(
      deudorId: deudorId,
      productoId: productoId,
      cantidad: cantidad,
      precioUnitario: precioUnitario,
    );
  }

  static TablaDeudorPagoCompanion pagoACompanion({
    required int usuarioId,
    required int deudorId,
    required int monto,
    required MetodoPago metodoPago,
    String? notas,
  }) {
    return TablaDeudorPagoCompanion.insert(
      usuarioId: usuarioId,
      deudorId: deudorId,
      monto: monto,
      metodoPago: metodoPago.codigo,
      notas: Value(notas),
    );
  }
}
