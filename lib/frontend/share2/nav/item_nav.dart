import 'package:flutter/material.dart';

import '../feedback/badge_contador.dart';
import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Ítem de navegación individual del sidebar.
///
/// Muestra un ícono, texto, estado activo/inactivo y un badge numérico opcional.
///
/// Parámetros:
/// - [icono]: ícono de Material a la izquierda del texto.
/// - [etiqueta]: texto del ítem.
/// - [alPresionar]: callback ejecutado al hacer tap.
/// - [activo]: fondo [ColoresApp.goGreen] con texto e ícono blancos cuando es `true`.
/// - [contadorBadge]: muestra un [BadgeContador] si es mayor a 0.
///
/// Ejemplo:
/// ```dart
/// ItemNav(
///   icono: Icons.dashboard_outlined,
///   etiqueta: 'Dashboard',
///   activo: true,
///   alPresionar: () => Get.toNamed('/dashboard'),
/// )
/// ItemNav(
///   icono: Icons.build_outlined,
///   etiqueta: 'Órdenes de servicio',
///   activo: false,
///   contadorBadge: 5,
///   alPresionar: () => Get.toNamed('/ordenes'),
/// )
/// ```
class ItemNav extends StatelessWidget {
  const ItemNav({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.alPresionar,
    this.activo = false,
    this.contadorBadge = 0,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback alPresionar;
  final bool activo;
  final int contadorBadge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: activo ? ColoresApp.goGreen : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: alPresionar,
          borderRadius: BorderRadius.circular(8),
          hoverColor: ColoresApp.goGreen.withValues(alpha: 0.15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icono,
                  size: 18,
                  color: activo ? ColoresApp.textOnPrimary : ColoresApp.textSidebar,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    etiqueta,
                    style: activo
                        ? TipografiaApp.cuerpoMedium
                            .copyWith(color: ColoresApp.textOnPrimary)
                        : TipografiaApp.cuerpo
                            .copyWith(color: ColoresApp.textSidebar),
                  ),
                ),
                if (contadorBadge > 0) ...[
                  const SizedBox(width: 6),
                  BadgeContador(cantidad: contadorBadge),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
