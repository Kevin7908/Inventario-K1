import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

import 'package:inventario_k1/backend/features/cotizaciones/modelo/cotizacion_resumen.dart';

class BadgeEstadoCotizacion extends StatelessWidget {
  const BadgeEstadoCotizacion({super.key, required this.estado});

  final EstadoCotizacion estado;

  @override
  Widget build(BuildContext context) {
    final (label, color, bgColor) = switch (estado) {
      EstadoCotizacion.vigente => (
          'Vigente',
          ColoresApp.statusPaid,
          ColoresApp.statusPaidBg,
        ),
      EstadoCotizacion.porVencer => (
          'Por vencer',
          ColoresApp.statusPending,
          ColoresApp.statusPendingBg,
        ),
      EstadoCotizacion.vencida => (
          'Vencida',
          ColoresApp.statusDebt,
          ColoresApp.statusDebtBg,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
