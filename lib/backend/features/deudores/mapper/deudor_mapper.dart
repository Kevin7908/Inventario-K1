import '../../../share/dominio/metodo_pago.dart';
import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import '../enum/enum_deudor.dart';
import '../modelo/deudor_pago.dart';
import '../modelo/deudor_resumen.dart';

class DeudorMapper {
  DeudorMapper._();

  static DeudorResumen filaAResumen(
    TablaDeudorData row, {
    required String nombreCliente,
  }) {
    return DeudorResumen(
      id: row.id,
      numero: row.numero,
      clienteId: row.clienteId,
      nombreCliente: nombreCliente,
      ventaId: row.ventaId,
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

  static TablaDeudorCompanion nuevaACompanion({
    required String numero,
    required int clienteId,
    int? ventaId,
    required String concepto,
    required int montoTotal,
    DateTime? fechaVencimiento,
    String? notas,
  }) {
    return TablaDeudorCompanion.insert(
      numero: numero,
      clienteId: clienteId,
      ventaId: Value(ventaId),
      concepto: concepto,
      montoTotal: montoTotal,
      fechaVencimiento: Value(fechaVencimiento),
      notas: Value(notas),
    );
  }

  static TablaDeudorPagoCompanion pagoACompanion({
    required int deudorId,
    required int monto,
    required MetodoPago metodoPago,
    String? notas,
  }) {
    return TablaDeudorPagoCompanion.insert(
      deudorId: deudorId,
      monto: monto,
      metodoPago: metodoPago.codigo,
      notas: Value(notas),
    );
  }
}
