import 'package:flutter/material.dart';

import '../temas/colores_app.dart';

/// Barra de avance de una sola cifra: cuánto se lleva de un total.
///
/// La usan la tarjeta de una reserva, su pie de cuentas y las cuentas por
/// cobrar. Es puramente presentacional: recibe la fracción ya calculada y el
/// color ya decidido, porque qué es "ir bien" cambia según el módulo —una
/// reserva a medio pagar está normal, una deuda a medio pagar y vencida no—.
///
/// Sin `ClipRRect`: el relleno lleva su propio `borderRadius`, que es más
/// barato que recortar (§2 de `CLAUDE.md`).
///
/// Parámetros:
/// - [progreso]: de 0 a 1. Se acota, así que un 1.2 por redondeo no desborda.
/// - [color]: el del relleno.
/// - [colorFondo]: el del canal. Por defecto el gris tenue del diseño.
/// - [alto]: grosor de la barra. 8 en las tarjetas, 6 en los pies.
///
/// Ejemplo:
/// ```dart
/// BarraProgreso(
///   progreso: reserva.porcentajePagado,
///   color: ColoresApp.goGreen,
/// )
/// ```
class BarraProgreso extends StatelessWidget {
  const BarraProgreso({
    super.key,
    required this.progreso,
    required this.color,
    this.colorFondo,
    this.alto = 8,
  });

  final double progreso;
  final Color color;
  final Color? colorFondo;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final radio = BorderRadius.circular(alto * 0.75);

    return Container(
      height: alto,
      decoration: BoxDecoration(
        color: colorFondo ?? ColoresApp.borderFila,
        borderRadius: radio,
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progreso.clamp(0.0, 1.0),
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, borderRadius: radio),
        ),
      ),
    );
  }
}
