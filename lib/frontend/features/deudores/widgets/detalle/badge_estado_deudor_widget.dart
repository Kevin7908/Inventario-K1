import 'package:flutter/material.dart';
import 'package:inventario_k1/backend/features/deudores/enum/enum_deudor.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

class BadgeEstadoDeudorWidget extends StatelessWidget {
  const BadgeEstadoDeudorWidget({super.key, required this.estado});

  final EstadoDeudor estado;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: _dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            estado.valor,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _txtColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Color get _bgColor => switch (estado) {
        EstadoDeudor.activa => const Color(0xFFDBEAFE),
        EstadoDeudor.pagada => ColoresApp.statusPaidBg,
        EstadoDeudor.vencida => ColoresApp.statusPendingBg,
        EstadoDeudor.incobrable => ColoresApp.statusDebtBg,
      };

  Color get _txtColor => switch (estado) {
        EstadoDeudor.activa => ColoresApp.primaryDark,
        EstadoDeudor.pagada => const Color(0xFF065F46),
        EstadoDeudor.vencida => const Color(0xFF92400E),
        EstadoDeudor.incobrable => const Color(0xFF991B1B),
      };

  Color get _dotColor => switch (estado) {
        EstadoDeudor.activa => ColoresApp.primary,
        EstadoDeudor.pagada => ColoresApp.statusPaid,
        EstadoDeudor.vencida => ColoresApp.statusPending,
        EstadoDeudor.incobrable => ColoresApp.statusDebt,
      };
}
