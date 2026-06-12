import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

import '../../../../../backend/features/reservas/enum/enum_reserva.dart';

class BadgeEstadoReservaWidget extends StatelessWidget {
  const BadgeEstadoReservaWidget({super.key, required this.estado});

  final EstadoReserva estado;

  Color get _bg {
    return switch (estado) {
      EstadoReserva.activa => ColoresApp.statusPaidBg,
      EstadoReserva.completada => ColoresApp.primaryLight,
      EstadoReserva.cancelada => ColoresApp.statusDebtBg,
    };
  }

  Color get _fg {
    return switch (estado) {
      EstadoReserva.activa => ColoresApp.statusPaid,
      EstadoReserva.completada => ColoresApp.primary,
      EstadoReserva.cancelada => ColoresApp.statusDebt,
    };
  }

  String get _label {
    return switch (estado) {
      EstadoReserva.activa => 'Activa',
      EstadoReserva.completada => 'Completada',
      EstadoReserva.cancelada => 'Cancelada',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: _fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            _label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _fg,
            ),
          ),
        ],
      ),
    );
  }
}
