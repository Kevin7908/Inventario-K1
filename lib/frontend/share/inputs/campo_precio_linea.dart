import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// El precio tecleable de una línea de documento, sin cajón alrededor.
///
/// Ocupa el sitio exacto del texto verde que muestra un precio fijo, para que
/// la fila mida lo mismo se pueda editar o no. Por eso no lleva borde ni
/// relleno: dentro de una lista, un `TextField` con su marco rompe la
/// alineación de todas las demás filas.
///
/// **No guarda el texto**: el [controlador] lo crea y lo libera el widget que
/// posee la línea, que es el que sabe cuándo la fila deja de existir. Por eso
/// esta pieza puede ser `StatelessWidget` como el resto de share.
///
/// Parámetros:
/// - [controlador]: el del campo. Lo crea y lo libera quien usa el widget.
/// - [alCambiar]: se llama con el valor ya interpretado. Un campo ilegible
///   avisa `0`, no `null`: la línea sin precio es un estado válido mientras se
///   teclea, y el pie ya la suma como cero.
/// - [foco]: opcional, para llevar el cursor aquí desde fuera.
/// - [habilitado]: en `false` no deja escribir pero conserva el sitio.
///
/// Ejemplo:
/// ```dart
/// CampoPrecioLinea(
///   controlador: _precio,
///   alCambiar: (valor) => notifier.cambiarPrecio(linea, valor),
/// )
/// ```
class CampoPrecioLinea extends StatelessWidget {
  const CampoPrecioLinea({
    super.key,
    required this.controlador,
    required this.alCambiar,
    this.foco,
    this.habilitado = true,
  });

  final TextEditingController controlador;
  final ValueChanged<int> alCambiar;
  final FocusNode? foco;
  final bool habilitado;

  /// El verde de un importe, compartido con el texto que muestra el precio
  /// fijo. Vive aquí para que las dos formas de la misma celda no se separen.
  static TextStyle get estilo => TipografiaApp.cuerpoMedium.copyWith(
        fontSize: 13,
        color: ColoresApp.castletonGreen,
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: TextField(
        controller: controlador,
        focusNode: foco,
        enabled: habilitado,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: estilo,
        onChanged: (texto) => alCambiar(int.tryParse(texto) ?? 0),
        decoration: InputDecoration(
          isDense: true,
          prefixText: r'$',
          prefixStyle: estilo,
          hintText: 'Precio',
          hintStyle: TipografiaApp.deshabilitado(estilo),
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}
