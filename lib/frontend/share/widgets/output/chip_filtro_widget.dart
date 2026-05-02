import 'package:flutter/material.dart';

import '../../temas/colores_app.dart';

class ChipFiltro extends StatelessWidget {
  final String etiqueta;
  final bool seleccionado;
  final VoidCallback alPresionar;
  final Color? color;

  const ChipFiltro({
    super.key,
    required this.etiqueta,
    required this.seleccionado,
    required this.alPresionar,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorEfectivo = color ?? ColoresApp.primary;
    return GestureDetector(
      onTap: alPresionar,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: seleccionado
              ? colorEfectivo.withOpacity(0.1)
              : ColoresApp.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: seleccionado
                ? colorEfectivo.withOpacity(0.4)
                : ColoresApp.border,
          ),
        ),
        child: Text(
          etiqueta,
          style: TextStyle(
            color: seleccionado ? colorEfectivo : ColoresApp.textMedium,
            fontSize: 12.5,
            fontWeight: seleccionado ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
