import '../modelo/clave_configuracion.dart';

/// Los datos del negocio: NIT, dirección, IVA…
///
/// No hay `crear` ni `eliminar`: las claves son las de
/// [ClaveConfiguracion] y no cambian en tiempo de ejecución. Solo se leen y se
/// escriben.
abstract class RepositorioConfiguracion {
  /// El valor de [clave], o su `porDefecto` si nadie la ha configurado.
  ///
  /// No pide permiso: leer el nombre del taller para el encabezado de una
  /// factura no es entrar a Configuración.
  Future<String> leer(ClaveConfiguracion clave);

  /// Todas las claves con su valor efectivo, de una sola lectura.
  ///
  /// No pide permiso, por lo mismo que [leer]: es lo que consulta el
  /// encabezado de cada documento impreso para saber cómo se llama el taller,
  /// y un cajero imprime facturas sin tener `CONFIGURACION_VER`.
  Future<Map<ClaveConfiguracion, String>> leerTodas();

  /// Todas las claves con su valor efectivo, **observadas**.
  ///
  /// Exige `CONFIGURACION_VER`: esto **es** la pantalla de Configuración, y
  /// lo que la distingue de [leerTodas] es que se queda escuchando para
  /// repintar el formulario. Quien solo necesita el dato usa la otra.
  Stream<Map<ClaveConfiguracion, String>> observarTodas();

  /// Guarda [valor] en [clave], creando la fila si no existía.
  ///
  /// Exige `CONFIGURACION_EDITAR`.
  Future<void> guardar(ClaveConfiguracion clave, String valor);
}
