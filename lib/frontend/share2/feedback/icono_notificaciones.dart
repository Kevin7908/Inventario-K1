import 'package:flutter/material.dart';

import '../temas/colores_app.dart';

/// Ícono de campana con un punto que indica notificaciones sin leer.
///
/// Parámetros:
/// - [alPresionar]: callback al tocar la campana.
/// - [tieneNotificaciones]: muestra el punto rojo cuando es `true`. No indica cantidad.
///
/// Ejemplo:
/// ```dart
/// IconoNotificaciones(
///   tieneNotificaciones: true,
///   alPresionar: () => controlador.abrirNotificaciones(),
/// )
/// ```
class IconoNotificaciones extends StatelessWidget {
  const IconoNotificaciones({
    super.key,
    required this.alPresionar,
    this.tieneNotificaciones = false,
  });

  final VoidCallback alPresionar;
  final bool tieneNotificaciones;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColoresApp.bgCard,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: alPresionar,
        customBorder: const CircleBorder(),
        hoverColor: ColoresApp.bgCardHover,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications_outlined,
                size: 20,
                color: ColoresApp.textSecondary,
              ),
              if (tieneNotificaciones)
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: ColoresApp.statusDanger,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
