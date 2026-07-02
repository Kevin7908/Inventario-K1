import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Badge circular que muestra un conteo numérico sobre un color de fondo.
///
/// Parámetros:
/// - [cantidad]: número a mostrar. Si es 0 o negativo, no se renderiza nada.
/// - [color]: color de fondo. Por defecto [ColoresApp.statusDanger] (rojo).
///
/// Ejemplo:
/// ```dart
/// BadgeContador(cantidad: 5)
/// BadgeContador(cantidad: 12, color: ColoresApp.statusWarning)
/// ```
class BadgeContador extends StatelessWidget {
  const BadgeContador({
    super.key,
    required this.cantidad,
    this.color = ColoresApp.statusDanger,
  });

  final int cantidad;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (cantidad <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      child: Text(
        cantidad > 99 ? '99+' : '$cantidad',
        style: TipografiaApp.overline.copyWith(
          color: ColoresApp.textOnPrimary,
          fontSize: 10,
          height: 1,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
