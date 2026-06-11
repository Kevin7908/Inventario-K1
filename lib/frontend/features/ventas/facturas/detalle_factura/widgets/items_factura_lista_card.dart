import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../backend/features/ventas/facturas/enum/enum_facturas.dart';
import '../../../../../../backend/features/ventas/facturas/modelo/venta_item.dart';
import '../../../../../share/formateadores/moneda_formateador.dart';
import '../../../../../share/temas/colores_app.dart';
import '../../../../../share/widgets/dialogos/dialogo_confirmar_eliminar_widget.dart';
import '../../../../../share/widgets/output/snack_bar_mensaje.dart';
import '../../provider/facturas_provider.dart';
import 'detalle_shared_widgets_factura.dart';
import 'dialogo_agregar_item_factura.dart';
import 'dialogo_editar_item_factura.dart';

class ItemsFacturaListaCard extends ConsumerWidget {
  const ItemsFacturaListaCard({
    super.key,
    required this.facturaId,
    this.readOnly = false,
  });
  final int facturaId;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalle = ref.watch(
      facturaDetalleProvider(facturaId).select((a) => a.value),
    );
    if (detalle == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColoresApp.border),
        boxShadow: const [
          BoxShadow(color: Color(0x07000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SeccionHeaderFactura(
            titulo: 'Items facturados',
            icono: Icons.receipt_outlined,
            accion: null,
          ),
          if (detalle.items.isEmpty)
            const EstadoVacioSeccionFactura(mensaje: 'Sin items. Agrega servicios o productos.')
          else ...[
            _EncabezadoItems(readOnly: readOnly),
            ...detalle.items.map(
              (item) => _FilaItem(
                key: ValueKey(item.id),
                item: item,
                facturaId: facturaId,
                readOnly: readOnly,
              ),
            ),
          ],
        ],
      ),
    );
  }
}


class _EncabezadoItems extends StatelessWidget {
  const _EncabezadoItems({this.readOnly = false});
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: ColoresApp.border)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 90, child: EncabezadoColFac('Tipo')),
          const Expanded(child: EncabezadoColFac('Descripción')),
          const SizedBox(width: 60, child: EncabezadoColFac('Cant.', center: true)),
          const SizedBox(width: 90, child: EncabezadoColFac('P. Unit.', right: true)),
          const SizedBox(width: 90, child: EncabezadoColFac('Subtotal', right: true)),
          if (!readOnly) const SizedBox(width: 60),
        ],
      ),
    );
  }
}

class _FilaItem extends ConsumerWidget {
  const _FilaItem({
    super.key,
    required this.item,
    required this.facturaId,
    this.readOnly = false,
  });
  final VentaItem item;
  final int facturaId;
  final bool readOnly;

  void _confirmarEliminar(BuildContext context, WidgetRef ref) {
    DialogoConfirmarEliminar.mostrar(
      context: context,
      nombreElemento: item.descripcion,
      tipoElemento: 'item',
      onConfirmar: () async {
        final error = await ref.read(facturasProvider.notifier)
            .eliminarItem(item.id, facturaId);
        if (!context.mounted) return;
        if (error != null) SnackBarMensaje.error(context, error);
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _BadgeTipoItem(tipo: item.tipoItem),
            ),
          ),
          Expanded(
            child: Text(
              item.descripcion,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: ColoresApp.textDark),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              item.cantidad % 1 == 0
                  ? 'x${item.cantidad.toInt()}'
                  : 'x${item.cantidad.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: ColoresApp.textMedium),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              fmtMoneda(item.precioUnitario),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, color: ColoresApp.textDark),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              fmtMoneda(item.subtotal),
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ColoresApp.textDark),
            ),
          ),
          if (!readOnly)
            SizedBox(
              width: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MiniBotonFac(
                    icono: Icons.edit_outlined,
                    color: ColoresApp.primary,
                    onTap: () {
                      if (item.tipoItem == TipoItem.servicio) {
                        DialogoAgregarItemServicio.mostrar(
                          context,
                          ventaId: facturaId,
                          itemAEditar: item,
                        );
                      } else {
                        DialogoEditarItemFactura.mostrar(
                          context,
                          ventaId: facturaId,
                          item: item,
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  MiniBotonFac(
                    icono: Icons.delete_outline_rounded,
                    color: ColoresApp.statusDebt,
                    onTap: () => _confirmarEliminar(context, ref),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BadgeTipoItem extends StatelessWidget {
  const _BadgeTipoItem({required this.tipo});
  final TipoItem tipo;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (tipo) {
      TipoItem.servicio  => ('Servicio', ColoresApp.primary),
      TipoItem.producto  => ('Producto', ColoresApp.accentTeal),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
