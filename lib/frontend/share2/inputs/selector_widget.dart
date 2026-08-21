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
    this.habilitado = true,
  });

  final String etiqueta;
  final T valor;
  final List<T> opciones;
  final String Function(T opcion) constructorEtiqueta;
  final ValueChanged<T> alCambiar;

  /// En `false` el desplegable se ve pero no se abre. Mismo motivo que en
  /// `CampoTexto`: el dato se sigue leyendo, solo no se cambia.
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(etiqueta, style: TipografiaApp.etiquetaCampo),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: ColoresApp.bgInput,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: ColoresApp.borderInput),
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
              // `nuevo is T` en vez de `!= null`: con un tipo nulable
              // (`SelectorWidget<Categoria?>`) la opción "sin selección" es un
              // valor válido y debe propagarse; con uno no nulable, null se
              // descarta igual que antes.
              onChanged: habilitado
                  ? (nuevo) {
                      if (nuevo is T) alCambiar(nuevo);
                    }
                  : null,
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
