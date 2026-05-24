import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../share/temas/colores_app.dart';
import '../../provider/ordenes_provider.dart';
import '../helpers/formateadores.dart';
import 'detalle_shared_widgets.dart';

class ResumenOrdenPanel extends ConsumerWidget {
  const ResumenOrdenPanel({super.key, required this.ordenId});
  final int ordenId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalle = ref.watch(
      ordenDetalleProvider(ordenId).select((a) => a.value),
    );
    if (detalle == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 20, 20, 20),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SeccionHeader(
            titulo: 'Resumen de la orden',
            icono: Icons.receipt_long_outlined,
          ),
          if (detalle.tareas.isNotEmpty)
            _ResumenBloque(
              titulo: 'Mano de obra',
              items: detalle.tareas
                  .map((t) => _ResumenItem(t.servicioNombre, t.precioPactado))
                  .toList(),
            ),
          if (detalle.repuestos.isNotEmpty)
            _ResumenBloque(
              titulo: 'Repuestos',
              items: detalle.repuestos
                  .map((r) => _ResumenItem(
                        '${r.productoNombre} ×${r.cantidad % 1 == 0 ? r.cantidad.toInt() : r.cantidad}',
                        r.subtotal,
                      ))
                  .toList(),
            ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Column(
              children: [
                _FilaTotal('Subtotal M.O.', detalle.subtotalManoObra, false),
                const SizedBox(height: 6),
                _FilaTotal(
                    'Subtotal repuestos', detalle.subtotalRepuestos, false),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: Color(0xFFE5E7EB)),
                ),
                _FilaTotal('TOTAL ESTIMADO', detalle.totalEstimado, true),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.receipt_rounded, size: 16),
                  label: const Text('Generar factura'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColoresApp.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        ColoresApp.primary.withValues(alpha: 0.4),
                    disabledForegroundColor: Colors.white70,
                    minimumSize: const Size.fromHeight(40),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Próximamente',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: ColoresApp.textLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumenItem {
  const _ResumenItem(this.label, this.valor);
  final String label;
  final double valor;
}

class _ResumenBloque extends StatelessWidget {
  const _ResumenBloque({required this.titulo, required this.items});
  final String titulo;
  final List<_ResumenItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
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
                        fontSize: 12.5,
                        color: ColoresApp.textMedium,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    fmtMoneda(i.valor),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: ColoresApp.textDark,
                    ),
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
  const _FilaTotal(this.etiqueta, this.valor, this.esTotal);
  final String etiqueta;
  final double valor;
  final bool esTotal;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            etiqueta,
            style: TextStyle(
              fontSize: esTotal ? 14 : 12.5,
              fontWeight: esTotal ? FontWeight.w700 : FontWeight.w500,
              color: esTotal ? ColoresApp.textDark : ColoresApp.textMedium,
            ),
          ),
        ),
        Text(
          fmtMoneda(valor),
          style: TextStyle(
            fontSize: esTotal ? 16 : 13,
            fontWeight: FontWeight.w700,
            color: esTotal ? ColoresApp.primary : ColoresApp.textDark,
          ),
        ),
      ],
    );
  }
}
