import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import '../enum/enum_cotizacion.dart';
import '../modelo/cotizacion_item.dart';
import '../modelo/cotizacion_resumen.dart';

// NOTA: TablaCotizacionData, TablaCotizacionCompanion, etc. son generados
// por build_runner después de registrar las tablas en app_db.dart.

class CotizacionMapper {
  CotizacionMapper._();

  static CotizacionResumen filaAResumen(
    TablaCotizacionData row, {
    required String nombreCliente,
    String? telefonoCliente,
    required String nombreMoto,
  }) {
    return CotizacionResumen(
      id: row.id,
      numero: row.numero,
      clienteId: row.clienteId,
      motoId: row.motoId,
      nombreCliente: nombreCliente,
      telefonoCliente: telefonoCliente,
      nombreMoto: nombreMoto,
      subtotal: row.subtotal,
      iva: row.iva,
      total: row.total,
      vigenciaHasta: row.vigenciaHasta,
      notas: row.notas,
      creadoEn: row.creadoEn,
    );
  }

  static CotizacionItem itemAModelo(TablaCotizacionItemData row) {
    return CotizacionItem(
      id: row.id,
      cotizacionId: row.cotizacionId,
      tipoItem: TipoItemCotizacionExt.desdeTexto(row.tipoItem),
      referenciaId: row.referenciaId,
      descripcion: row.descripcion,
      cantidad: row.cantidad,
      precioUnitario: row.precioUnitario,
      subtotal: row.subtotal,
    );
  }

  static TablaCotizacionCompanion nuevaACompanion({
    required String numero,
    int? clienteId,
    int? motoId,
    required int subtotal,
    required int iva,
    required int total,
    required String vigenciaHasta,
    String? notas,
  }) {
    return TablaCotizacionCompanion.insert(
      numero: numero,
      clienteId: Value(clienteId),
      motoId: Value(motoId),
      subtotal: Value(subtotal),
      iva: Value(iva),
      total: Value(total),
      vigenciaHasta: vigenciaHasta,
      notas: Value(notas),
    );
  }

  static TablaCotizacionItemCompanion itemACompanion({
    required int cotizacionId,
    required String tipoItem,
    int? referenciaId,
    required String descripcion,
    required double cantidad,
    required int precioUnitario,
    required int subtotal,
  }) {
    return TablaCotizacionItemCompanion.insert(
      cotizacionId: cotizacionId,
      tipoItem: tipoItem,
      referenciaId: Value(referenciaId),
      descripcion: descripcion,
      cantidad: cantidad,
      precioUnitario: precioUnitario,
      subtotal: subtotal,
    );
  }
}
