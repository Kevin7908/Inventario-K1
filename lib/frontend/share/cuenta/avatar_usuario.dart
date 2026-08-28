import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Círculo con las iniciales de un usuario.
///
/// Parámetros:
/// - [iniciales]: texto corto a mostrar (normalmente 1-2 letras).
/// - [color]: color de fondo del círculo. Por defecto [ColoresApp.castletonGreen].
/// - [tamano]: diámetro del círculo en píxeles. Por defecto 40.
///
/// Ejemplo:
/// ```dart
/// AvatarUsuario(iniciales: 'ZM')
/// AvatarUsuario(iniciales: 'K1', tamano: 32)
/// ```
class AvatarUsuario extends StatelessWidget {
  const AvatarUsuario({
    super.key,
    required this.iniciales,
    this.color = ColoresApp.castletonGreen,
    this.tamano = 40,
  });

  final String iniciales;
  final Color color;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        iniciales,
        style: TipografiaApp.sobrePrimario(TipografiaApp.cuerpoMedium),
      ),
    );
  }
}
