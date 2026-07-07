import 'package:flutter/material.dart';

import '../temas/colores_app.dart';

/// Botón compacto para acciones que se entienden con un solo ícono
/// (editar, eliminar, cerrar) dentro de espacios angostos como filas de
/// tabla, donde un botón con texto no cabe.
///
/// Parámetros:
/// - [icono]: ícono del botón.
/// - [alPresionar]: callback ejecutado al hacer tap. Si es `null`, el botón queda deshabilitado.
/// - [color]: color del ícono. Por defecto `ColoresApp.textSecondary`.
/// - [tooltip]: texto que aparece al mantener el cursor encima. Opcional.
///
/// Ejemplo:
/// ```dart
/// Row(
///   mainAxisSize: MainAxisSize.min,
///   children: [
///     BotonIcono(
///       icono: Icons.edit_outlined,
///       tooltip: 'Editar',
///       alPresionar: () => controlador.editar(item),
///     ),
///     BotonIcono(
///       icono: Icons.delete_outline_rounded,
///       tooltip: 'Eliminar',
///       color: ColoresApp.statusDanger,
///       alPresionar: () => controlador.eliminar(item),
///     ),
///   ],
/// )
/// ```
class BotonIcono extends StatelessWidget {
  const BotonIcono({
    super.key,
    required this.icono,
    required this.alPresionar,
    this.color,
    this.tooltip,
  });

  final IconData icono;
  final VoidCallback? alPresionar;
  final Color? color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final bool deshabilitado = alPresionar == null;
    final Color colorIcono = color ?? ColoresApp.textSecondary;

    final boton = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: alPresionar,
        borderRadius: BorderRadius.circular(8),
        hoverColor: ColoresApp.bgCardHover,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icono,
            size: 18,
            color: deshabilitado
                ? ColoresApp.textDisabled
                : colorIcono,
          ),
        ),
      ),
    );

    if (tooltip == null) return boton;
    return Tooltip(message: tooltip, child: boton);
  }
}
