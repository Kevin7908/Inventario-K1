import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

import 'package:inventario_k1/backend/features/cotizaciones/modelo/cotizacion_resumen.dart';

class PanelCotHeader extends StatelessWidget {
  const PanelCotHeader({
    super.key,
    required this.cotizacion,
    required this.onCerrar,
  });

  final CotizacionResumen cotizacion;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ColoresApp.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cotizacion.numero,
                  style: const TextStyle(
                    color: ColoresApp.textDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${cotizacion.nombreCliente} · ${cotizacion.vigenciaHasta}',
                  style: const TextStyle(
                      color: ColoresApp.textMedium, fontSize: 12.5),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: ColoresApp.textMedium, size: 20),
            onPressed: onCerrar,
          ),
        ],
      ),
    );
  }
}
