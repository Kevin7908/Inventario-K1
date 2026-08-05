/// Resultado de una operación de escritura que puede fallar.
///
/// Reemplaza al viejo `Future<String?>` —`null` en éxito, mensaje de error si
/// no—, que mezclaba control de flujo con texto de interfaz: obligaba a
/// comparar cadenas para saber *por qué* falló algo y ataba el mensaje al
/// backend en vez de dejarlo en la vista.
///
/// Ejemplo:
/// ```dart
/// switch (await notifier.crear(producto)) {
///   case Exito():
///     controlador.cerrar();
///   case Fallo(motivo: MotivoFallo.skuDuplicado):
///     _resaltarCampoSku();
///   case Fallo(:final mensaje):
///     mostrarError(mensaje);
/// }
/// ```
sealed class Resultado {
  const Resultado();

  /// Atajo para los casos en que solo importa si salió bien.
  bool get exitoso => this is Exito;
}

/// La operación se completó.
final class Exito extends Resultado {
  const Exito();
}

/// La operación no se completó.
///
/// [motivo] permite reaccionar distinto según el tipo de fallo; [mensaje] es
/// el texto ya redactado para mostrar al usuario.
final class Fallo extends Resultado {
  const Fallo(this.motivo, this.mensaje);

  final MotivoFallo motivo;
  final String mensaje;
}

/// Por qué falló una operación.
enum MotivoFallo {
  /// Ya existe otro registro con ese nombre.
  nombreDuplicado,

  /// Ya existe otro producto con ese SKU.
  skuDuplicado,

  /// Ya existe otro registro con ese documento (NIT, cédula…).
  documentoDuplicado,

  /// El dato no cumple una regla de negocio (vacío, muy corto…).
  validacion,

  /// La base de datos rechazó la operación o falló al ejecutarla.
  persistencia,
}
