import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/core/currency_ext.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';
import 'package:inventario_k1/frontend/share/widgets/botones/accion_boton.dart';
import 'package:inventario_k1/frontend/share/widgets/output/snack_bar_mensaje.dart';

import 'package:inventario_k1/backend/features/cotizaciones/enum/enum_cotizacion.dart';
import 'package:inventario_k1/backend/features/cotizaciones/modelo/cotizacion_item.dart';
import 'package:inventario_k1/frontend/features/cotizaciones/provider/cotizaciones_provider.dart';

class PanelItemsTabla extends ConsumerWidget {
  const PanelItemsTabla({
    super.key,
    required this.items,
    required this.cotizacionId,
  });

  final List<CotizacionItem> items;
  final int cotizacionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: ColoresApp.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          const _PanelTablaHeader(),
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: ColoresApp.border),
            PanelItemFila(
              item: items[i],
              onEliminar: () async {
                final error = await ref
                    .read(cotizacionesProvider.notifier)
                    .eliminarItem(items[i].id, cotizacionId);
                if (context.mounted && error != null) {
                  SnackBarMensaje.error(context, error);
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _PanelTablaHeader extends StatelessWidget {
  const _PanelTablaHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: ColoresApp.bgContent,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      child: const Row(
        children: [
          SizedBox(width: 72, child: _ColH('TIPO')),
          Expanded(child: _ColH('DESCRIPCIÓN')),
          SizedBox(width: 36, child: _ColH('CANT.')),
          SizedBox(width: 80, child: _ColH('P. UNIT')),
          SizedBox(width: 80, child: _ColH('SUBTOTAL')),
          SizedBox(width: 28),
        ],
      ),
    );
  }
}

class _ColH extends StatelessWidget {
  const _ColH(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: ColoresApp.textLight,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
  }
}

class PanelItemFila extends StatelessWidget {
  const PanelItemFila({
    super.key,
    required this.item,
    required this.onEliminar,
  });

  final CotizacionItem item;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final esProducto = item.tipoItem == TipoItemCotizacion.producto;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: _PanelTipoChip(esProducto: esProducto),
          ),
          Expanded(
            child: Text(
              item.descripcion,
              style:
                  const TextStyle(color: ColoresApp.textDark, fontSize: 12.5),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${item.cantidad.toInt()}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: ColoresApp.textMedium, fontSize: 12.5),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              item.precioUnitario.toCopString(),
              textAlign: TextAlign.end,
              style: const TextStyle(
                  color: ColoresApp.textMedium, fontSize: 12.5),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              item.subtotal.toCopString(),
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: ColoresApp.textDark,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 28,
            child: AccionBoton(
              icono: Icons.delete_outline_rounded,
              tooltip: 'Eliminar ítem',
              esDestructivo: true,
              alPresionar: onEliminar,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelTipoChip extends StatelessWidget {
  const _PanelTipoChip({required this.esProducto});

  final bool esProducto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: esProducto
            ? ColoresApp.primaryLight
            : ColoresApp.accentPurple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        esProducto ? 'PRODUCTO' : 'SERVICIO',
        style: TextStyle(
          color: esProducto ? ColoresApp.primary : ColoresApp.accentPurple,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class PanelSinItems extends StatelessWidget {
  const PanelSinItems({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: ColoresApp.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Column(
        children: [
          Icon(Icons.inbox_outlined, color: ColoresApp.textLight, size: 28),
          SizedBox(height: 8),
          Text(
            'Sin ítems',
            style: TextStyle(color: ColoresApp.textLight, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
