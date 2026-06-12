import 'package:flutter/material.dart';
import 'package:inventario_k1/core/currency_ext.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

import '../../reserva_editor/provider/reserva_editor_provider.dart';

class ItemSeleccionadoReservaWidget extends StatelessWidget {
  const ItemSeleccionadoReservaWidget({
    super.key,
    required this.item,
    required this.onCambiarCantidad,
    required this.onEliminar,
  });

  final ReservaItemDraft item;
  final ValueChanged<double> onCambiarCantidad;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ColoresApp.bgContent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined,
              size: 18, color: ColoresApp.textLight),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nombreProducto,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${item.sku} · ${item.precioUnitario.toCopString()} c/u',
                  style: const TextStyle(
                    fontSize: 10,
                    color: ColoresApp.textMedium,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ControlCantidad(
            cantidad: item.cantidad,
            onDecrement: () => onCambiarCantidad(item.cantidad - 1),
            onIncrement: () => onCambiarCantidad(item.cantidad + 1),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 75,
            child: Text(
              item.subtotal.toCopString(),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                color: ColoresApp.textDark,
              ),
            ),
          ),
          const SizedBox(width: 6),
          _BotonEliminar(onEliminar: onEliminar),
        ],
      ),
    );
  }
}

class _ControlCantidad extends StatelessWidget {
  const _ControlCantidad({
    required this.cantidad,
    required this.onDecrement,
    required this.onIncrement,
  });

  final double cantidad;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _BtnQty(icono: Icons.remove, onTap: onDecrement),
        const SizedBox(width: 5),
        SizedBox(
          width: 24,
          child: Text(
            '${cantidad % 1 == 0 ? cantidad.toInt() : cantidad}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
              color: ColoresApp.textDark,
            ),
          ),
        ),
        const SizedBox(width: 5),
        _BtnQty(icono: Icons.add, onTap: onIncrement),
      ],
    );
  }
}

class _BtnQty extends StatelessWidget {
  const _BtnQty({required this.icono, required this.onTap});

  final IconData icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: ColoresApp.bgCard,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: ColoresApp.border),
        ),
        child: Icon(icono, size: 13, color: ColoresApp.textMedium),
      ),
    );
  }
}

class _BotonEliminar extends StatelessWidget {
  const _BotonEliminar({required this.onEliminar});

  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onEliminar,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: ColoresApp.statusDebtBg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.close_rounded,
            size: 13, color: ColoresApp.statusDebt),
      ),
    );
  }
}
