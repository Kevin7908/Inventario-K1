import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Campo de texto de propósito general con etiqueta arriba.
///
/// Parámetros:
/// - [etiqueta]: texto mostrado encima del campo.
/// - [controlador]: controla el valor del campo.
/// - [placeholder]: texto de ejemplo cuando el campo está vacío.
/// - [alCambiar]: callback ejecutado en cada cambio de texto.
///
/// Ejemplo:
/// ```dart
/// CampoTexto(
///   etiqueta: 'Nombre del taller',
///   controlador: _nombreController,
/// )
/// ```
class CampoTexto extends StatelessWidget {
  const CampoTexto({
    super.key,
    required this.etiqueta,
    required this.controlador,
    this.placeholder,
    this.alCambiar,
  });

  final String etiqueta;
  final TextEditingController controlador;
  final String? placeholder;
  final ValueChanged<String>? alCambiar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(etiqueta, style: TipografiaApp.caption),
        const SizedBox(height: 6),
        TextField(
          controller: controlador,
          onChanged: alCambiar,
          style: TipografiaApp.cuerpo,
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TipografiaApp.deshabilitado(TipografiaApp.cuerpo),
            filled: true,
            fillColor: ColoresApp.bgInput,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: ColoresApp.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: ColoresApp.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: ColoresApp.borderFocus),
            ),
          ),
        ),
      ],
    );
  }
}
