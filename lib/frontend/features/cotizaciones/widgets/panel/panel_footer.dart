import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/core/currency_ext.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

import 'package:inventario_k1/backend/features/cotizaciones/modelo/cotizacion_resumen.dart';
import 'package:inventario_k1/frontend/features/cotizaciones/provider/cotizaciones_provider.dart';

class PanelCotFooter extends ConsumerWidget {
  const PanelCotFooter({super.key, required this.cotizacion});

  final CotizacionResumen cotizacion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Usa totales del detalle si ya están cargados (reflejan cambios en ítems)
    final detalleAsync = ref.watch(cotizacionDetalleProvider(cotizacion.id));
    final resumen = detalleAsync.value?.resumen ?? cotizacion;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: ColoresApp.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PanelTotalFila(label: 'Subtotal', valor: resumen.subtotal),
          const SizedBox(height: 4),
          PanelTotalFila(label: 'IVA (19%)', valor: resumen.iva),
          const Divider(height: 14, color: ColoresApp.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  color: ColoresApp.textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                resumen.total.toCopString(),
                style: const TextStyle(
                  color: ColoresApp.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.print_outlined, size: 15),
                  label: const Text('Imprimir'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ColoresApp.textMedium,
                    disabledForegroundColor:
                        ColoresApp.textLight.withValues(alpha: 0.7),
                    side: const BorderSide(color: ColoresApp.border),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.bookmark_add_outlined, size: 15),
                  label: const Text('Crear Reserva'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColoresApp.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        ColoresApp.primary.withValues(alpha: 0.4),
                    disabledForegroundColor:
                        Colors.white.withValues(alpha: 0.6),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PanelTotalFila extends StatelessWidget {
  const PanelTotalFila({super.key, required this.label, required this.valor});

  final String label;
  final int valor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: ColoresApp.textMedium, fontSize: 13),
        ),
        Text(
          valor.toCopString(),
          style: const TextStyle(color: ColoresApp.textDark, fontSize: 13),
        ),
      ],
    );
  }
}

class PanelBtnAccion extends StatelessWidget {
  const PanelBtnAccion({
    super.key,
    required this.label,
    required this.icono,
    required this.onTap,
  });

  final String label;
  final IconData icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(color: ColoresApp.primary.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
          color: ColoresApp.primaryLight,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 14, color: ColoresApp.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ColoresApp.primary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
