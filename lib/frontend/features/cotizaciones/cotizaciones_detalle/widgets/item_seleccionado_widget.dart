import 'package:flutter/material.dart';
import 'package:inventario_k1/core/currency_ext.dart';

import '../../../../../../frontend/share/temas/colores_app.dart';
import '../../widgets/dialogo/dialogo_cot_items_tabla.dart';

/// Fila de un producto seleccionado dentro del panel de ítems de la cotización.
class ItemSeleccionadoWidget extends StatelessWidget {
  const ItemSeleccionadoWidget({
    super.key,
    required this.item,
    required this.onEliminar,
  });

  final CotItemDraft item;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.descripcion,
                  style: const TextStyle(
                    color: ColoresApp.textDark,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.cantidad.toInt()} × ${item.precioUnitario.toCopString()}',
                  style: const TextStyle(
                    color: ColoresApp.textMedium,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.subtotal.toCopString(),
                style: const TextStyle(
                  color: ColoresApp.textDark,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: onEliminar,
                child: const Icon(
                  Icons.delete_outline_rounded,
                  size: 16,
                  color: ColoresApp.textLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
