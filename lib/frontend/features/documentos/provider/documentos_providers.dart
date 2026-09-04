import '../../../../backend/features/configuracion/modelo/clave_configuracion.dart';
import '../../../../backend/features/configuracion/repositorio/repositorio_configuracion.dart';
import '../modelo/negocio_impreso.dart';
import '../servicio/formato_impreso.dart';

export '../../configuracion/provider/configuracion_provider.dart'
    show repositorioConfiguracionProvider;

/// Lo que la configuración le aporta a un impreso: quién emite y en qué papel.
///
/// Van juntos porque salen de la misma lectura. Separarlos costaría dos
/// consultas por cada factura para responder lo mismo.
class AjustesImpresion {
  const AjustesImpresion({required this.negocio, required this.formato});

  /// El encabezado del taller.
  final NegocioImpreso negocio;

  /// El papel del taller: el que sale sin preguntar. El diálogo de vista
  /// previa deja cambiarlo para una impresión suelta sin tocar la clave.
  final FormatoImpreso formato;
}

/// Lee el encabezado del taller y su formato de papel **en el momento de
/// imprimir**.
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
/// comparado con emitir un documento con los datos equivocados. Es también la
/// razón de que el formato se lea aquí y no en `main()`, como sí hace la tasa
/// de IVA: cambiar de impresora tiene que notarse sin reiniciar.
///
/// Usa `leerTodas` y no `observarTodas`: la segunda es la pantalla de
/// Configuración y exige `CONFIGURACION_VER`, que un cajero no tiene. Imprimir
/// una factura con el nombre del taller no es entrar a Configuración.
///
/// Recibe el repositorio por parámetro y no busca un provider por dentro, para
/// que un test pueda pasarle el suyo (`CLAUDE.md` §3).
///
/// Ejemplo:
/// ```dart
/// final ajustes =
///     await leerAjustesImpresion(ref.read(repositorioConfiguracionProvider));
/// await DialogoVistaPrevia.mostrar(
///   context,
///   documento: documentoDeVenta(venta: venta, negocio: ajustes.negocio),
///   formato: ajustes.formato,
/// );
/// ```
Future<AjustesImpresion> leerAjustesImpresion(
  RepositorioConfiguracion repositorio,
) async {
  final valores = await repositorio.leerTodas();
  const clave = ClaveConfiguracion.formatoImpresion;

  return AjustesImpresion(
    negocio: NegocioImpreso.desdeConfiguracion(valores),
    formato: FormatoImpreso.desdeCodigo(valores[clave] ?? clave.porDefecto),
  );
}
