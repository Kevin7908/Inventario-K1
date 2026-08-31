import '../../../../backend/features/configuracion/repositorio/repositorio_configuracion.dart';
import '../modelo/negocio_impreso.dart';

export '../../configuracion/provider/configuracion_provider.dart'
    show repositorioConfiguracionProvider;

/// Lee el encabezado del taller **en el momento de imprimir**.
///
/// Antes esto era un `FutureProvider` y tenía un bug de los que no se ven en
/// un test de widget: Riverpod cachea el resultado de un provider mientras sus
/// dependencias no cambien, y la única dependencia era
/// `repositorioConfiguracionProvider`, que no cambia nunca. Resultado: se
/// cambiaba el nombre del negocio en Configuración, se emitía una factura
/// nueva y salía **el nombre viejo** hasta reiniciar la aplicación.
///
/// Ahora no se cachea nada: cada impresión pregunta. Es una consulta a una
/// tabla de siete filas contra SQLite local, así que el costo es ninguno
/// comparado con emitir un documento con los datos equivocados.
///
/// Recibe el repositorio por parámetro y no busca un provider por dentro, para
/// que un test pueda pasarle el suyo (`CLAUDE.md` §3).
///
/// Ejemplo:
/// ```dart
/// final negocio =
///     await leerNegocioImpreso(ref.read(repositorioConfiguracionProvider));
/// ```
Future<NegocioImpreso> leerNegocioImpreso(
  RepositorioConfiguracion repositorio,
) async =>
    NegocioImpreso.desdeConfiguracion(await repositorio.observarTodas().first);
