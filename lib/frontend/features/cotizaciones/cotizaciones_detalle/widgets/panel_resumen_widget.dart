import 'package:flutter/material.dart';
import 'package:inventario_k1/core/currency_ext.dart';

import '../../../../../../frontend/share/temas/colores_app.dart';
import '../../widgets/dialogo/dialogo_cot_items_tabla.dart';
import 'item_seleccionado_widget.dart';

/// Panel lateral derecho de la cotización:
/// lista de ítems seleccionados, totales y botones de acción.
class PanelResumenWidget extends StatelessWidget {
  const PanelResumenWidget({
    super.key,
    required this.items,
    required this.subtotal,
    required this.iva,
    required this.total,
    required this.cargandoItems,
    required this.onEliminarItem,
    required this.onImprimir,
    required this.onReservar,
  });

  final List<CotItemDraft> items;
  final int subtotal;
  final int iva;
  final int total;
  final bool cargandoItems;
  final ValueChanged<int> onEliminarItem;
  final VoidCallback onImprimir;
  final VoidCallback onReservar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: ColoresApp.bgCard,
        border: Border(left: BorderSide(color: ColoresApp.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Encabezado ─────────────────────────────────────────
          const _PanelEncabezado(),
          const Divider(height: 1, color: ColoresApp.border),

          // ── Lista de ítems (scrollable) ─────────────────────────
          Expanded(child: _ListaItems(
            items: items,
            cargando: cargandoItems,
            onEliminar: onEliminarItem,
          )),

          const Divider(height: 1, color: ColoresApp.border),

          // ── Totales ────────────────────────────────────────────
          _Totales(subtotal: subtotal, iva: iva, total: total),
          const Divider(height: 1, color: ColoresApp.border),

          // ── Botones ────────────────────────────────────────────
          _BotonesPanel(
            onImprimir: onImprimir,
            onReservar: onReservar,
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets del panel ─────────────────────────────────────────────────────

class _PanelEncabezado extends StatelessWidget {
  const _PanelEncabezado();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(Icons.receipt_long_outlined, size: 15, color: ColoresApp.primary),
          SizedBox(width: 8),
          Text(
            'ÍTEMS SELECCIONADOS',
            style: TextStyle(
              color: ColoresApp.textDark,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ListaItems extends StatelessWidget {
  const _ListaItems({
    required this.items,
    required this.cargando,
    required this.onEliminar,
  });

  final List<CotItemDraft> items;
  final bool cargando;
  final ValueChanged<int> onEliminar;

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Center(
        child: CircularProgressIndicator(
          color: ColoresApp.primary,
          strokeWidth: 2,
        ),
      );
    }

    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                size: 40,
                color: ColoresApp.textLight,
              ),
              SizedBox(height: 10),
              Text(
                'Selecciona productos\ndel inventario.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ColoresApp.textLight,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: items.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: ColoresApp.border, indent: 12, endIndent: 12),
      itemBuilder: (_, i) => ItemSeleccionadoWidget(
        key: ValueKey(i),
        item: items[i],
        onEliminar: () => onEliminar(i),
      ),
    );
  }
}

class _Totales extends StatelessWidget {
  const _Totales({
    required this.subtotal,
    required this.iva,
    required this.total,
  });

  final int subtotal;
  final int iva;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          _FilaTotal(
            label: 'Subtotal',
            valor: subtotal.toCopString(),
            negrita: false,
          ),
          const SizedBox(height: 4),
          _FilaTotal(
            label: 'IVA (19%)',
            valor: iva.toCopString(),
            negrita: false,
          ),
          const SizedBox(height: 8),
          _FilaTotal(
            label: 'TOTAL',
            valor: total.toCopString(),
            negrita: true,
            colorValor: ColoresApp.primary,
          ),
        ],
      ),
    );
  }
}

class _FilaTotal extends StatelessWidget {
  const _FilaTotal({
    required this.label,
    required this.valor,
    required this.negrita,
    this.colorValor,
  });

  final String label;
  final String valor;
  final bool negrita;
  final Color? colorValor;

  @override
  Widget build(BuildContext context) {
    final peso = negrita ? FontWeight.w700 : FontWeight.w500;
    final size = negrita ? 14.0 : 12.5;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: negrita ? ColoresApp.textDark : ColoresApp.textMedium,
            fontSize: size,
            fontWeight: peso,
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            color: colorValor ?? (negrita ? ColoresApp.textDark : ColoresApp.textMedium),
            fontSize: size,
            fontWeight: peso,
          ),
        ),
      ],
    );
  }
}

class _BotonesPanel extends StatelessWidget {
  const _BotonesPanel({
    required this.onImprimir,
    required this.onReservar,
  });

  final VoidCallback onImprimir;
  final VoidCallback onReservar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onImprimir,
              icon: const Icon(Icons.print_outlined, size: 15),
              label: const Text('Imprimir'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ColoresApp.textMedium,
                side: const BorderSide(color: ColoresApp.border),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onReservar,
              icon: const Icon(Icons.bookmark_border_rounded, size: 15),
              label: const Text('Reservar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColoresApp.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
