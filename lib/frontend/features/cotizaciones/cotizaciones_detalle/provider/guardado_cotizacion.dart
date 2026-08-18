import '../../../../../backend/features/cotizaciones/repositorio/repositorio_cotizaciones.dart';
import '../modelo/item_cotizacion_editor.dart';

/// Lo que devuelve un guardado: la cotización ya existe y tiene consecutivo.
typedef CotizacionGuardada = ({int id, String numero});

/// Escribe la cotización en la base.
///
/// Vive aparte del notifier para separar dos responsabilidades que se estaban
/// mezclando: **cuándo** guardar —el retardo, el estado de la barra, qué hacer
/// si falla— es del notifier; **cómo** se escribe es de aquí.
///
/// Decide sola entre crear y actualizar según venga o no un [id], y en el caso
/// de crear relee el consecutivo, que lo genera el repositorio.
class GuardadoCotizacion {
  const GuardadoCotizacion(this._repo);

  final RepositorioCotizaciones _repo;

  Future<CotizacionGuardada> guardar({
    required int? id,
    required int? clienteId,
    required int? motoId,
    required DateTime vigenciaHasta,
    required String notas,
    required List<ItemCotizacionEditor> items,
  }) async {
    final drafts = items.map((i) => i.aDraft()).toList(growable: false);
    final limpias = notas.trim().isEmpty ? null : notas.trim();

    if (id != null) {
      await _repo.actualizar(
        id: id,
        clienteId: clienteId,
        motoId: motoId,
        vigenciaHasta: vigenciaHasta,
        notas: limpias,
        items: drafts,
      );
      return (id: id, numero: '');
    }

    final nuevo = await _repo.crear(
      clienteId: clienteId,
      motoId: motoId,
      vigenciaHasta: vigenciaHasta,
      notas: limpias,
      items: drafts,
    );
    // El número lo arma el repositorio (`COT-2026-0001`), así que hay que
    // releerlo para poder mostrarlo en la barra.
    final creada = await _repo.obtenerDetalle(nuevo);
    return (id: nuevo, numero: creada.resumen.numero);
  }

}
