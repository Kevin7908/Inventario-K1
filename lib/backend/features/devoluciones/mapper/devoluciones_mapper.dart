import '../../../share/database/app_db.dart';
import '../enum/enum_devoluciones.dart';
import '../modelo/devolucion.dart';

/// El único que conoce las dos formas: la fila de Drift y el modelo de
/// dominio. Las consultas de este módulo van por `customSelect` porque
/// necesitan `JOIN` con `venta_detalles`, así que los mapas llegan crudos.
abstract final class DevolucionesMapper {
  DevolucionesMapper._();

  static LineaDevolvible devolvibleDesdeMapa(Map<String, dynamic> f) {
    return LineaDevolvible(
      ventaDetalleId: f['id'] as int,
      productoId: f['producto_id'] as int?,
      descripcion: f['descripcion'] as String,
      cantidadVendida: (f['cantidad'] as num).toDouble(),
      cantidadDevuelta: (f['devuelta'] as num?)?.toDouble() ?? 0,
      precioUnitario: (f['precio_unitario'] as num).toInt(),
    );
  }

  static DevolucionLinea lineaDesdeMapa(Map<String, dynamic> f) {
    return DevolucionLinea(
      id: f['id'] as int,
      ventaDetalleId: f['venta_detalle_id'] as int,
      productoId: f['producto_id'] as int?,
      descripcion: f['descripcion'] as String,
      cantidad: (f['cantidad'] as num).toDouble(),
      precioUnitario: (f['precio_unitario'] as num).toInt(),
    );
  }

  /// [lineas] llega aparte porque se trae en **una sola** consulta para todas
  /// las devoluciones, no una por documento (`REGLAS_BD.md` §5, N+1).
  static Devolucion cabeceraDesdeMapa(
    Map<String, dynamic> f,
    List<DevolucionLinea> lineas,
  ) {
    return Devolucion(
      id: f['id'] as int,
      numero: f['numero'] as String,
      ventaId: f['venta_id'] as int,
      numeroFactura: f['numero_factura'] as String? ?? '',
      motivo: MotivoDevolucion.desdeCodigo(f['motivo'] as String),
      total: (f['total'] as num).toInt(),
      notas: f['notas'] as String?,
      usuarioId: f['usuario_id'] as int,
      recibidoPor: (f['recibido_por'] as String? ?? '').trim(),
      creadoEn: _fecha(f['creado_en']),
      lineas: lineas,
    );
  }

  /// Drift guarda las fechas como segundos desde la época; un `customSelect`
  /// las devuelve así de crudas.
  static DateTime _fecha(Object? valor) => switch (valor) {
        final int segundos =>
          DateTime.fromMillisecondsSinceEpoch(segundos * 1000),
        final DateTime fecha => fecha,
        _ => DateTime.now(),
      };

  static TablaDevolucionDetalleCompanion detalleACompanion({
    required int devolucionId,
    required int ventaDetalleId,
    required double cantidad,
    required int precioUnitario,
  }) {
    return TablaDevolucionDetalleCompanion.insert(
      devolucionId: devolucionId,
      ventaDetalleId: ventaDetalleId,
      cantidad: cantidad,
      precioUnitario: precioUnitario,
    );
  }
}
