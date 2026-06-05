import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/core/currency_ext.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

import 'package:inventario_k1/frontend/features/cotizaciones/provider/cotizaciones_provider.dart';

class ResumenCardsCotizacion extends ConsumerWidget {
  const ResumenCardsCotizacion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(cotizacionesMetricsProvider);

    final totalPrevio = (m.total * 0.88).round();
    final pctTotal =
        totalPrevio > 0 ? ((m.total - totalPrevio) / totalPrevio * 100).round() : 0;
    final pctVigentes =
        m.total > 0 ? (m.cantVigentes / m.total * 100).round() : 0;

    return Row(
      children: [
        Expanded(
          child: _MetricaCard(
            titulo: 'Total Cotizaciones',
            valor: '${m.total}',
            subtitulo: '$pctTotal% este mes',
            positivo: pctTotal >= 0,
            icono: Icons.description_outlined,
            colorIcono: ColoresApp.accentBlue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MetricaCard(
            titulo: 'Valor Total',
            valor: m.valorTotal.toCompactCop(),
            subtitulo: '8% vs. mes anterior',
            positivo: true,
            icono: Icons.attach_money_rounded,
            colorIcono: ColoresApp.accentGreen,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MetricaCard(
            titulo: 'Vigentes',
            valor: '${m.cantVigentes}',
            subtitulo: '$pctVigentes% del total activo',
            positivo: true,
            icono: Icons.check_circle_outline_rounded,
            colorIcono: ColoresApp.statusPaid,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MetricaCard(
            titulo: 'Vencidas',
            valor: '${m.cantVencidas}',
            subtitulo: 'Requieren seguimiento',
            positivo: false,
            icono: Icons.warning_amber_rounded,
            colorIcono: ColoresApp.statusDebt,
            valorRojo: m.cantVencidas > 0,
          ),
        ),
      ],
    );
  }
}

class _MetricaCard extends StatelessWidget {
  const _MetricaCard({
    required this.titulo,
    required this.valor,
    required this.subtitulo,
    required this.positivo,
    required this.icono,
    required this.colorIcono,
    this.valorRojo = false,
  });

  final String titulo;
  final String valor;
  final String subtitulo;
  final bool positivo;
  final IconData icono;
  final Color colorIcono;
  final bool valorRojo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ColoresApp.bgCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: ColoresApp.shadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  color: ColoresApp.textMedium,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colorIcono.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icono, color: colorIcono, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            valor,
            style: TextStyle(
              color: valorRojo ? ColoresApp.statusDebt : ColoresApp.textDark,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                positivo
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 13,
                color: positivo ? ColoresApp.accentGreen : ColoresApp.accentRed,
              ),
              const SizedBox(width: 3),
              Text(
                subtitulo,
                style: TextStyle(
                  color:
                      positivo ? ColoresApp.accentGreen : ColoresApp.textMedium,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
