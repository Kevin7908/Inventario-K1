import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Un número grande con su etiqueta debajo: la tarjeta de conteo del diseño.
///
/// Es la fila de cuatro cajas que encabeza varias pantallas del mockup
/// (órdenes totales / en proceso / pendientes / completadas). El valor va
/// arriba y en grande porque es lo que se lee de un vistazo; la etiqueta
/// explica.
///
/// **No confundir con [TarjetaInfo]**, que hace lo contrario —etiqueta arriba,
/// valor debajo, sobre fondo tenue— y sirve para los datos de una ficha, no
/// para un contador de encabezado.
///
/// Parámetros:
/// - [valor]: el número, ya formateado. Se pinta a 26 px.
/// - [etiqueta]: qué cuenta ese número.
/// - [colorValor]: tiñe el número según lo que represente (naranja para lo
///   que está en curso, verde para lo terminado). Por defecto, el texto
///   principal.
/// - [alPresionar]: si se pasa, la tarjeta filtra la lista al tocarla y se
///   marca con [activa]. Si es `null`, es solo informativa y no responde.
/// - [activa]: resalta la tarjeta con borde de color. Solo tiene sentido junto
///   con [alPresionar].
///
/// Ejemplo:
/// ```dart
/// Row(
///   children: [
///     Expanded(child: TarjetaMetrica(valor: '12', etiqueta: 'Órdenes totales')),
///     const SizedBox(width: 16),
///     Expanded(
///       child: TarjetaMetrica(
///         valor: '3',
///         etiqueta: 'En proceso',
///         colorValor: ColoresApp.statusWarning,
///       ),
///     ),
///   ],
/// )
/// ```
class TarjetaMetrica extends StatelessWidget {
  const TarjetaMetrica({
    super.key,
    required this.valor,
    required this.etiqueta,
    this.colorValor,
    this.alPresionar,
    this.activa = false,
  });

  final String valor;
  final String etiqueta;
  final Color? colorValor;
  final VoidCallback? alPresionar;
  final bool activa;

  @override
  Widget build(BuildContext context) {
    final acento = colorValor ?? ColoresApp.textPrimary;

    final contenido = Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            valor,
            style: TipografiaApp.heading1.copyWith(color: acento),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            etiqueta,
            style: TipografiaApp.caption.copyWith(color: ColoresApp.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    final borde = Border.all(
      color: activa ? acento : ColoresApp.border,
      // El grosor no cambia al activarse: un borde que engorda mueve el
      // contenido de sitio y desalinea la fila entera de tarjetas.
    );

    if (alPresionar == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: ColoresApp.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: borde,
        ),
        child: contenido,
      );
    }

    return Material(
      color: ColoresApp.bgCard,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alPresionar,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: borde,
          ),
          child: contenido,
        ),
      ),
    );
  }
}
