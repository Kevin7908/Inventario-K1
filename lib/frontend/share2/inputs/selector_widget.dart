import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Dropdown de opciones predefinidas, con etiqueta arriba.
///
/// Parámetros:
/// - [etiqueta]: texto mostrado encima del selector.
/// - [valor]: opción seleccionada actualmente.
/// - [opciones]: lista de opciones disponibles.
/// - [constructorEtiqueta]: convierte cada opción en el texto a mostrar.
/// - [alCambiar]: callback ejecutado al elegir una opción distinta.
///
/// Ejemplo:
/// ```dart
/// SelectorWidget<String>(
///   etiqueta: 'Moneda',
///   valor: 'COP',
///   opciones: const ['COP', 'USD'],
///   constructorEtiqueta: (v) => v == 'COP' ? 'Peso colombiano (COP \$)' : 'Dólar (USD \$)',
///   alCambiar: (v) => setState(() => _moneda = v),
/// )
/// ```
class SelectorWidget<T> extends StatelessWidget {
  const SelectorWidget({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.opciones,
    required this.constructorEtiqueta,
    required this.alCambiar,
  });

  final String etiqueta;
  final T valor;
  final List<T> opciones;
  final String Function(T opcion) constructorEtiqueta;
  final ValueChanged<T> alCambiar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(etiqueta, style: TipografiaApp.caption),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: ColoresApp.bgInput,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ColoresApp.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: valor,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: ColoresApp.textSecondary,
              ),
              style: TipografiaApp.cuerpo,
              dropdownColor: ColoresApp.bgCard,
              onChanged: (nuevo) {
                if (nuevo != null) alCambiar(nuevo);
              },
              items: [
                for (final opcion in opciones)
                  DropdownMenuItem<T>(
                    value: opcion,
                    child: Text(constructorEtiqueta(opcion)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
