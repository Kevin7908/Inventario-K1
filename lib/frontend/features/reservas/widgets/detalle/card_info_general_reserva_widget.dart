import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

import '../../../../../backend/features/reservas/modelo/reserva_resumen.dart';

class CardInfoGeneralReservaWidget extends StatelessWidget {
  const CardInfoGeneralReservaWidget({super.key, required this.resumen});

  final ReservaResumen resumen;

  @override
  Widget build(BuildContext context) {
    return _CardSeccion(
      titulo: 'Información general',
      child: Column(
        children: [
          Row(
            children: [
              _InfoItem(label: 'Cliente', valor: resumen.nombreCliente),
              const SizedBox(width: 12),
              _InfoItem(
                label: 'Moto',
                valor: resumen.nombreMoto != null
                    ? '${resumen.nombreMoto}'
                        '${resumen.placaMoto != null ? ' · ${resumen.placaMoto}' : ''}'
                    : '—',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _InfoItem(
                label: 'Fecha límite',
                valor: resumen.fechaLimite ?? '—',
                alerta: resumen.estaVencida,
                mono: true,
              ),
              const SizedBox(width: 12),
              _InfoItem(
                label: 'Creada',
                valor:
                    '${resumen.creadoEn.year}-${resumen.creadoEn.month.toString().padLeft(2, '0')}-${resumen.creadoEn.day.toString().padLeft(2, '0')}',
                mono: true,
              ),
            ],
          ),
          if (resumen.cotizacionId != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: _ChipCotizacion(id: resumen.cotizacionId!),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.label,
    required this.valor,
    this.alerta = false,
    this.mono = false,
  });

  final String label;
  final String valor;
  final bool alerta;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: ColoresApp.textLight,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              if (alerta)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.warning_amber_rounded,
                      size: 13, color: ColoresApp.statusDebt),
                ),
              Flexible(
                child: Text(
                  valor,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: alerta ? ColoresApp.statusDebt : ColoresApp.textDark,
                    fontFamily: mono ? 'monospace' : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipCotizacion extends StatelessWidget {
  const _ChipCotizacion({required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ColoresApp.primaryLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '📋 Cotización #$id',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ColoresApp.primary,
        ),
      ),
    );
  }
}

// ── Contenedor reutilizable de sección ────────────────────────────────────────

class _CardSeccion extends StatelessWidget {
  const _CardSeccion({required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColoresApp.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: ColoresApp.bgContent,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: ColoresApp.border)),
            ),
            child: Text(
              titulo.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: ColoresApp.primary,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }
}

// Exportar para reuso
class CardSeccionReserva extends StatelessWidget {
  const CardSeccionReserva({
    super.key,
    required this.titulo,
    required this.child,
    this.trailing,
  });

  final String titulo;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColoresApp.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: ColoresApp.bgContent,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: ColoresApp.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    titulo.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: ColoresApp.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}
