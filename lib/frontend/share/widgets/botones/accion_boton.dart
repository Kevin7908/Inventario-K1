import 'package:flutter/material.dart';

import '../../temas/colores_app.dart';

class AccionBoton extends StatelessWidget {
  final IconData icono;
  final VoidCallback? alPresionar;
  final String tooltip;
  final bool esDestructivo;

  const AccionBoton({
    super.key,
    required this.icono,
    this.alPresionar,
    required this.tooltip,
    this.esDestructivo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: alPresionar,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: esDestructivo
                ? ColoresApp.statusDebtBg
                : ColoresApp.bgContent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: esDestructivo
                  ? ColoresApp.statusDebt.withOpacity(0.2)
                  : ColoresApp.border,
            ),
          ),
          child: Icon(
            icono,
            size: 15,
            color: esDestructivo
                ? ColoresApp.statusDebt
                : ColoresApp.textMedium,
          ),
        ),
      ),
    );
  }
}
