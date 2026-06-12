import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/core/currency_ext.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

import '../../provider/deudores_provider.dart';

class KpiDeudoresWidget extends ConsumerWidget {
  const KpiDeudoresWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(deudoresMetricsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        children: [
          _KpiCelda(
            label: 'Cartera total',
            valor: m.carteraTotal.toCompactCop(),
            color: ColoresApp.primary,
          ),
          const SizedBox(height: 8),
          _KpiCelda(
            label: 'Saldo por cobrar',
            valor: m.saldoPorCobrar.toCompactCop(),
            color: ColoresApp.statusDebt,
          ),
          const SizedBox(height: 8),
          _KpiCelda(
            label: 'Activas',
            valor: '${m.cantActivas}',
            color: ColoresApp.statusPaid,
          ),
          const SizedBox(height: 8),
          _KpiCelda(
            label: 'Vencidas',
            valor: '${m.cantVencidas}',
            color: ColoresApp.statusPending,
          ),
        ],
      ),
    );
  }
}

class _KpiCelda extends StatelessWidget {
  const _KpiCelda({
    required this.label,
    required this.valor,
    required this.color,
  });

  final String label;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ColoresApp.bgContent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ColoresApp.textLight,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
