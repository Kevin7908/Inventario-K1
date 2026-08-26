import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Chip de color que comunica el estado de un registro
/// (Activo, Pagado, Pendiente, Anulado…).
///
/// Es puramente presentacional: recibe ya resuelto el texto y los colores. El
/// módulo que lo usa decide qué estado corresponde a qué color, normalmente
/// con las parejas `statusXxx` / `statusXxxBg` de [ColoresApp].
///
/// Parámetros:
/// - [etiqueta]: texto del estado.
/// - [color]: color del texto y del punto indicador.
/// - [colorFondo]: color de fondo del chip.
/// - [conPunto]: antepone un círculo del mismo color que el texto.
///
/// El chip toma el ancho de su texto, pero **encoge antes que desbordar**: en
/// una celda de tabla estrecha, «Administrador» se recorta con puntos
/// suspensivos en vez de pintar la franja de overflow.
///
/// Ejemplo:
/// ```dart
/// IndicadorEstado(
///   etiqueta: 'Activo',
///   color: ColoresApp.statusSuccess,
///   colorFondo: ColoresApp.statusSuccessBg,
/// )
///
/// IndicadorEstado(
///   etiqueta: 'Stock bajo',
///   color: ColoresApp.statusWarning,
///   colorFondo: ColoresApp.statusWarningBg,
///   conPunto: true,
/// )
/// ```
class IndicadorEstado extends StatelessWidget {
  const IndicadorEstado({
    super.key,
    required this.etiqueta,
    required this.color,
    required this.colorFondo,
    this.conPunto = false,
  });

  final String etiqueta;
  final Color color;
  final Color colorFondo;
  final bool conPunto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (conPunto) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: Text(
              etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TipografiaApp.caption.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
