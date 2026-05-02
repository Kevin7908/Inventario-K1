import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

class BadgeEstado extends StatelessWidget {

    final bool activo;

  const BadgeEstado({super.key, required this.activo});

  static const _colorActivo = ColoresApp.statusPaid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: activo
            ? _colorActivo.withOpacity(0.12)
            : ColoresApp.bgContent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: activo
              ? _colorActivo.withOpacity(0.3)
              : ColoresApp.border,
        ),
      ),
      child: Text(
        activo ? 'Activo' : 'Inactivo',
        style: TextStyle(
          color: activo ? _colorActivo : ColoresApp.textLight,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}