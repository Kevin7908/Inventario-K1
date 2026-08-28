import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Dato destacado en una caja compacta: una etiqueta arriba y su valor debajo.
///
/// Se usa en grupos para resumir los números de una ficha (stock disponible,
/// stock mínimo, ubicación, unidad de medida) o como KPI suelto.
///
/// Parámetros:
/// - [etiqueta]: nombre del dato (ej. "Stock disponible").
/// - [valor]: valor a destacar (ej. "42 und").
/// - [colorValor]: color del valor. Por defecto `ColoresApp.textPrimary`;
///   útil para teñirlo según un estado (rojo si el stock está en cero).
/// - [icono]: ícono opcional a la izquierda de la etiqueta.
///
/// Ejemplo:
/// ```dart
/// Row(
///   children: [
///     Expanded(child: TarjetaInfo(etiqueta: 'Stock disponible', valor: '42 und')),
///     const SizedBox(width: 13),
///     Expanded(child: TarjetaInfo(etiqueta: 'Stock mínimo', valor: '10 und')),
///   ],
/// )
/// ```
class TarjetaInfo extends StatelessWidget {
  const TarjetaInfo({
    super.key,
    required this.etiqueta,
    required this.valor,
    this.colorValor,
    this.icono,
  });

  final String etiqueta;
  final String valor;
  final Color? colorValor;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ColoresApp.bgInput,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColoresApp.borderFila),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icono != null) ...[
                Icon(icono, size: 14, color: ColoresApp.textDisabled),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  etiqueta,
                  style: TipografiaApp.caption.copyWith(
                    fontSize: 11.5,
                    color: ColoresApp.textDisabled,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TipografiaApp.subtitulo.copyWith(
              fontSize: 16,
              color: colorValor ?? ColoresApp.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
