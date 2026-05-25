import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../backend/features/ventas/facturas/enum/enum_facturas.dart';
import '../../../../../share/temas/colores_app.dart';
import '../../provider/facturas_provider.dart';
import '../helpers/formateadores_factura.dart';
import 'detalle_shared_widgets_factura.dart';

class FacturaInfoCard extends ConsumerWidget {
  const FacturaInfoCard({super.key, required this.facturaId});
  final int facturaId;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SeccionHeaderFactura(
            titulo: 'Información de la factura',
            icono: Icons.receipt_long_outlined,
          ),
          Wrap(
            children: [
              SizedBox(
                width: 200,
                child: InfoCellFac(
                  etiqueta: 'Cliente',
                  valor: detalle.clienteNombre,
                ),
              ),
              if (detalle.tipo == TipoVenta.servicio && detalle.numeroOrden != null)
                SizedBox(
                  width: 180,
                  child: InfoCellFac(
                    etiqueta: 'Orden vinculada',
                    valor: '',
                    valorWidget: Text(
                      detalle.numeroOrden!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ColoresApp.primary,
                      ),
                    ),
                  ),
                ),
              SizedBox(
                width: 160,
                child: InfoCellFac(
                  etiqueta: 'Tipo',
                  valor: '',
                  valorWidget: _BadgeTipo(tipo: detalle.tipo),
                ),
              ),
              SizedBox(
                width: 160,
                child: InfoCellFac(
                  etiqueta: 'Método de pago',
                  valor: detalle.metodoPago.etiqueta,
                ),
              ),
              SizedBox(
                width: 160,
                child: InfoCellFac(
                  etiqueta: 'Fecha',
                  valor: fmtFechaCorta(detalle.creadoEn),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgeTipo extends StatelessWidget {
  const _BadgeTipo({required this.tipo});
  final TipoVenta tipo;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (tipo) {
      TipoVenta.servicio  => ('Servicio', ColoresApp.primary),
      TipoVenta.mostrador => ('Mostrador', ColoresApp.accentTeal),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
