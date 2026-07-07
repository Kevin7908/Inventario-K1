import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Tarjeta blanca con título que agrupa un bloque de contenido.
///
/// Parámetros:
/// - [titulo]: encabezado de la sección.
/// - [child]: contenido de la sección.
/// - [icono]: ícono opcional a la izquierda del título (ej. secciones de un formulario largo).
///
/// Ejemplo:
/// ```dart
/// PanelSeccion(
///   titulo: 'Datos del negocio',
///   child: Column(children: [...]),
/// )
///
/// PanelSeccion(
///   titulo: 'Información general',
///   icono: Icons.info_outline,
///   child: Column(children: [...]),
/// )
/// ```
class PanelSeccion extends StatelessWidget {
  const PanelSeccion({
    super.key,
    required this.titulo,
    required this.child,
    this.icono,
  });

  final String titulo;
  final Widget child;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ColoresApp.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icono != null) ...[
                Icon(icono, size: 18, color: ColoresApp.goGreen),
                const SizedBox(width: 8),
              ],
              Text(titulo, style: TipografiaApp.subtitulo),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
