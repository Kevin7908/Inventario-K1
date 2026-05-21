import 'package:flutter/material.dart';

import '../../../../../backend/features/ventas/ordenes/enum/enum_ordenes.dart';
import '../../../../../backend/features/ventas/ordenes/modelo/orden_resumen.dart';

class OrdenesMetricas {
  const OrdenesMetricas({
    required this.abiertas,
    required this.listasParaEntrega,
    required this.entregadasMes,
    required this.sinDiagnostico,
  });

  final int abiertas;
  final int listasParaEntrega;
  final int entregadasMes;
  final int sinDiagnostico;

  factory OrdenesMetricas.deOrdenes(List<OrdenResumen> ordenes) {
    final ahora = DateTime.now();
    return OrdenesMetricas(
      abiertas: ordenes
          .where((o) => o.estado == EstadoOrden.abierta)
          .length,
      listasParaEntrega: ordenes
          .where((o) => o.estado == EstadoOrden.lista)
          .length,
      // Ahora fechaIngreso es DateTime?, no String
      entregadasMes: ordenes.where((o) {
        if (o.estado != EstadoOrden.entregada || o.fechaIngreso == null) {
          return false;
        }
        final dt = o.fechaIngreso!;
        return dt.month == ahora.month && dt.year == ahora.year;
      }).length,
      sinDiagnostico: ordenes
          .where(
            (o) =>
                o.estado == EstadoOrden.abierta &&
                (o.diagnostico == null || o.diagnostico!.isEmpty),
          )
          .length,
    );
  }
}

class OrdenesResumenCards extends StatelessWidget {
  const OrdenesResumenCards({super.key, required this.metricas});

  final OrdenesMetricas metricas;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            titulo: 'Órdenes abiertas',
            valor: metricas.abiertas.toString(),
            subtitulo: '${metricas.sinDiagnostico} sin diagnóstico',
            accentColor: const Color(0xFF6366F1),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            titulo: 'Listas p/ entrega',
            valor: metricas.listasParaEntrega.toString(),
            subtitulo: 'Pendientes de cobro',
            accentColor: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            titulo: 'Entregadas / mes',
            valor: metricas.entregadasMes.toString(),
            subtitulo: 'Este mes',
            accentColor: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            titulo: 'Sin diagnóstico',
            valor: metricas.sinDiagnostico.toString(),
            subtitulo: 'Requieren atención',
            accentColor: const Color(0xFF8B5CF6),
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
              fontSize: 32,
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