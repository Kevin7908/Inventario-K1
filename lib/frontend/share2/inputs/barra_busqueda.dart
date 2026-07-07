import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Campo de búsqueda con ícono, para filtrar listas o tablas.
///
/// A diferencia de [CampoTexto], no tiene etiqueta arriba: es un input
/// autocontenido con el ícono de lupa a la izquierda, pensado para barras
/// de búsqueda (topbar, filtros de tabla).
///
/// Parámetros:
/// - [controlador]: controla el valor del campo.
/// - [placeholder]: texto de ejemplo cuando el campo está vacío.
/// - [alCambiar]: callback ejecutado en cada cambio de texto.
/// - [ancho]: ancho fijo opcional. Por defecto ocupa el ancho de su contenedor.
///
/// Ejemplo:
/// ```dart
/// BarraBusqueda(
///   controlador: _busquedaController,
///   placeholder: 'Buscar unidad...',
///   alCambiar: (texto) => controlador.buscar(texto),
///   ancho: 320,
/// )
/// ```
class BarraBusqueda extends StatelessWidget {
  const BarraBusqueda({
    super.key,
    required this.controlador,
    this.placeholder,
    this.alCambiar,
    this.ancho,
  });

  final TextEditingController controlador;
  final String? placeholder;
  final ValueChanged<String>? alCambiar;
  final double? ancho;

  @override
  Widget build(BuildContext context) {
    final campo = TextField(
      controller: controlador,
      onChanged: alCambiar,
      style: TipografiaApp.cuerpo,
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: TipografiaApp.deshabilitado(TipografiaApp.cuerpo),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 18,
          color: ColoresApp.textDisabled,
        ),
        filled: true,
        fillColor: ColoresApp.bgInput,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ColoresApp.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ColoresApp.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ColoresApp.borderFocus),
        ),
      ),
    );

    if (ancho == null) return campo;
    return SizedBox(width: ancho, child: campo);
  }
}
