import 'package:flutter/material.dart';

import 'colores_app.dart';

/// Fuente: General Sans  (SemiBold · Medium · Regular)
/// Para que funcione, agrégala en pubspec.yaml bajo flutter > fonts.
class TipografiaApp {
  static const String _familia = 'GeneralSans';

  static const double _tamHeading1   = 28;
  static const double _tamHeading2   = 22;
  static const double _tamHeading3   = 18;
  static const double _tamSubtitulo  = 15;
  static const double _tamCuerpo     = 14;
  static const double _tamCaption    = 12;
  static const double _tamOverline   = 11;

  /// Título de pantalla / sección principal
  static const TextStyle heading1 = TextStyle(
    fontFamily: _familia,
    fontSize:   _tamHeading1,
    fontWeight: FontWeight.w600, // SemiBold
    color:      ColoresApp.textPrimary,
    height:     1.2,
  );

  /// Título de card o sección secundaria
  static const TextStyle heading2 = TextStyle(
    fontFamily: _familia,
    fontSize:   _tamHeading2,
    fontWeight: FontWeight.w600,
    color:      ColoresApp.textPrimary,
    height:     1.3,
  );

  /// Título de diálogo / panel
  static const TextStyle heading3 = TextStyle(
    fontFamily: _familia,
    fontSize:   _tamHeading3,
    fontWeight: FontWeight.w600,
    color:      ColoresApp.textPrimary,
    height:     1.3,
  );

  /// Subtítulo, nombre de campo importante
  static const TextStyle subtitulo = TextStyle(
    fontFamily: _familia,
    fontSize:   _tamSubtitulo,
    fontWeight: FontWeight.w500, // Medium
    color:      ColoresApp.textPrimary,
    height:     1.4,
  );

  /// Texto de cuerpo general
  static const TextStyle cuerpo = TextStyle(
    fontFamily: _familia,
    fontSize:   _tamCuerpo,
    fontWeight: FontWeight.w400, // Regular
    color:      ColoresApp.textPrimary,
    height:     1.5,
  );

  /// Cuerpo con énfasis (medium)
  static const TextStyle cuerpoMedium = TextStyle(
    fontFamily: _familia,
    fontSize:   _tamCuerpo,
    fontWeight: FontWeight.w500,
    color:      ColoresApp.textPrimary,
    height:     1.5,
  );

  /// Labels de campos, descripciones secundarias
  static const TextStyle caption = TextStyle(
    fontFamily: _familia,
    fontSize:   _tamCaption,
    fontWeight: FontWeight.w400,
    color:      ColoresApp.textSecondary,
    height:     1.4,
  );

  /// Texto de badge / chip / overline
  static const TextStyle overline = TextStyle(
    fontFamily:      _familia,
    fontSize:        _tamOverline,
    fontWeight:      FontWeight.w600,
    color:           ColoresApp.textSecondary,
    letterSpacing:   0.5,
    height:          1.3,
  );

  /// Cualquier estilo base sobre fondo primario (sidebar, botones)
  static TextStyle sobrePrimario(TextStyle base) =>
      base.copyWith(color: ColoresApp.textOnPrimary);

  /// Texto secundario / deshabilitado
  static TextStyle deshabilitado(TextStyle base) =>
      base.copyWith(color: ColoresApp.textDisabled);

  /// Texto de acción / link
  static TextStyle enlace(TextStyle base) =>
      base.copyWith(color: ColoresApp.textLink);
}
