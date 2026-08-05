import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Cuadro redondeado que identifica a una entidad: su ícono o, si no tiene,
/// la inicial de su nombre sobre su color.
///
/// La inicial no es decorativa: en catálogos donde la entidad no guarda ícono
/// —como las categorías— es lo único que distingue una tarjeta de otra de un
/// vistazo, y en listas contraídas es lo único que se ve.
///
/// Parámetros:
/// - [icono]: ícono a mostrar. Tiene prioridad sobre [inicial].
/// - [inicial]: una o dos letras, cuando no hay ícono.
/// - [color]: color de acento del contenido. Por defecto [ColoresApp.goGreen].
/// - [colorFondo]: fondo del cuadro. Por defecto, [color] atenuado.
/// - [lado]: alto y ancho del cuadro. Por defecto 44.
/// - [radio]: radio de las esquinas. Por defecto 12.
/// - [tamanoContenido]: tamaño del ícono o de la letra. Por defecto se deriva
///   de [lado]; conviene fijarlo en cuadros pequeños, donde la proporción
///   dejaría el glifo ilegible.
///
/// Ejemplo:
/// ```dart
/// MarcadorIdentidad(
///   inicial: 'F',
///   color: const Color(0xFF01B763),
///   lado: 50,
///   radio: 14,
/// )
/// ```
class MarcadorIdentidad extends StatelessWidget {
  const MarcadorIdentidad({
    super.key,
    this.icono,
    this.inicial,
    this.color,
    this.colorFondo,
    this.lado = 44,
    this.radio = 12,
    this.tamanoContenido,
  });

  final IconData? icono;
  final String? inicial;
  final Color? color;
  final Color? colorFondo;
  final double lado;
  final double radio;
  final double? tamanoContenido;

  @override
  Widget build(BuildContext context) {
    final acento = color ?? ColoresApp.goGreen;
    final fondo = colorFondo ??
        (color == null
            ? ColoresApp.greenChipBg
            : acento.withValues(alpha: 0.16));

    return Container(
      width: lado,
      height: lado,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(radio),
      ),
      child: icono != null
          ? Icon(icono, size: tamanoContenido ?? lado * 0.45, color: acento)
          : Text(
              inicial ?? '',
              style: TipografiaApp.cuerpoMedium.copyWith(
                fontSize: tamanoContenido ?? lado * 0.4,
                fontWeight: FontWeight.w700,
                color: acento,
                height: 1,
              ),
            ),
    );
  }
}
