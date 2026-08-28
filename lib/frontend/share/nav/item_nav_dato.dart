import 'package:flutter/material.dart';

/// Datos de un ítem de navegación para pasarle a [BarraLateral].
///
/// Ejemplo:
/// ```dart
/// ItemNavDato(
///   icono: Icons.dashboard_outlined,
///   etiqueta: 'Dashboard',
///   ruta: '/dashboard',
///   alPresionar: () => Get.toNamed('/dashboard'),
/// )
/// ```
class ItemNavDato {
  const ItemNavDato({
    required this.icono,
    required this.etiqueta,
    required this.ruta,
    required this.alPresionar,
    this.contadorBadge = 0,
  });

  final IconData icono;
  final String etiqueta;
  final String ruta;
  final VoidCallback alPresionar;
  final int contadorBadge;
}
