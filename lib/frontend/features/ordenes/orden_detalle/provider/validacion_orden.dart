import '../../../../../backend/features/ventas/ordenes/enum/enum_ordenes.dart';
import '../../../../../core/resultado.dart';
import '../modelo/linea_orden_editor.dart';

/// Reglas de la orden que la interfaz puede comprobar antes de escribir.
///
/// Vive fuera de la vista y fuera del notifier para poder probarse sola.
/// Devuelve `null` cuando todo está en orden y un [Fallo] con el texto ya
/// redactado cuando no.
///
/// Es **mucho más delgada** que `validarCotizacion`, y el motivo importa: una
/// cotización se guarda entera de una vez, así que hay un momento en el que
/// tiene sentido preguntar «¿está completa?». Una orden se escribe línea a
/// línea, y cada línea se valida antes de existir —el botón «Agregar» está
/// apagado hasta que el servicio tiene técnico y precio—. Lo que queda por
/// comprobar aquí es solo la cabecera y el cambio de estado.

/// Kilometraje de entrada. El `CHECK` de la tabla lo rechaza si es negativo,
/// pero el error de SQLite no se le puede enseñar a nadie.
Resultado? validarCabeceraOrden({required int kilometrajeEntrada}) {
  if (kilometrajeEntrada < 0) {
    return const Fallo(
      MotivoFallo.validacion,
      'El kilometraje no puede ser negativo.',
    );
  }
  return null;
}

/// Si la orden puede pasar de [desde] a [hacia].
///
/// El único paso que se bloquea aquí es el que no tiene vuelta atrás sin
/// romper el inventario: una orden `ANULADA` ya devolvió sus repuestos, así
/// que reabrirla dejaría las líneas anotadas sobre stock que volvió al
/// estante. Anular se hace desde su propio botón, con confirmación, no desde
/// el selector.
Resultado? validarCambioEstado({
  required EstadoOrden desde,
  required EstadoOrden hacia,
}) {
  if (desde == hacia) return null;

  if (desde == EstadoOrden.anulada) {
    return const Fallo(
      MotivoFallo.validacion,
      'Una orden anulada no se puede reabrir. Crea una orden nueva.',
    );
  }

  return null;
}

/// Qué hace falta antes de cerrar la orden, para poder avisar **antes** de
/// intentarlo.
///
/// No sustituye a la verificación del repositorio, que es la que manda: al
/// cerrar se comprueba el stock de todos los repuestos dentro de la
/// transacción, y si no alcanza la orden no cambia de estado. Esto es solo
/// para no dejar cerrar una orden a la que le falta lo evidente.
Resultado? validarCierre({required List<LineaOrdenEditor> lineas}) {
  final sinPrecio = lineas.where((l) => l.precioUnitario <= 0).toList();
  if (sinPrecio.isNotEmpty) {
    return Fallo(
      MotivoFallo.validacion,
      'Ponle precio a "${sinPrecio.first.descripcion}" antes de cerrar la '
      'orden.',
    );
  }
  return null;
}

/// Traduce lo que lanza el repositorio a algo que se le pueda enseñar al
/// usuario.
///
/// El backend lanza `Exception('Stock insuficiente…')` con el nombre del
/// producto dentro; `toString()` le antepone «Exception: », que no aporta
/// nada y solo delata la implementación.
String mensajeDeExcepcion(Object error) {
  final texto = error.toString();
  const prefijo = 'Exception: ';
  return texto.startsWith(prefijo) ? texto.substring(prefijo.length) : texto;
}
