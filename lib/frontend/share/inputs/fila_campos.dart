import 'package:flutter/material.dart';

/// Fila de campos de formulario que se apila cuando no hay ancho.
///
/// Reparte el ancho entre sus [hijos] con 16 px de separación, y por debajo de
/// [anchoMinimo] los pone uno debajo de otro: en una ventana angosta tres
/// campos en fila quedan ilegibles.
///
/// Parámetros:
/// - [hijos]: campos de la fila.
/// - [pesos]: proporción de cada hijo. Por defecto todos valen 1. Debe tener
///   el mismo largo que [hijos].
/// - [anchoMinimo]: ancho por debajo del cual la fila se vuelve columna.
///
/// Ejemplo:
/// ```dart
/// FilaCampos(
///   hijos: [
///     CampoTexto(etiqueta: 'Nombre *', controlador: _nombreCtrl),
///     CampoTexto(etiqueta: 'NIT', controlador: _nitCtrl),
///   ],
/// )
/// ```
class FilaCampos extends StatelessWidget {
  const FilaCampos({
    super.key,
    required this.hijos,
    this.pesos,
    this.anchoMinimo = 640,
  }) : assert(
          pesos == null || pesos.length == hijos.length,
          'FilaCampos necesita un peso por hijo',
        );

  final List<Widget> hijos;
  final List<int>? pesos;
  final double anchoMinimo;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < anchoMinimo) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < hijos.length; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                hijos[i],
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < hijos.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(flex: pesos?[i] ?? 1, child: hijos[i]),
            ],
          ],
        );
      },
    );
  }
}
