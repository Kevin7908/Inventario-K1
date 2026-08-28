import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Enlace de retorno que encabeza una página de detalle.
///
/// Es deliberadamente discreto —flecha y texto en gris, sin fondo ni borde—
/// para que no compita con la acción principal de la pantalla.
///
/// Parámetros:
/// - [etiqueta]: texto del enlace, nombrando el destino ("Volver a productos").
/// - [alPresionar]: callback al hacer tap.
///
/// Ejemplo:
/// ```dart
/// BotonVolver(
///   etiqueta: 'Volver a productos',
///   alPresionar: alVolver,
/// )
/// ```
class BotonVolver extends StatelessWidget {
  const BotonVolver({
    super.key,
    required this.etiqueta,
    required this.alPresionar,
  });

  final String etiqueta;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: alPresionar,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.arrow_back_rounded,
                  size: 16,
                  color: ColoresApp.textMuted,
                ),
                const SizedBox(width: 8),
                // `Flexible` + recorte: la etiqueta nombra el destino y puede
                // ser larga ("Volver al inicio de sesión"). En una columna
                // angosta —el formulario de login mide 380— la fila se
                // desbordaba por medio píxel.
                Flexible(
                  child: Text(
                    etiqueta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TipografiaApp.caption.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ColoresApp.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
