import 'package:flutter/material.dart';

import 'colores_app.dart';

/// Tokens tipográficos del proyecto.
///
/// Los tamaños y pesos replican el mockup de diseño (`InventarioK1.html`), que
/// usa la familia *General Sans* con los pesos 500 (Medium), 600 (SemiBold) y
/// 700 (Bold). Mientras la familia no esté empaquetada en `pubspec.yaml`,
/// [_familia] cae en la fuente por defecto del sistema y solo se conservan
/// tamaño, peso y `letterSpacing` — que es lo que define la jerarquía visual.
class TipografiaApp {
  static const String _familia = 'GeneralSans';

  static const double _tamHeading1      = 26;
  static const double _tamHeading2      = 22;
  static const double _tamHeading3      = 18;
  static const double _tamSubtitulo     = 15;
  static const double _tamTituloTarjeta = 14;
  static const double _tamCuerpo        = 13.5;
  static const double _tamCaption       = 12.5;
  static const double _tamOverline      = 11.5;

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

  /// Subtítulo debajo del título de pantalla
  /// (ej. "Ajustes generales del negocio y catálogos base")
  static const TextStyle subtituloPagina = TextStyle(
    fontFamily: _familia,
    fontSize:   _tamCuerpo,
    fontWeight: FontWeight.w500,
    color:      ColoresApp.textMuted,
    height:     1.4,
  );

  /// Título de un bloque dentro de una card (ej. "Datos del negocio")
  static const TextStyle subtitulo = TextStyle(
    fontFamily: _familia,
    fontSize:   _tamSubtitulo,
    fontWeight: FontWeight.w600, // SemiBold
    color:      ColoresApp.textPrimary,
    height:     1.4,
  );

  /// Nombre de un ítem dentro de una tarjeta de grilla
  static const TextStyle tituloTarjeta = TextStyle(
    fontFamily: _familia,
    fontSize:   _tamTituloTarjeta,
    fontWeight: FontWeight.w600,
    color:      ColoresApp.textPrimary,
    height:     1.3,
  );

  /// Texto de cuerpo general
  static const TextStyle cuerpo = TextStyle(
    fontFamily: _familia,
    fontSize:   _tamCuerpo,
    fontWeight: FontWeight.w500, // Medium
    color:      ColoresApp.textPrimary,
    height:     1.5,
  );

  /// Cuerpo con énfasis (semibold) — celda destacada de tabla
  static const TextStyle cuerpoMedium = TextStyle(
    fontFamily: _familia,
    fontSize:   _tamCuerpo,
    fontWeight: FontWeight.w600,
    color:      ColoresApp.textPrimary,
    height:     1.5,
  );

  /// Etiqueta de campo de formulario, encima del input
  static const TextStyle etiquetaCampo = TextStyle(
    fontFamily: _familia,
    fontSize:   _tamCaption,
    fontWeight: FontWeight.w600,
    color:      ColoresApp.textSecondary,
    height:     1.4,
  );

  /// Descripciones secundarias, celdas tenues de tabla
  static const TextStyle caption = TextStyle(
    fontFamily: _familia,
    fontSize:   _tamCaption,
    fontWeight: FontWeight.w500,
    color:      ColoresApp.textSecondary,
    height:     1.4,
  );

  /// Encabezado de columna de tabla / overline en mayúsculas
  static const TextStyle overline = TextStyle(
    fontFamily:      _familia,
    fontSize:        _tamOverline,
    fontWeight:      FontWeight.w600,
    color:           ColoresApp.textMuted,
    letterSpacing:   0.4,
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

  /// Variante monoespaciada — para códigos: NIT, SKU, abreviaturas.
  /// Replica `font-family:ui-monospace,monospace` del mockup.
  static TextStyle monoespaciada(TextStyle base) =>
      base.copyWith(fontFamily: 'monospace', fontFamilyFallback: const ['monospace']);
}
