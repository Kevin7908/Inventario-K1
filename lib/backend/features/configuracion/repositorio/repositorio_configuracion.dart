import '../modelo/clave_configuracion.dart';

/// Los datos del negocio: NIT, dirección, IVA…
///
/// No hay `crear` ni `eliminar`: las claves son las de
/// [ClaveConfiguracion] y no cambian en tiempo de ejecución. Solo se leen y se
/// escriben.
abstract class RepositorioConfiguracion {
  /// El valor de [clave], o su `porDefecto` si nadie la ha configurado.
  Future<String> leer(ClaveConfiguracion clave);

  /// Todas las claves con su valor efectivo, listo para pintar el formulario.
  Stream<Map<ClaveConfiguracion, String>> observarTodas();

  /// Guarda [valor] en [clave], creando la fila si no existía.
  Future<void> guardar(ClaveConfiguracion clave, String valor);
}
