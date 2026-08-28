import 'package:flutter/material.dart';

import '../temas/colores_app.dart';

/// Línea divisora horizontal dentro del sidebar.
///
/// Separa visualmente el grupo principal de navegación de los ítems de pie
/// (Configuración, Salir).
///
/// Ejemplo:
/// ```dart
/// const SeparadorNav()
/// ```
class SeparadorNav extends StatelessWidget {
  const SeparadorNav({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(
        color: ColoresApp.borderSidebar,
        thickness: 1,
        height: 1,
      ),
    );
  }
}
