import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Una línea del historial de dinero de un documento: qué entró, cuándo y
/// cuánto.
///
/// La comparten los abonos de una reserva y los pagos de una deuda, que son la
/// misma lista con otro nombre. El **signo lo interpreta quien la usa**: una
/// devolución de reserva llega ya con su ícono de vuelta, su rótulo y su color
/// rojo, porque share2 no sabe qué significa un importe negativo en cada
/// módulo.
///
/// El importe llega **ya formateado**, como en el resto de share2.
///
/// Parámetros:
/// - [icono]: la flecha o el símbolo del movimiento.
/// - [titulo]: qué fue —el método de pago, o «Devolución»—.
/// - [detalle]: la línea tenue de abajo: fecha y referencia.
/// - [importe]: el número de la derecha, ya formateado.
/// - [color]: el del ícono y el importe.
/// - [alEliminar]: si se pasa, aparece la papelera al final. Sin él la fila es
///   solo de lectura, que es lo normal en un libro que no se corrige.
///
/// Ejemplo:
/// ```dart
/// FilaMovimiento(
///   icono: Icons.arrow_downward_rounded,
///   titulo: pago.metodoPago.etiqueta,
///   detalle: formatearFecha(pago.fechaPago),
///   importe: formatearPrecio(pago.monto),
///   color: ColoresApp.statusSuccess,
/// )
/// ```
class FilaMovimiento extends StatelessWidget {
  const FilaMovimiento({
    super.key,
    required this.icono,
    required this.titulo,
    required this.importe,
    required this.color,
    this.detalle,
    this.alEliminar,
  });

  final IconData icono;
  final String titulo;
  final String importe;
  final Color color;
  final String? detalle;
  final VoidCallback? alEliminar;

  @override
  Widget build(BuildContext context) {
    final detalle = this.detalle;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icono, size: 15, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titulo,
                  style: TipografiaApp.cuerpoMedium.copyWith(fontSize: 12.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (detalle != null && detalle.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    detalle,
                    style: TipografiaApp.caption.copyWith(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            importe,
            style: TipografiaApp.cuerpoMedium.copyWith(
              fontSize: 13,
              color: color,
            ),
          ),
          if (alEliminar != null) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: alEliminar,
              icon: const Icon(Icons.delete_outline_rounded, size: 17),
              color: ColoresApp.textMuted,
              hoverColor: ColoresApp.statusDangerBg,
              tooltip: 'Borrar este movimiento',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 30, height: 30),
              padding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
    );
  }
}
