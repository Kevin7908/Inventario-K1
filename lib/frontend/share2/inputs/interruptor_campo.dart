import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Interruptor de formulario con etiqueta y una línea que explica qué implica
/// el estado actual ("Visible en el catálogo" / "Oculto del catálogo").
///
/// El detalle no es decorativo: un switch a secas obliga a deducir qué
/// significa que esté encendido.
///
/// Parámetros:
/// - [etiqueta]: nombre del campo.
/// - [detalle]: qué implica el valor actual. Lo decide quien lo usa, porque
///   cambia según esté encendido o apagado.
/// - [valor]: estado del interruptor.
/// - [alCambiar]: callback con el nuevo valor.
/// - [detalleEnUnaLinea]: recorta el detalle con "…" en vez de dejarlo bajar
///   de línea. Útil dentro de una [FilaCampos], donde el alto debe coincidir.
///
/// Ejemplo:
/// ```dart
/// InterruptorCampo(
///   etiqueta: 'Proveedor activo',
///   detalle: activo ? 'Se ofrece al crear productos' : 'Solo en el historial',
///   valor: activo,
///   alCambiar: (v) => setState(() => activo = v),
/// )
/// ```
class InterruptorCampo extends StatelessWidget {
  const InterruptorCampo({
    super.key,
    required this.etiqueta,
    required this.detalle,
    required this.valor,
    required this.alCambiar,
    this.detalleEnUnaLinea = true,
  });

  final String etiqueta;
  final String detalle;
  final bool valor;
  final ValueChanged<bool> alCambiar;
  final bool detalleEnUnaLinea;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: ColoresApp.bgInput,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: ColoresApp.borderInput),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta, style: TipografiaApp.etiquetaCampo),
                const SizedBox(height: 2),
                Text(
                  detalle,
                  style: TipografiaApp.caption.copyWith(
                    fontSize: 12,
                    color: ColoresApp.textMuted,
                  ),
                  maxLines: detalleEnUnaLinea ? 1 : null,
                  overflow: detalleEnUnaLinea
                      ? TextOverflow.ellipsis
                      : TextOverflow.clip,
                ),
              ],
            ),
          ),
          Switch(
            value: valor,
            onChanged: alCambiar,
            activeThumbColor: ColoresApp.goGreen,
            inactiveThumbColor: ColoresApp.textDisabled,
            inactiveTrackColor: ColoresApp.border,
          ),
        ],
      ),
    );
  }
}
