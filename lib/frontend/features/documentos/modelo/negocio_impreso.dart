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
/// - [nit], [direccion], [telefono], [ciudad]: opcionales en la práctica.
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
    );
  }

  final String nombre;
  final String nit;
  final String direccion;
  final String telefono;
  final String ciudad;

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
      ].join(' · ');

  @override
  List<Object?> get props => [nombre, nit, direccion, telefono, ciudad];
}
