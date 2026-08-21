import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Botón para acciones irreversibles (eliminar, anular).
///
/// Parámetros:
/// - [etiqueta]: texto visible del botón.
/// - [alPresionar]: callback ejecutado al hacer tap. Si es `null`, el botón queda deshabilitado.
/// - [icono]: ícono opcional a la izquierda del texto. Si es `null`, no se muestra ninguno.
///
/// Ejemplo:
/// ```dart
/// BotonDestructivo(
///   etiqueta: 'Eliminar',
///   icono: Icons.delete_outline_rounded,
///   alPresionar: () => controlador.eliminar(id),
/// )
/// ```
class BotonDestructivo extends StatelessWidget {
  const BotonDestructivo({
    super.key,
    required this.etiqueta,
    required this.alPresionar,
    this.icono,
    this.expandido = false,
    this.suave = false,
  });

  final String etiqueta;
  final VoidCallback? alPresionar;
  final IconData? icono;

  /// Ocupa todo el ancho disponible en lugar de ajustarse al texto.
  final bool expandido;

  /// Rojo sobre fondo claro en vez de rojo macizo.
  ///
  /// Es para la acción destructiva que **convive con el contenido** —cancelar
  /// una reserva desde su propio pie, anular una orden dentro de su diálogo—,
  /// donde un bloque rojo sólido se lleva toda la atención de una pantalla que
  /// no trata de eso. Sigue leyéndose como peligro, pero no grita.
  final bool suave;

  @override
  Widget build(BuildContext context) {
    final bool deshabilitado = alPresionar == null;

    final contenido = suave
        ? (deshabilitado
            ? ColoresApp.statusDanger.withValues(alpha: 0.5)
            : ColoresApp.statusDanger)
        : ColoresApp.textOnPrimary;

    return Material(
      color: suave
          ? ColoresApp.statusDangerBg
          : (deshabilitado
              ? ColoresApp.statusDanger.withValues(alpha: 0.5)
              : ColoresApp.statusDanger),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: alPresionar,
        borderRadius: BorderRadius.circular(8),
        hoverColor: suave
            ? ColoresApp.statusDanger.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: suave
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ColoresApp.statusDanger.withValues(alpha: 0.35),
                  ),
                )
              : null,
          child: Row(
            mainAxisSize: expandido ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icono != null) ...[
                Icon(icono, size: 18, color: contenido),
                const SizedBox(width: 8),
              ],
              Text(
                etiqueta,
                style: suave
                    ? TipografiaApp.cuerpoMedium.copyWith(color: contenido)
                    : TipografiaApp.sobrePrimario(TipografiaApp.cuerpoMedium),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
