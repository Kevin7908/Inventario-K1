import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/core/currency_ext.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

import '../../reserva_editor/provider/reserva_editor_provider.dart';

class ListaItemsReservadosWidget extends ConsumerWidget {
  const ListaItemsReservadosWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(reservaEditorProvider.select((s) => s.items));
    final notifier = ref.read(reservaEditorProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: ColoresApp.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Cabecera(cantidad: items.length),
          if (items.isEmpty)
            const _EstadoVacio()
          else
            Column(
              children: items
                  .map(
                    (item) => _FilaItem(
                      key: ValueKey(item.productoId),
                      item: item,
                      onCambiarCantidad: (c) =>
                          notifier.cambiarCantidad(item.productoId, c),
                      onEliminar: () => notifier.eliminarItem(item.productoId),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.cantidad});

  final int cantidad;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: ColoresApp.bgContent,
        borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
        border: Border(bottom: BorderSide(color: ColoresApp.border)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'PRODUCTOS SELECCIONADOS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: ColoresApp.primary,
                letterSpacing: 0.8,
              ),
            ),
          ),
          if (cantidad > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: ColoresApp.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$cantidad',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: ColoresApp.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20, horizontal: 14),
      child: Center(
        child: Text(
          'Selecciona productos en la grilla de arriba',
          style: TextStyle(fontSize: 12, color: ColoresApp.textLight),
        ),
      ),
    );
  }
}

class _FilaItem extends StatelessWidget {
  const _FilaItem({
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ColoresApp.border)),
      ),
      child: Row(
        children: [
          // Nombre + SKU
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nombreProducto,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: ColoresApp.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.sku,
                  style: const TextStyle(
                    fontSize: 10,
                    color: ColoresApp.textLight,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Precio unitario
          SizedBox(
            width: 90,
            child: Text(
              item.precioUnitario.toCopString(),
              style: const TextStyle(
                fontSize: 12,
                color: ColoresApp.textMedium,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 14),
          // Control de cantidad
          _ControlCantidad(
            cantidad: item.cantidad,
            onDecrement: () => onCambiarCantidad(item.cantidad - 1),
            onIncrement: () => onCambiarCantidad(item.cantidad + 1),
          ),
          const SizedBox(width: 14),
          // Subtotal
          SizedBox(
            width: 90,
            child: Text(
              item.subtotal.toCopString(),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                color: ColoresApp.textDark,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          // Eliminar
          IconButton(
            onPressed: onEliminar,
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: Colors.red,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.all(6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        _BtnQty(icono: Icons.remove, onTap: onDecrement),
        const SizedBox(width: 6),
        SizedBox(
          width: 26,
          child: Text(
            '${cantidad % 1 == 0 ? cantidad.toInt() : cantidad}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
              color: ColoresApp.textDark,
            ),
          ),
        ),
        const SizedBox(width: 6),
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
          color: ColoresApp.bgContent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: ColoresApp.border),
        ),
        child: Icon(icono, size: 13, color: ColoresApp.textMedium),
      ),
    );
  }
}
