import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

import 'package:inventario_k1/backend/features/cotizaciones/modelo/cotizacion_resumen.dart';
import '../tabla/badge_estado_cotizacion.dart';

class PanelInfoGrid extends StatelessWidget {
  const PanelInfoGrid({super.key, required this.cotizacion});

  final CotizacionResumen cotizacion;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: PanelInfoCelda(
                    label: 'CLIENTE', valor: cotizacion.nombreCliente)),
            Expanded(
                child: PanelInfoCelda(
                    label: 'TELÉFONO',
                    valor: cotizacion.telefonoCliente ?? '—')),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
                child: PanelInfoCelda(
                    label: 'MOTO', valor: cotizacion.nombreMoto)),
            Expanded(
              child: PanelInfoCeldaWidget(
                label: 'ESTADO',
                child: BadgeEstadoCotizacion(estado: cotizacion.estado),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
                child: PanelInfoCelda(
                    label: 'VIGENCIA HASTA',
                    valor: cotizacion.vigenciaHasta)),
            Expanded(
                child: PanelInfoCelda(
                    label: 'CREADO EL',
                    valor: _fmtFecha(cotizacion.creadoEn))),
          ],
        ),
        if (cotizacion.notas != null && cotizacion.notas!.isNotEmpty) ...[
          const SizedBox(height: 14),
          PanelInfoCelda(
              label: 'NOTAS', valor: cotizacion.notas!, fullWidth: true),
        ],
      ],
    );
  }

  String _fmtFecha(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

class PanelInfoCelda extends StatelessWidget {
  const PanelInfoCelda({
    super.key,
    required this.label,
    required this.valor,
    this.fullWidth = false,
  });

  final String label;
  final String valor;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: ColoresApp.textLight,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          valor,
          style: const TextStyle(
            color: ColoresApp.textDark,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class PanelInfoCeldaWidget extends StatelessWidget {
  const PanelInfoCeldaWidget({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: ColoresApp.textLight,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}
