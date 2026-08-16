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

/// Filtros que el repositorio traduce a un `WHERE`.
///
/// Es un value object con igualdad estructural para que reabrir el stream con
/// el mismo filtro no cuente como cambio.
final class FiltroCotizaciones {
  const FiltroCotizaciones({this.busqueda = '', this.estado});

  /// Texto libre. Busca en el número de la cotización y en el nombre del
  /// cliente, que llega por el JOIN.
  final String busqueda;

  /// `null` = todos los estados.
  final EstadoCotizacion? estado;

  @override
  bool operator ==(Object other) =>
      other is FiltroCotizaciones &&
      other.busqueda == busqueda &&
      other.estado == estado;

  @override
  int get hashCode => Object.hash(busqueda, estado);
}

/// Un tramo del listado más el total real.
///
/// [total] cuenta todas las filas que cumplen el filtro, no las de la página.
final class PaginaCotizaciones {
  const PaginaCotizaciones({required this.items, required this.total});

  final List<CotizacionResumen> items;
  final int total;
}

/// Conteos del encabezado, resueltos con un solo `COUNT` por columna.
///
/// [montoVigente] suma el total de las cotizaciones que todavía se pueden
/// cerrar: es el dinero que hay sobre la mesa, no el histórico.
typedef ResumenCotizaciones = ({
  int total,
  int vigentes,
  int porVencer,
  int vencidas,
  int montoVigente,
});

abstract class RepositorioCotizaciones {
  Stream<List<CotizacionResumen>> observarTodas();

  /// Una página del listado. El `WHERE`, el `COUNT` y el `LIMIT` los resuelve
  /// SQLite, incluido el estado —que sale de comparar `vigencia_hasta` con la
  /// fecha de hoy y antes se calculaba en Dart sobre la lista entera.
  Stream<PaginaCotizaciones> observarPagina({
    required FiltroCotizaciones filtro,
    required int pagina,
    required int tamano,
  });

  Stream<ResumenCotizaciones> observarResumen();

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
