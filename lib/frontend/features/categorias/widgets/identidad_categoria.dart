import 'package:flutter/material.dart';

import '../../../share/share.dart';

/// Cómo se pinta una categoría en toda la app.
///
/// **Un solo color y un solo ícono, iguales para todas.** Antes cada categoría
/// guardaba los suyos en la base y se elegían al crearla: eso dejaba el diseño
/// de la app a merced de lo que alguien hubiera tecleado, permitía dos
/// categorías del mismo color —que es exactamente lo que un color distintivo
/// tiene que evitar— y metía una decisión de vista dentro del esquema.
///
/// Lo que distingue a una categoría de otra es su nombre, y de eso ya se
/// encarga la inicial del marcador.
///
/// Ejemplo:
/// ```dart
/// MarcadorIdentidad(
///   inicial: inicialDe(categoria.nombre),
///   color: IdentidadCategoria.color,
/// )
/// ```
final class IdentidadCategoria {
  const IdentidadCategoria._();

  /// El verde de marca, el mismo de las acciones principales.
  static const Color color = ColoresApp.goGreen;

  static const IconData icono = Icons.category_outlined;
}
