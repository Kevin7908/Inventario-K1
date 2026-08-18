import 'package:inventario_k1/backend/features/cotizaciones/enum/enum_cotizacion.dart';
import 'package:inventario_k1/backend/features/cotizaciones/modelo/cotizacion_detalle.dart';
import 'package:inventario_k1/backend/features/cotizaciones/modelo/cotizacion_resumen.dart';
import 'package:inventario_k1/backend/features/cotizaciones/repositorio/repositorio_cotizaciones.dart';

/// Repositorio de mentira para los tests del editor.
///
/// Existe por el guardado automático: el editor programa un `Timer` en cada
/// cambio, y sin esto un widget test acabaría escribiendo en la base real del
/// desarrollador. Además deja comprobar **qué** se guardó y **cuántas veces**,
/// que es justo lo que hay que verificar de un autoguardado.
class RepositorioCotizacionesFalso implements RepositorioCotizaciones {
  RepositorioCotizacionesFalso({this.fallaAlGuardar = false});

  /// Para probar qué hace el editor cuando la base rechaza la escritura.
  final bool fallaAlGuardar;

  /// Una entrada por llamada a `crear`, con los ítems que se guardaron.
  final List<List<ItemDraft>> creaciones = [];

  /// Una entrada por llamada a `actualizar`.
  final List<List<ItemDraft>> actualizaciones = [];

  int _siguienteId = 1;

  int get vecesGuardado => creaciones.length + actualizaciones.length;

  @override
  Future<int> crear({
    int? clienteId,
    int? motoId,
    required DateTime vigenciaHasta,
    String? notas,
    required List<ItemDraft> items,
  }) async {
    if (fallaAlGuardar) throw Exception('base caída');
    creaciones.add(items);
    return _siguienteId++;
  }

  @override
  Future<void> actualizar({
    required int id,
    int? clienteId,
    int? motoId,
    required DateTime vigenciaHasta,
    String? notas,
    required List<ItemDraft> items,
  }) async {
    if (fallaAlGuardar) throw Exception('base caída');
    actualizaciones.add(items);
  }

  @override
  Future<CotizacionDetalle> obtenerDetalle(int id) async => CotizacionDetalle(
        resumen: CotizacionResumen(
          id: id,
          numero: 'COT-2026-000$id',
          subtotal: 0,
          iva: 0,
          vigenciaHasta: DateTime(2026, 12, 31),
          creadoEn: DateTime(2026, 8, 16),
        ),
        items: const [],
      );

  // Lo que el editor no usa. Si algún día lo necesita, el test avisa con una
  // excepción clara en vez de devolver un vacío que parezca correcto.

  @override
  Stream<List<CotizacionResumen>> observarTodas() =>
      throw UnimplementedError('el editor no lista cotizaciones');

  @override
  Stream<PaginaCotizaciones> observarPagina({
    required FiltroCotizaciones filtro,
    required int pagina,
    required int tamano,
  }) =>
      throw UnimplementedError('el editor no pagina');

  @override
  Stream<ResumenCotizaciones> observarResumen() =>
      throw UnimplementedError('el editor no muestra el resumen');

  @override
  Future<List<CotizacionResumen>> obtenerTodas() =>
      throw UnimplementedError('el editor no lista cotizaciones');

  @override
  Future<void> eliminar(int id) =>
      throw UnimplementedError('el editor no borra cotizaciones');

  @override
  Future<void> agregarItem({
    required int cotizacionId,
    required TipoItemCotizacion tipo,
    int? referenciaId,
    required String descripcion,
    required double cantidad,
    required int precioUnitario,
  }) =>
      throw UnimplementedError('el editor guarda la cotización entera');

  @override
  Future<void> eliminarItem(int itemId, int cotizacionId) =>
      throw UnimplementedError('el editor guarda la cotización entera');
}
