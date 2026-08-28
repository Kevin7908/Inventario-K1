import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Botón de acción principal de la aplicación.
///
/// Parámetros:
/// - [etiqueta]: texto visible del botón.
/// - [alPresionar]: callback ejecutado al hacer tap. Si es `null`, el botón queda deshabilitado.
/// - [icono]: ícono opcional a la izquierda del texto. Si es `null`, no se muestra ninguno.
///
/// Ejemplo:
/// ```dart
/// BotonPrimario(
///   etiqueta: 'Guardar cambios',
///   icono: Icons.check,
///   alPresionar: () => controlador.guardar(),
/// )
/// BotonPrimario(
///   etiqueta: 'Registrar venta',
///   alPresionar: () => controlador.registrar(),
/// )
/// ```
class BotonPrimario extends StatelessWidget {
  const BotonPrimario({
    super.key,
    required this.etiqueta,
    required this.alPresionar,
    this.icono,
    this.expandido = false,
  });

  final String etiqueta;
  final VoidCallback? alPresionar;
  final IconData? icono;

  /// Ocupa todo el ancho disponible en lugar de ajustarse al texto. Es lo que
  /// hace falta cuando el botón cierra un panel angosto, apilado sobre otros.
  final bool expandido;

  @override
  Widget build(BuildContext context) {
    final bool deshabilitado = alPresionar == null;

    return Material(
      color: deshabilitado
          ? ColoresApp.goGreen.withValues(alpha: 0.5)
          : ColoresApp.goGreen,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: alPresionar,
        borderRadius: BorderRadius.circular(8),
        hoverColor: ColoresApp.castletonGreen.withValues(alpha: 0.25),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisSize: expandido ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
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
