import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/ventas/facturas/enum/enum_facturas.dart';
import '../../../../share2/feedback/dialogo_confirmacion.dart';
import '../../../../share/widgets/output/estado_error_widget.dart';
import '../../../../share/widgets/output/snack_bar_mensaje.dart';
import '../provider/facturas_provider.dart';
import '../widgets/dialogo_crear_factura.dart';
import 'widgets/factura_info_card.dart';
import 'widgets/factura_top_bar.dart';
import 'widgets/items_factura_lista_card.dart';
import 'widgets/resumen_factura_panel.dart';

class FacturaDetallePage extends ConsumerWidget {
  const FacturaDetallePage({super.key, required this.facturaId});
  final int facturaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalleAsync = ref.watch(facturaDetalleProvider(facturaId));

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: detalleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EstadoErrorWidget(
          mensaje: e.toString(),
          alReintentar: () => ref.invalidate(facturaDetalleProvider(facturaId)),
        ),
        data: (_) => _ContenidoDetalle(facturaId: facturaId),
      ),
    );
  }
}

class _ContenidoDetalle extends ConsumerWidget {
  const _ContenidoDetalle({required this.facturaId});
  final int facturaId;

  void _confirmarEliminar(BuildContext context, WidgetRef ref) {
    final detalle = ref.read(facturaDetalleProvider(facturaId)).value;
    if (detalle == null) return;

    // No se ofrece «eliminar»: una factura es un documento contable y solo se
    // anula.
    DialogoConfirmacion.mostrar(
      context,
      titulo: '¿Anular la factura ${detalle.numeroFactura}?',
      mensaje: 'Se devolverá al inventario lo que había salido. La factura no '
          'se borra: queda registrada como anulada.',
      textoConfirmar: 'Anular factura',
    ).then((confirmado) async {
      if (confirmado != true) return;
      final error = await ref.read(facturasProvider.notifier).anular(detalle.id);
      if (!context.mounted) return;
      if (error != null) {
        SnackBarMensaje.error(context, error);
      } else {
        Navigator.of(context).pop();
        SnackBarMensaje.success(context, 'Factura anulada.');
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalle = ref.watch(facturaDetalleProvider(facturaId)).value;
    if (detalle == null) return const SizedBox.shrink();

    final readOnly = detalle.estadoPago == EstadoPago.pagado;

    return Column(
      children: [
        FacturaTopBar(
          facturaId: facturaId,
          readOnly:  readOnly,
          onVolver: () => Navigator.of(context).pop(),
          onEditar: () async {
            await DialogoCrearFactura.mostrar(context, facturaAEditar: detalle);
            if (context.mounted) {
              ref.invalidate(facturaDetalleProvider(facturaId));
            }
          },
          onEliminar: () => _confirmarEliminar(context, ref),
        ),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Columna izquierda — scrollable
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FacturaInfoCard(facturaId: facturaId),
                      const SizedBox(height: 14),
                      ItemsFacturaListaCard(
                        facturaId: facturaId,
                        readOnly:  readOnly,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              // Panel lateral fijo
              SizedBox(
                width: 300,
                child: ResumenFacturaPanel(facturaId: facturaId),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
