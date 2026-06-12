import 'package:flutter/material.dart';
import 'package:inventario_k1/core/currency_ext.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

import '../../../../../backend/features/reservas/modelo/reserva_item.dart';
import 'card_info_general_reserva_widget.dart';

class CardProductosReservadosWidget extends StatelessWidget {
  const CardProductosReservadosWidget({super.key, required this.items});

  final List<ReservaItem> items;

  @override
  Widget build(BuildContext context) {
    return CardSeccionReserva(
      titulo: 'Productos reservados',
      child: _TablaItems(items: items),
    );
  }
}

class _TablaItems extends StatelessWidget {
  const _TablaItems({required this.items});

  final List<ReservaItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _EncabezadoTabla(),
        ...items.map((it) => _FilaItem(item: it)),
      ],
    );
  }
}

class _EncabezadoTabla extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      color: ColoresApp.bgContent,
      child: const Row(
        children: [
          Expanded(
            flex: 4,
            child: _ThCell('Producto'),
          ),
          _ThCell('Cant.', align: TextAlign.right),
          SizedBox(width: 8),
          _ThCell('P. Pactado', align: TextAlign.right),
          SizedBox(width: 8),
          _ThCell('Subtotal', align: TextAlign.right),
        ],
      ),
    );
  }
}

class _ThCell extends StatelessWidget {
  const _ThCell(this.text, {this.align = TextAlign.left});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      textAlign: align,
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        color: ColoresApp.textLight,
        letterSpacing: 0.7,
      ),
    );
  }
}

class _FilaItem extends StatelessWidget {
  const _FilaItem({required this.item});

  final ReservaItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: ColoresApp.border)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
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
          Text(
            '${item.cantidad % 1 == 0 ? item.cantidad.toInt() : item.cantidad}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12.5,
              color: ColoresApp.textMedium,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              item.precioUnitario.toCopString(),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                color: ColoresApp.textMedium,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              item.subtotal.toCopString(),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: ColoresApp.textDark,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
