import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

import 'package:inventario_k1/backend/features/cotizaciones/modelo/cotizacion_resumen.dart';
import 'package:inventario_k1/frontend/features/cotizaciones/provider/cotizaciones_provider.dart';
import '../agregar_item/dialogo_agregar_item.dart';
import 'panel_cot_header.dart';
import 'panel_footer.dart';
import 'panel_info_grid.dart';
import 'panel_items_tabla.dart';

class PanelDetalleCotizacion extends ConsumerWidget {
  const PanelDetalleCotizacion({
    super.key,
    required this.cotizacion,
    required this.onCerrar,
  });

  final CotizacionResumen cotizacion;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalleAsync = ref.watch(cotizacionDetalleProvider(cotizacion.id));

    return Container(
      width: 390,
      decoration: const BoxDecoration(
        color: ColoresApp.bgCard,
        border: Border(left: BorderSide(color: ColoresApp.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelCotHeader(cotizacion: cotizacion, onCerrar: onCerrar),

          Expanded(
            child: detalleAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: ColoresApp.primary),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Error: $e',
                  style: const TextStyle(color: ColoresApp.statusDebt),
                ),
              ),
              data: (detalle) => SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PanelInfoGrid(cotizacion: detalle.resumen),
                    const SizedBox(height: 20),

                    const Text(
                      'Ítems de la cotización',
                      style: TextStyle(
                        color: ColoresApp.textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),

                    detalle.items.isEmpty
                        ? const PanelSinItems()
                        : PanelItemsTabla(
                            items: detalle.items,
                            cotizacionId: cotizacion.id,
                          ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: PanelBtnAccion(
                        label: '+ Agregar Producto',
                        icono: Icons.inventory_2_outlined,
                        onTap: () => DialogoAgregarProducto.mostrar(
                          context,
                          cotizacionId: cotizacion.id,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          PanelCotFooter(cotizacion: cotizacion),
        ],
      ),
    );
  }
}
