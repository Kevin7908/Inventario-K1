import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Línea de dato con ícono a la izquierda: contacto, teléfono, ciudad…
///
/// Es la fila que el diseño repite dentro de las tarjetas de ficha
/// (proveedores, clientes, técnicos), donde cada dato es una línea suelta y no
/// una celda de tabla. Se apila en una `Column` con `separacion` entre filas.
///
/// Parámetros:
/// - [icono]: ícono de la izquierda, del tamaño del texto.
/// - [texto]: contenido. Se recorta con "…" si no cabe.
/// - [color]: color del texto. Por defecto `ColoresApp.textSecondary`.
/// - [colorIcono]: color del ícono. Por defecto `ColoresApp.textDisabled`,
///   más tenue que el texto para que la lista se lea por el contenido.
/// - [destacado]: sube el peso a semibold y tiñe también el ícono con [color].
///   Es el "24 productos" en verde de la tarjeta de proveedor.
///
/// Ejemplo:
/// ```dart
/// Column(
///   crossAxisAlignment: CrossAxisAlignment.start,
///   children: [
///     FilaDato(icono: Icons.person_outline_rounded, texto: 'Carlos Méndez'),
///     const SizedBox(height: 9),
///     FilaDato(
///       icono: Icons.inventory_2_outlined,
///       texto: '24 productos',
///       color: ColoresApp.castletonGreen,
///       destacado: true,
///     ),
///   ],
/// )
/// ```
class FilaDato extends StatelessWidget {
  const FilaDato({
    super.key,
    required this.icono,
    required this.texto,
    this.color,
    this.colorIcono,
    this.destacado = false,
  });

  final IconData icono;
  final String texto;
  final Color? color;
  final Color? colorIcono;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final tinta = color ?? ColoresApp.textSecondary;

    return Row(
      children: [
        Icon(
          icono,
          size: 16,
          color: destacado ? tinta : (colorIcono ?? ColoresApp.textDisabled),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            texto,
            style: TipografiaApp.cuerpo.copyWith(
              fontSize: 13,
              fontWeight: destacado ? FontWeight.w600 : FontWeight.w500,
              color: tinta,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
