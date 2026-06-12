import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../backend/features/ventas/facturas/enum/enum_facturas.dart';
import '../../../../../share/temas/colores_app.dart';
import '../../../../../share/widgets/output/snack_bar_mensaje.dart';
import '../../provider/facturas_provider.dart';

class FacturaTopBar extends ConsumerWidget {
  const FacturaTopBar({
    super.key,
    required this.facturaId,
    required this.onVolver,
    required this.onEditar,
    required this.onEliminar,
    this.readOnly = false,
  });

  final int facturaId;
  final VoidCallback onVolver;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalle = ref.watch(
      facturaDetalleProvider(facturaId).select((a) => a.value),
    );
    if (detalle == null) return const SizedBox.shrink();

    return Container(
      height: 56,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Volver
          InkWell(
            onTap: onVolver,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.arrow_back_ios_new_rounded,
                      size: 14, color: ColoresApp.textMedium),
                  SizedBox(width: 4),
                  Text(
                    'Ventas',
                    style: TextStyle(
                        fontSize: 13, color: ColoresApp.textMedium),
                  ),
                ],
              ),
            ),
          ),
          const Text(' / ', style: TextStyle(color: ColoresApp.textLight)),
          Text(
            detalle.numeroFactura,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ColoresApp.textDark,
            ),
          ),
          const Spacer(),

          // Imprimir (deshabilitado por ahora)
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.print_outlined, size: 15),
            label: const Text('Imprimir'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ColoresApp.textMedium,
              disabledForegroundColor: ColoresApp.textLight,
              side: const BorderSide(color: ColoresApp.border),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),

          // Cambiar estado pago rápido
          _SelectorEstadoPago(facturaId: facturaId),
          const SizedBox(width: 8),

          if (!readOnly) ...[
            // Editar
            OutlinedButton.icon(
              onPressed: onEditar,
              icon: const Icon(Icons.edit_outlined, size: 15),
              label: const Text('Editar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ColoresApp.primary,
                side: const BorderSide(color: ColoresApp.primary),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),

            // Eliminar
            OutlinedButton.icon(
              onPressed: onEliminar,
              icon: const Icon(Icons.delete_outline_rounded, size: 15),
              label: const Text('Eliminar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ColoresApp.statusDebt,
                side: const BorderSide(color: ColoresApp.statusDebt),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectorEstadoPago extends ConsumerWidget {
  const _SelectorEstadoPago({required this.facturaId});
  final int facturaId;

  static const _colores = {
    EstadoPago.pagado:   Color(0xFF10B981),
    EstadoPago.pendiente: Color(0xFFF59E0B),
    EstadoPago.anulada:  Color(0xFFEF4444),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalle = ref.watch(
      facturaDetalleProvider(facturaId).select((a) => a.value),
    );
    if (detalle == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: ColoresApp.bgContent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColoresApp.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<EstadoPago>(
          value: detalle.estadoPago,
          isDense: true,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'DM Sans',
          ),
          items: EstadoPago.values.map((e) {
            final color = _colores[e]!;
            return DropdownMenuItem(
              value: e,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(e.etiqueta, style: TextStyle(color: color)),
                ],
              ),
            );
          }).toList(),
          onChanged: (nuevo) async {
            if (nuevo == null || nuevo == detalle.estadoPago) return;
            final error = await ref.read(facturasProvider.notifier).actualizar(
                  id:         facturaId,
                  metodoPago: detalle.metodoPago,
                  estadoPago: nuevo,
                  iva:        detalle.iva,
                );
            if (!context.mounted) return;
            if (error != null) SnackBarMensaje.error(context, error);
          },
        ),
      ),
    );
  }
}
