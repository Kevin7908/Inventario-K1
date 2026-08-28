import 'package:flutter/material.dart';

import '../../formateadores/moneda_formateador.dart';
import '../../temas/colores_app.dart';

/// Escucha un [TextEditingController] y muestra el valor formateado como
/// pesos colombianos en tiempo real.
///
/// Si se proporciona [multiplicador], muestra [valor_campo × multiplicador]
/// (útil para previews de subtotal cuando el precio es fijo).
class PrecioCopWidget extends StatelessWidget {
  const PrecioCopWidget({
    super.key,
    required this.controller,
    this.multiplicador,
    this.etiqueta,
    this.style,
  });

  final TextEditingController controller;

  /// Si no es null, el resultado mostrado es `campo × multiplicador`.
  final num? multiplicador;

  /// Texto que aparece antes del valor (ej. "Subtotal:").
  final String? etiqueta;

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        final numero = double.tryParse(
              value.text.replaceAll(',', '').replaceAll('.', '').trim(),
            ) ??
            0;
        final resultado = multiplicador != null ? numero * multiplicador! : numero;

        return Row(
          children: [
            if (etiqueta != null) ...[
              Text(
                '$etiqueta ',
                style: const TextStyle(
                  fontSize: 12,
                  color: ColoresApp.textMedium,
                ),
              ),
            ],
            Text(
              fmtMoneda(resultado),
              style: style ??
                  const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.primary,
                  ),
            ),
          ],
        );
      },
    );
  }
}
