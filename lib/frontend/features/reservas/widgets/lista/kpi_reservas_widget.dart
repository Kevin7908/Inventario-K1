import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/core/currency_ext.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

import '../../provider/reservas_provider.dart';

class KpiReservasWidget extends ConsumerWidget {
  const KpiReservasWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(reservasMetricsProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        children: [
          _KpiCard(
            color: ColoresApp.primary,
            label: 'Activas',
            valor: '${m.cantActivas}',
            icono: Icons.bookmark_outline_rounded,
          ),
          const SizedBox(height: 8),
          _KpiCard(
            color: ColoresApp.statusDebt,
            label: 'Por cobrar',
            valor: m.porCobrar.toCompactCop(),
            icono: Icons.attach_money_rounded,
          ),
          const SizedBox(height: 8),
          _KpiCard(
            color: ColoresApp.statusPaid,
            label: 'Completadas',
            valor: '${m.cantCompletadas}',
            icono: Icons.check_circle_outline_rounded,
          ),
          const SizedBox(height: 8),
          _KpiCard(
            color: ColoresApp.statusPending,
            label: 'Vencidas',
            valor: '${m.cantVencidas}',
            icono: Icons.warning_amber_rounded,
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.color,
    required this.label,
    required this.valor,
    required this.icono,
  });

  final Color color;
  final String label;
  final String valor;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ColoresApp.bgContent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.textLight,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
