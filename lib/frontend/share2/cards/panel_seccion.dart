import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Tarjeta blanca con título que agrupa un bloque de contenido.
///
/// Parámetros:
/// - [titulo]: encabezado de la sección.
/// - [child]: contenido de la sección.
/// - [icono]: ícono opcional a la izquierda del título (ej. secciones de un formulario largo).
/// - [accion]: widget alineado a la derecha del título, para la acción propia
///   de la sección ("Agregar moto", "Ver todo"). Va en el encabezado y no
///   dentro del contenido para que no se pierda cuando la sección crece.
///
/// Ejemplo:
/// ```dart
/// PanelSeccion(
///   titulo: 'Datos del negocio',
///   child: Column(children: [...]),
/// )
///
/// PanelSeccion(
///   titulo: 'Motos',
///   icono: Icons.two_wheeler_outlined,
///   accion: BotonSecundario(
///     etiqueta: 'Agregar moto',
///     icono: Icons.add,
///     alPresionar: _agregarMoto,
///   ),
///   child: Column(children: [...]),
/// )
/// ```
class PanelSeccion extends StatelessWidget {
  const PanelSeccion({
    super.key,
    required this.titulo,
    required this.child,
    this.icono,
    this.accion,
  });

  final String titulo;
  final Widget child;
  final IconData? icono;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ColoresApp.bgCard,
        borderRadius: BorderRadius.circular(18),
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
              Expanded(child: Text(titulo, style: TipografiaApp.subtitulo)),
              ?accion,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}
