import 'package:equatable/equatable.dart';

import '../../../../backend/features/configuracion/modelo/clave_configuracion.dart';

/// El taller que emite el documento, ya resuelto para imprimir.
///
/// Se arma desde `configuracion` con [desdeConfiguracion]: el nombre, el NIT y
/// la dirección del encabezado **se configuran, no se programan**, igual que
/// los permisos. Un taller que cambia de local edita un campo, no recompila.
///
/// Los campos vacíos no se pintan, así que un negocio que aún no cargó su NIT
/// obtiene un encabezado más corto, no uno con etiquetas huérfanas.
///
/// Parámetros:
/// - [nombre]: razón social. Es el único que siempre tiene valor, porque
///   `ClaveConfiguracion.nombreNegocio` trae «Taller de Motos» por defecto.
/// - [nit], [direccion], [telefono], [ciudad], [correo]: opcionales en la
///   práctica.
/// - [regimenIva]: cómo responde el negocio ante el impuesto («Responsable de
///   IVA»). Texto libre: se imprime tal cual y ningún cálculo lo consume.
/// - [actividadEconomica]: el código CIIU, que el cliente compara contra su
///   propia contabilidad.
///
/// Ejemplo:
/// ```dart
/// final negocio = NegocioImpreso.desdeConfiguracion(
///   await ref.read(configuracionProvider.future),
/// );
/// ```
class NegocioImpreso extends Equatable {
  const NegocioImpreso({
    required this.nombre,
    this.nit = '',
    this.direccion = '',
    this.telefono = '',
    this.ciudad = '',
    this.correo = '',
    this.regimenIva = '',
    this.actividadEconomica = '',
  });

  /// Traduce el mapa que devuelve `RepositorioConfiguracion.observarTodas`.
  factory NegocioImpreso.desdeConfiguracion(
    Map<ClaveConfiguracion, String> valores,
  ) {
    String leer(ClaveConfiguracion clave) =>
        (valores[clave] ?? clave.porDefecto).trim();

    return NegocioImpreso(
      nombre: leer(ClaveConfiguracion.nombreNegocio),
      nit: leer(ClaveConfiguracion.nit),
      direccion: leer(ClaveConfiguracion.direccion),
      telefono: leer(ClaveConfiguracion.telefono),
      ciudad: leer(ClaveConfiguracion.ciudad),
      correo: leer(ClaveConfiguracion.correo),
      regimenIva: leer(ClaveConfiguracion.regimenIva),
      actividadEconomica: leer(ClaveConfiguracion.actividadEconomica),
    );
  }

  final String nombre;
  final String nit;
  final String direccion;
  final String telefono;
  final String ciudad;
  final String correo;
  final String regimenIva;
  final String actividadEconomica;

  /// La segunda línea del encabezado: dirección y ciudad, si las hay.
  ///
  /// Se une con « · » y **se saltan las vacías**, para no imprimir un
  /// separador suelto cuando solo está cargado uno de los dos datos.
  String get lineaUbicacion =>
      [direccion, ciudad].where((s) => s.isNotEmpty).join(' · ');

  /// La tercera: NIT y teléfono, con la misma regla.
  String get lineaContacto => [
        if (nit.isNotEmpty) 'NIT $nit',
        if (telefono.isNotEmpty) 'Tel. $telefono',
        if (correo.isNotEmpty) correo,
      ].join(' · ');

  /// La cuarta, la fiscal: régimen y actividad económica.
  ///
  /// Va aparte de [lineaContacto] porque responde otra pregunta —cómo factura
  /// el negocio, no cómo se le llama— y porque un taller que no las cargó no
  /// tiene por qué imprimir una línea vacía.
  String get lineaFiscal => [
        if (regimenIva.isNotEmpty) regimenIva,
        if (actividadEconomica.isNotEmpty)
          'Actividad económica $actividadEconomica',
      ].join(' · ');

  @override
  List<Object?> get props => [
        nombre,
        nit,
        direccion,
        telefono,
        ciudad,
        correo,
        regimenIva,
        actividadEconomica,
      ];
}
