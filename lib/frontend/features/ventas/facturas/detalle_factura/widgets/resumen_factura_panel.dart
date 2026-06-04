import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../share/formateadores/moneda_formateador.dart';
import '../../../../../share/temas/colores_app.dart';
import '../../provider/facturas_provider.dart';
import 'detalle_shared_widgets_factura.dart';

class ResumenFacturaPanel extends ConsumerWidget {
  const ResumenFacturaPanel({super.key, required this.facturaId});
  final int facturaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalle = ref.watch(
      facturaDetalleProvider(facturaId).select((a) => a.value),
    );
    if (detalle == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 20, 20, 20),
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
          const SeccionHeaderFactura(
            titulo: 'Resumen de la factura',
            icono: Icons.receipt_long_outlined,
          ),

          if (detalle.itemsServicio.isNotEmpty)
            _ResumenBloque(
              titulo: 'Servicios',
              items: detalle.itemsServicio
                  .map((i) => _Item(i.descripcion, i.subtotal))
                  .toList(),
            ),

          if (detalle.itemsProducto.isNotEmpty)
            _ResumenBloque(
              titulo: 'Productos',
              items: detalle.itemsProducto
                  .map((i) => _Item(
                        '${i.descripcion} x${i.cantidad % 1 == 0 ? i.cantidad.toInt() : i.cantidad}',
                        i.subtotal,
                      ))
                  .toList(),
            ),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: ColoresApp.border)),
            ),
            child: Column(
              children: [
                _FilaTotal('Subtotal', detalle.subtotal, false),
                if (detalle.descuento > 0) ...[
                  const SizedBox(height: 6),
                  _FilaTotal('Descuento', -detalle.descuento, false,
                      color: ColoresApp.accentGreen),
                ],
                if (detalle.iva > 0) ...[
                  const SizedBox(height: 6),
                  _FilaTotal('IVA', detalle.iva, false),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: ColoresApp.border),
                ),
                _FilaTotal('TOTAL', detalle.total, true),
                if (detalle.totalPagado > 0 && detalle.totalPagado < detalle.total) ...[
                  const SizedBox(height: 8),
                  _FilaTotal('Pagado', detalle.totalPagado, false),
                  const SizedBox(height: 4),
                  _FilaTotal('Saldo pendiente', detalle.saldoPendiente, false,
                      color: ColoresApp.statusPending),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Item {
  const _Item(this.label, this.valor);
  final String label;
  final double valor;
}

class _ResumenBloque extends StatelessWidget {
  const _ResumenBloque({required this.titulo, required this.items});
  final String titulo;
  final List<_Item> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ColoresApp.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: ColoresApp.textLight,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      i.label,
                      style: const TextStyle(
                          fontSize: 12.5, color: ColoresApp.textMedium),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    fmtMoneda(i.valor),
                    style: const TextStyle(
                        fontSize: 12.5, color: ColoresApp.textDark),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaTotal extends StatelessWidget {
  const _FilaTotal(this.etiqueta, this.valor, this.esTotal, {this.color});
  final String etiqueta;
  final double valor;
  final bool esTotal;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final valorColor = color ??
        (esTotal ? ColoresApp.primary : ColoresApp.textDark);
    return Row(
      children: [
        Expanded(
          child: Text(
            etiqueta,
            style: TextStyle(
              fontSize: esTotal ? 14 : 12.5,
              fontWeight:
                  esTotal ? FontWeight.w700 : FontWeight.w500,
              color: esTotal ? ColoresApp.textDark : ColoresApp.textMedium,
            ),
          ),
        ),
        Text(
          fmtMoneda(valor),
          style: TextStyle(
            fontSize: esTotal ? 16 : 13,
            fontWeight: FontWeight.w700,
            color: valorColor,
          ),
        ),
      ],
    );
  }
}
