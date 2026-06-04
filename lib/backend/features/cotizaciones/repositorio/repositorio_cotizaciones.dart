import '../enum/enum_cotizacion.dart';
import '../modelo/cotizacion_detalle.dart';
import '../modelo/cotizacion_resumen.dart';

/// Borrador de ítem para crear/actualizar cotizaciones.
class ItemDraft {
  final TipoItemCotizacion tipo;
  final int? referenciaId;
  final String descripcion;
  final double cantidad;
  final int precioUnitario;

  const ItemDraft({
    required this.tipo,
    this.referenciaId,
    required this.descripcion,
    required this.cantidad,
    required this.precioUnitario,
  });

  int get subtotal => (cantidad * precioUnitario).round();
}

abstract class RepositorioCotizaciones {
  Stream<List<CotizacionResumen>> observarTodas();

  Future<List<CotizacionResumen>> obtenerTodas();

  Future<CotizacionDetalle> obtenerDetalle(int id);

  Future<int> crear({
    int? clienteId,
    int? motoId,
    required String vigenciaHasta,
    String? notas,
    required List<ItemDraft> items,
  });

  Future<void> actualizar({
    required int id,
    int? clienteId,
    int? motoId,
    required String vigenciaHasta,
    String? notas,
    required List<ItemDraft> items,
  });

  Future<void> eliminar(int id);

  Future<void> agregarItem({
    required int cotizacionId,
    required TipoItemCotizacion tipo,
    int? referenciaId,
    required String descripcion,
    required double cantidad,
    required int precioUnitario,
  });

  Future<void> eliminarItem(int itemId, int cotizacionId);
}
