import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../../backend/features/ventas/ordenes/modelo/orden_repuesto.dart';
import '../../../../../../share/temas/colores_app.dart';
import '../../../../../../share/widgets/botones/dialogo_confirmar_eliminar_widget.dart';
import '../../../../../../share/widgets/output/snack_bar_mensaje.dart';
import '../../../provider/ordenes_provider.dart';
import '../../helpers/formateadores.dart';
import '../detalle_shared_widgets.dart';

class RepuestosListaCard extends ConsumerWidget {
  const RepuestosListaCard({super.key, required this.ordenId});
  final int ordenId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repuestos = ref.watch(
      ordenDetalleProvider(ordenId).select(
        (a) => a.value?.repuestos ?? const [],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const SeccionHeader(
            titulo: 'Repuestos utilizados',
            icono: Icons.inventory_2_outlined,
          ),
          if (repuestos.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 14),
                  Expanded(child: EncabezadoCol('Producto')),
                  SizedBox(width: 60, child: EncabezadoCol('Cant.', center: true)),
                  SizedBox(width: 100, child: EncabezadoCol('P. Unit.', right: true)),
                  SizedBox(width: 100, child: EncabezadoCol('Subtotal', right: true)),
                  SizedBox(width: 50),
                ],
              ),
            ),
            Column(
              children: repuestos
                  .map((r) => _FilaRepuesto(repuesto: r, ordenId: ordenId))
                  .toList(),
            ),
          ] else
            const EstadoVacioSeccion(mensaje: 'Sin repuestos registrados'),
        ],
      ),
    );
  }
}

class _FilaRepuesto extends ConsumerWidget {
  const _FilaRepuesto({required this.repuesto, required this.ordenId});
  final OrdenRepuesto repuesto;
  final int ordenId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: ColoresApp.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              repuesto.productoNombre,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: ColoresApp.textDark,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              '×${repuesto.cantidad % 1 == 0 ? repuesto.cantidad.toInt() : repuesto.cantidad}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: ColoresApp.textMedium,
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              fmtMoneda(repuesto.precioUnitario),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12.5,
                color: ColoresApp.textMedium,
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              fmtMoneda(repuesto.subtotal),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ColoresApp.textDark,
              ),
            ),
          ),
          SizedBox(
            width: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                MiniBoton(
                  icono: Icons.delete_outline_rounded,
                  color: ColoresApp.statusDebt,
                  onTap: () => DialogoConfirmarEliminar.mostrar(
                    context: context,
                    nombreElemento: repuesto.productoNombre,
                    tipoElemento: 'repuesto',
                    onConfirmar: () async {
                      final error = await ref
                          .read(ordenesProvider.notifier)
                          .eliminarRepuesto(repuesto.id, ordenId);
                      if (!context.mounted) return;
                      if (error != null) {
                        SnackBarMensaje.error(context, error);
                      } else {
                        SnackBarMensaje.success(
                            context, 'Repuesto eliminado y stock restaurado.');
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
