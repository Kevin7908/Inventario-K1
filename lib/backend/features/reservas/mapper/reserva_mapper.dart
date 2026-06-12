import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import '../enum/enum_reserva.dart';
import '../modelo/reserva_abono.dart';
import '../modelo/reserva_item.dart';
import '../modelo/reserva_resumen.dart';

class ReservaMapper {
  ReservaMapper._();

  static ReservaResumen filaAResumen(
    TablaReservaData row, {
    required String nombreCliente,
    String? nombreMoto,
    String? placaMoto,
  }) {
    return ReservaResumen(
      id: row.id,
      numero: row.numero,
      clienteId: row.clienteId,
      nombreCliente: nombreCliente,
      motoId: row.motoId,
      nombreMoto: nombreMoto,
      placaMoto: placaMoto,
      cotizacionId: row.cotizacionId,
      estado: EstadoReserva.desdeValor(row.estado),
      totalReserva: row.totalReserva,
      pagadoAcumulado: row.pagadoAcumulado,
      creadoEn: row.creadoEn,
      fechaLimite: row.fechaLimite,
    );
  }

  static ReservaItem itemAModelo(
    TablaReservaItemData row, {
    required String nombreProducto,
    required String sku,
    String? imagenUrl,
  }) {
    return ReservaItem(
      id: row.id,
      reservaId: row.reservaId,
      productoId: row.productoId,
      nombreProducto: nombreProducto,
      sku: sku,
      imagenUrl: imagenUrl,
      cantidad: row.cantidad,
      precioUnitario: row.precioUnitario,
    );
  }

  static ReservaAbono abonoAModelo(TablaReservaAbonoData row) {
    return ReservaAbono(
      id: row.id,
      reservaId: row.reservaId,
      monto: row.monto,
      metodoPago: row.metodoPago,
      referenciaPago: row.referenciaPago,
      fechaPago: row.fechaPago,
    );
  }

  static TablaReservaCompanion nuevaACompanion({
    required String numero,
    required int clienteId,
    int? motoId,
    int? cotizacionId,
    required int totalReserva,
    required String fechaLimite,
  }) {
    return TablaReservaCompanion.insert(
      numero: numero,
      clienteId: clienteId,
      motoId: Value(motoId),
      cotizacionId: Value(cotizacionId),
      totalReserva: totalReserva,
      fechaLimite: Value(fechaLimite),
    );
  }

  static TablaReservaItemCompanion itemACompanion({
    required int reservaId,
    required int productoId,
    required double cantidad,
    required int precioUnitario,
  }) {
    return TablaReservaItemCompanion.insert(
      reservaId: reservaId,
      productoId: productoId,
      cantidad: cantidad,
      precioUnitario: precioUnitario,
    );
  }

  static TablaReservaAbonoCompanion abonoACompanion({
    required int reservaId,
    required int monto,
    required String metodoPago,
    String? referenciaPago,
  }) {
    return TablaReservaAbonoCompanion.insert(
      reservaId: reservaId,
      monto: monto,
      metodoPago: metodoPago,
      referenciaPago: Value(referenciaPago),
    );
  }
}
