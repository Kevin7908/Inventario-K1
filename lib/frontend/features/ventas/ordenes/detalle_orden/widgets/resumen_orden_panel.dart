import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../backend/features/ventas/facturas/enum/enum_facturas.dart';
import '../../../../../../backend/features/ventas/facturas/modelo/factura_resumen.dart';
import '../../../../../share/temas/colores_app.dart';
import '../../../facturas/detalle_factura/factura_detalle_page.dart';
import '../../../facturas/provider/facturas_provider.dart';
import '../../../facturas/widgets/dialogo_crear_factura.dart';
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

    final facturaExistente = ref.watch(facturaDeOrdenProvider(ordenId));

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
          if (facturaExistente != null)
            _FacturaInfoBloque(factura: facturaExistente),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: facturaExistente != null
                ? Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FacturaDetallePage(
                                    facturaId: facturaExistente.id),
                              ),
                            );
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 14),
                          label: const Text('Ver factura'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ColoresApp.primary,
                            side: BorderSide(
                                color:
                                    ColoresApp.primary.withValues(alpha: 0.5)),
                            minimumSize: const Size(0, 38),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            textStyle: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await DialogoCrearFactura.mostrar(
                              context,
                              ordenId: ordenId,
                              clienteId: detalle.clienteId,
                              clienteNombre: detalle.clienteNombre,
                              facturaExistente: facturaExistente,
                            );
                          },
                          icon: const Icon(Icons.sync_rounded, size: 14),
                          label: const Text('Actualizar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColoresApp.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 38),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                            textStyle: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  )
                : ElevatedButton.icon(
                    onPressed: () async {
                      await DialogoCrearFactura.mostrar(
                        context,
                        ordenId: ordenId,
                        clienteId: detalle.clienteId,
                        clienteNombre: detalle.clienteNombre,
                        facturaExistente: null,
                      );
                    },
                    icon: const Icon(Icons.receipt_rounded, size: 16),
                    label: const Text('Generar factura'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColoresApp.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(40),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FacturaInfoBloque extends StatelessWidget {
  const _FacturaInfoBloque({required this.factura});
  final FacturaResumen factura;

  static const _estadoColor = {
    EstadoPago.pagado: Color(0xFF10B981),
    EstadoPago.pendiente: Color(0xFFF59E0B),
    EstadoPago.anulada: Color(0xFFEF4444),
  };

  @override
  Widget build(BuildContext context) {
    final estadoColor =
        _estadoColor[factura.estadoPago] ?? ColoresApp.textMedium;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_outlined,
                  size: 13, color: ColoresApp.textLight),
              const SizedBox(width: 5),
              Text(
                factura.numeroFactura,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ColoresApp.textDark,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: estadoColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  factura.estadoPago.etiqueta,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: estadoColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _InfoItem(
                  label: 'Método',
                  valor: factura.metodoPago.etiqueta,
                ),
              ),
              if (factura.iva > 0)
                Expanded(
                  child: _InfoItem(
                    label: 'IVA',
                    valor: fmtMoneda(factura.iva),
                  ),
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: Color(0xFFE5E7EB)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL FACTURA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: ColoresApp.textLight,
                ),
              ),
              Text(
                fmtMoneda(factura.total),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: ColoresApp.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.label, required this.valor});
  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: ColoresApp.textLight,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: ColoresApp.textDark,
          ),
        ),
      ],
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
