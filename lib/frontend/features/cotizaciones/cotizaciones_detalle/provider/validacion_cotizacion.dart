import '../../../../../core/resultado.dart';
import '../modelo/item_cotizacion_editor.dart';

/// Reglas de negocio de una cotización antes de guardarla.
///
/// Vive fuera de la vista y fuera del notifier para poder probarse sola.
/// Devuelve `null` cuando todo está en orden y un [Fallo] con el texto ya
/// redactado cuando no.
///
/// **Cliente y moto no se exigen**: se cotiza a quien entra a preguntar un
/// precio, y muchas veces todavía no es cliente de nadie.
Resultado? validarCotizacion({
  required List<ItemCotizacionEditor> items,
  required DateTime vigenciaHasta,
}) {
  if (items.isEmpty) {
    return const Fallo(
      MotivoFallo.validacion,
      'Agrega al menos una línea a la cotización.',
    );
  }

  for (final item in items) {
    if (item.cantidad <= 0) {
      return Fallo(
        MotivoFallo.validacion,
        'La cantidad de "${item.descripcion}" tiene que ser mayor que cero.',
      );
    }
    // El precio de un producto lo pone el catálogo; el de un servicio o una
    // línea libre lo teclea quien cotiza, y ahí sí puede quedar en cero.
    if (item.tipo.precioManual && item.precioUnitario <= 0) {
      return Fallo(
        MotivoFallo.validacion,
        'Ponle precio a "${item.descripcion}".',
      );
    }
  }

  final hoy = DateTime.now();
  final soloHoy = DateTime(hoy.year, hoy.month, hoy.day);
  final soloVigencia = DateTime(
    vigenciaHasta.year,
    vigenciaHasta.month,
    vigenciaHasta.day,
  );
  if (soloVigencia.isBefore(soloHoy)) {
    return const Fallo(
      MotivoFallo.validacion,
      'La cotización no puede vencer antes de hoy.',
    );
  }

  return null;
}
