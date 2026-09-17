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
    int cantidadItems = 0,
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
      descuento: row.descuento,
      iva: row.iva,
      vigenciaHasta: row.vigenciaHasta,
      notas: row.notas,
      creadoEn: row.creadoEn,
      cantidadItems: cantidadItems,
    );
  }

  static CotizacionItem itemAModelo(TablaCotizacionItemData row) {
    return CotizacionItem(
      id: row.id,
      cotizacionId: row.cotizacionId,
      tipoItem: TipoItemCotizacion.desdeTexto(row.tipoItem),
      // La tabla guarda la referencia en la columna que corresponde al tipo,
      // para que la FK la pueda verificar; el modelo la expone como una sola,
      // que es como se lee bien desde la vista.
      referenciaId: row.productoId ?? row.servicioId,
      descripcion: row.descripcion,
      cantidad: row.cantidad,
      precioUnitario: row.precioUnitario,
      subtotal: row.subtotal,
    );
  }

  static TablaCotizacionCompanion nuevaACompanion({
    required int usuarioId,
    required String numero,
    int? clienteId,
    int? motoId,
    required int subtotal,
    int descuento = 0,
    required int iva,
    required DateTime vigenciaHasta,
    String? notas,
  }) {
    return TablaCotizacionCompanion.insert(
      usuarioId: usuarioId,
      numero: numero,
      clienteId: Value(clienteId),
      motoId: Value(motoId),
      subtotal: Value(subtotal),
      descuento: Value(descuento),
      iva: Value(iva),
      vigenciaHasta: vigenciaHasta,
      notas: Value(notas),
      actualizadoEn: Value(DateTime.now()),
    );
  }

  /// Reparte [referenciaId] en la columna que le toca según [tipo].
  ///
  /// Es el único punto donde se decide, y por eso el `CHECK` de la tabla no
  /// puede saltarse: una línea `LIBRE` deja las dos en NULL, y las otras dos
  /// llenan exactamente una.
  static TablaCotizacionItemCompanion itemACompanion({
    required int usuarioId,
    required int cotizacionId,
    required TipoItemCotizacion tipo,
    int? referenciaId,
    required String descripcion,
    required double cantidad,
    required int precioUnitario,
    required int subtotal,
  }) {
    return TablaCotizacionItemCompanion.insert(
      usuarioId: usuarioId,
      cotizacionId: cotizacionId,
      tipoItem: tipo.valor,
      productoId: Value(
        tipo == TipoItemCotizacion.producto ? referenciaId : null,
      ),
      servicioId: Value(
        tipo == TipoItemCotizacion.servicio ? referenciaId : null,
      ),
      descripcion: descripcion,
      cantidad: cantidad,
      precioUnitario: precioUnitario,
      subtotal: subtotal,
    );
  }
}
