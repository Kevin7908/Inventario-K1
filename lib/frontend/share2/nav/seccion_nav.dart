import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Etiqueta de grupo dentro del sidebar (ej: "PRINCIPAL", "INVENTARIO").
///
/// Parámetros:
/// - [titulo]: texto del grupo. Se convierte a mayúsculas automáticamente.
///
/// Ejemplo:
/// ```dart
/// const SeccionNav(titulo: 'Principal')
/// const SeccionNav(titulo: 'Taller')
/// ```
class SeccionNav extends StatelessWidget {
  const SeccionNav({super.key, required this.titulo});

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 20, bottom: 4),
      child: Text(
        titulo.toUpperCase(),
        style: TipografiaApp.overline.copyWith(
          color: ColoresApp.textSidebar,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
