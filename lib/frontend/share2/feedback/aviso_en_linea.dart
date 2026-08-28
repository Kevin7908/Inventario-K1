import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Qué clase de aviso es. Decide el color y el ícono.
enum TonoAviso {
  informacion,
  exito,
  alerta,
  error;

  Color get _color => switch (this) {
        TonoAviso.informacion => ColoresApp.statusInfo,
        TonoAviso.exito => ColoresApp.statusSuccess,
        TonoAviso.alerta => ColoresApp.statusWarning,
        TonoAviso.error => ColoresApp.statusDanger,
      };

  Color get _fondo => switch (this) {
        TonoAviso.informacion => ColoresApp.statusInfoBg,
        TonoAviso.exito => ColoresApp.statusSuccessBg,
        TonoAviso.alerta => ColoresApp.statusWarningBg,
        TonoAviso.error => ColoresApp.statusDangerBg,
      };

  IconData get _icono => switch (this) {
        TonoAviso.informacion => Icons.info_outline_rounded,
        TonoAviso.exito => Icons.check_circle_outline_rounded,
        TonoAviso.alerta => Icons.warning_amber_rounded,
        TonoAviso.error => Icons.error_outline_rounded,
      };
}

/// Aviso que se queda en la pantalla, dentro del contenido.
///
/// Es la contraparte de `MensajeApp`: aquel es la barra de abajo que se va
/// sola, y sirve para confirmar algo que ya pasó. Este se queda, y sirve para
/// lo que el usuario todavía tiene que leer mientras decide —«la contraseña no
/// coincide», «el correo no está configurado»—. Un `SnackBar` de cinco
/// segundos no alcanza para eso.
///
/// Parámetros:
/// - [mensaje]: el texto del aviso.
/// - [tono]: de qué clase es. Por defecto [TonoAviso.error], que es el caso
///   más común dentro de un formulario.
/// - [titulo]: primera línea en negrita, opcional. Para cuando el mensaje
///   necesita un encabezado corto además del detalle.
///
/// Ejemplo:
/// ```dart
/// AvisoEnLinea(mensaje: 'Usuario o contraseña incorrectos.')
///
/// AvisoEnLinea(
///   tono: TonoAviso.alerta,
///   titulo: 'El correo no está configurado',
///   mensaje: 'Pídele al administrador que llene el archivo .env.',
/// )
/// ```
class AvisoEnLinea extends StatelessWidget {
  const AvisoEnLinea({
    super.key,
    required this.mensaje,
    this.tono = TonoAviso.error,
    this.titulo,
  });

  final String mensaje;
  final TonoAviso tono;
  final String? titulo;

  @override
  Widget build(BuildContext context) {
    final color = tono._color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tono._fondo,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(tono._icono, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (titulo != null) ...[
                  Text(
                    titulo!,
                    style: TipografiaApp.cuerpoMedium.copyWith(color: color),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  mensaje,
                  style: TipografiaApp.caption.copyWith(
                    color: ColoresApp.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
