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
  });

  final String etiqueta;
  final VoidCallback? alPresionar;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final bool deshabilitado = alPresionar == null;

    return Material(
      color: deshabilitado
          ? ColoresApp.statusDanger.withValues(alpha: 0.5)
          : ColoresApp.statusDanger,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: alPresionar,
        borderRadius: BorderRadius.circular(8),
        hoverColor: Colors.black.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icono != null) ...[
                Icon(icono, size: 18, color: ColoresApp.textOnPrimary),
                const SizedBox(width: 8),
              ],
              Text(
                etiqueta,
                style: TipografiaApp.sobrePrimario(TipografiaApp.cuerpoMedium),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
