import 'package:flutter/material.dart';

import '../botones/boton_destructivo.dart';
import '../botones/boton_primario.dart';
import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Diálogo que pide confirmación antes de ejecutar una acción irreversible.
///
/// Parámetros:
/// - [titulo]: pregunta o encabezado del diálogo (ej. '¿Eliminar "Litro"?').
/// - [mensaje]: texto adicional debajo del título. Opcional.
/// - [textoConfirmar]: texto del botón destructivo. Por defecto 'Eliminar'.
/// - [textoCancelar]: texto del botón de cancelar. Por defecto 'Cancelar'.
/// - [destructivo]: `true` —lo normal— pinta el botón de confirmar en rojo.
///   Ponlo en `false` cuando lo que se confirma no destruye nada y solo pide
///   una decisión, como «esta cédula ya está registrada, ¿la reutilizo?».
///
/// Se muestra con el método estático [mostrar], que devuelve `true` si el
/// usuario confirmó, o `null`/`false` si canceló o cerró el diálogo.
///
/// Ejemplo:
/// ```dart
/// final confirmado = await DialogoConfirmacion.mostrar(
///   context,
///   titulo: '¿Eliminar "Litro"?',
///   mensaje: 'Esta acción no se puede deshacer.',
/// );
/// if (confirmado == true) controlador.eliminar(id);
/// ```
class DialogoConfirmacion extends StatelessWidget {
  const DialogoConfirmacion({
    super.key,
    required this.titulo,
    this.mensaje,
    this.textoConfirmar = 'Eliminar',
    this.textoCancelar = 'Cancelar',
    this.destructivo = true,
  });

  final String titulo;
  final String? mensaje;
  final String textoConfirmar;
  final String textoCancelar;
  final bool destructivo;

  static Future<bool?> mostrar(
    BuildContext context, {
    required String titulo,
    String? mensaje,
    String textoConfirmar = 'Eliminar',
    String textoCancelar = 'Cancelar',
    bool destructivo = true,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => DialogoConfirmacion(
        titulo: titulo,
        mensaje: mensaje,
        textoConfirmar: textoConfirmar,
        textoCancelar: textoCancelar,
        destructivo: destructivo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: ColoresApp.bgCard,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: ColoresApp.shadowMedium,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: TipografiaApp.heading3),
            if (mensaje != null) ...[
              const SizedBox(height: 8),
              Text(
                mensaje!,
                style: TipografiaApp.cuerpo.copyWith(
                  color: ColoresApp.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    textoCancelar,
                    style: TipografiaApp.cuerpoMedium.copyWith(
                      color: ColoresApp.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (destructivo)
                  BotonDestructivo(
                    etiqueta: textoConfirmar,
                    alPresionar: () => Navigator.of(context).pop(true),
                  )
                else
                  BotonPrimario(
                    etiqueta: textoConfirmar,
                    alPresionar: () => Navigator.of(context).pop(true),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
