import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Campo de texto de propósito general con etiqueta arriba.
///
/// Usa `TextFormField`, así que funciona igual suelto o dentro de un `Form`:
/// si se le pasa [validador], participa de la validación del formulario.
///
/// Parámetros:
/// - [etiqueta]: texto mostrado encima del campo.
/// - [controlador]: controla el valor del campo.
/// - [placeholder]: texto de ejemplo cuando el campo está vacío.
/// - [alCambiar]: callback ejecutado en cada cambio de texto.
/// - [validador]: valida el valor dentro de un `Form`. Devuelve el mensaje de
///   error, o `null` si el valor es válido.
/// - [lineas]: alto del campo en líneas. Por defecto 1.
/// - [autofocus]: pone el foco en el campo al construirse.
/// - [monoespaciado]: usa fuente monoespaciada para el valor. Útil en códigos
///   donde alinear dígitos ayuda a leerlos (NIT, SKU, cédula).
///
/// Ejemplo:
/// ```dart
/// CampoTexto(
///   etiqueta: 'Nombre del taller',
///   controlador: _nombreController,
/// )
///
/// CampoTexto(
///   etiqueta: 'Nombre *',
///   controlador: _nombreCtrl,
///   autofocus: true,
///   validador: (v) =>
///       (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio.' : null,
/// )
/// ```
class CampoTexto extends StatelessWidget {
  const CampoTexto({
    super.key,
    required this.etiqueta,
    required this.controlador,
    this.placeholder,
    this.alCambiar,
    this.validador,
    this.lineas = 1,
    this.autofocus = false,
    this.monoespaciado = false,
  });

  final String etiqueta;
  final TextEditingController controlador;
  final String? placeholder;
  final ValueChanged<String>? alCambiar;
  final String? Function(String?)? validador;
  final int lineas;
  final bool autofocus;
  final bool monoespaciado;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder borde(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: color),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(etiqueta, style: TipografiaApp.etiquetaCampo),
        const SizedBox(height: 7),
        TextFormField(
          controller: controlador,
          onChanged: alCambiar,
          validator: validador,
          maxLines: lineas,
          autofocus: autofocus,
          style: monoespaciado
              ? TipografiaApp.monoespaciada(TipografiaApp.cuerpo)
              : TipografiaApp.cuerpo,
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TipografiaApp.deshabilitado(TipografiaApp.cuerpo),
            filled: true,
            fillColor: ColoresApp.bgInput,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: borde(ColoresApp.borderInput),
            enabledBorder: borde(ColoresApp.borderInput),
            focusedBorder: borde(ColoresApp.borderFocus),
            errorBorder: borde(ColoresApp.statusDanger),
            focusedErrorBorder: borde(ColoresApp.statusDanger),
            errorStyle: TipografiaApp.caption.copyWith(
              color: ColoresApp.statusDanger,
            ),
          ),
        ),
      ],
    );
  }
}
