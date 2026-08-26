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

  /// Ya hay otra ficha con ese teléfono. Es aparte de [documentoDuplicado]
  /// porque el conflicto puede ser con **otro rol**: el número que se está
  /// escribiendo para un cliente puede ser el de un proveedor, y el mensaje
  /// tiene que poder decirlo.
  telefonoDuplicado,

  /// La moto ya está registrada a nombre de otro cliente. Es distinto de
  /// [documentoDuplicado] porque el campo en conflicto no es del registro que
  /// se está guardando, sino de una de sus motos: la vista necesita saberlo
  /// para señalar la fila correcta.
  placaRegistrada,

  /// El dato no cumple una regla de negocio (vacío, muy corto…).
  validacion,

  /// La base de datos rechazó la operación o falló al ejecutarla.
  persistencia,
}
