import 'package:flutter/material.dart';

import '../../../../../backend/features/ventas/facturas/enum/enum_facturas.dart';
import '../../../../../backend/features/ventas/facturas/modelo/factura_resumen.dart';
import '../../../../share/formateadores/moneda_formateador.dart';

class FacturasMetricas {
  const FacturasMetricas({
    required this.totalCobradoMes,
    required this.facturasMes,
    required this.saldoPendiente,
    required this.facturasPendientes,
    required this.ivaRecaudado,
    required this.totalFacturas,
  });

  final double totalCobradoMes;
  final int facturasMes;
  final double saldoPendiente;
  final int facturasPendientes;
  final double ivaRecaudado;
  final int totalFacturas;

  factory FacturasMetricas.deFacturas(List<FacturaResumen> lista) {
    final ahora = DateTime.now();
    double cobradoMes = 0;
    int facturasMes = 0;
    double pendiente = 0;
    int numPendientes = 0;

    for (final f in lista) {
      if (f.estadoPago == EstadoPago.pagado &&
          f.creadoEn != null &&
          f.creadoEn!.month == ahora.month &&
          f.creadoEn!.year == ahora.year) {
        cobradoMes += f.total;
        facturasMes++;
      }
      if (f.estadoPago == EstadoPago.pendiente) {
        pendiente += f.total;
        numPendientes++;
      }
    }

    return FacturasMetricas(
      totalCobradoMes: cobradoMes,
      facturasMes: facturasMes,
      saldoPendiente: pendiente,
      facturasPendientes: numPendientes,
      ivaRecaudado: 0, // se calcularía con join a venta_detalles
      totalFacturas: lista.length,
    );
  }
}

class FacturasResumenCartas extends StatelessWidget {
  const FacturasResumenCartas({super.key, required this.metricas});
  final FacturasMetricas metricas;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            titulo: 'Cobrado este mes',
            valor: fmtMoneda(metricas.totalCobradoMes),
            subtitulo: '${metricas.facturasMes} facturas',
            accentColor: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            titulo: 'Saldo pendiente',
            valor: fmtMoneda(metricas.saldoPendiente),
            subtitulo: '${metricas.facturasPendientes} facturas',
            accentColor: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            titulo: 'Total facturas',
            valor: metricas.totalFacturas.toString(),
            subtitulo: 'Todas las facturas',
            accentColor: const Color(0xFF3B82F6),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.titulo,
    required this.valor,
    required this.subtitulo,
    required this.accentColor,
  });

  final String titulo;
  final String valor;
  final String subtitulo;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accentColor, width: 3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            valor,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: accentColor,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitulo,
            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}
