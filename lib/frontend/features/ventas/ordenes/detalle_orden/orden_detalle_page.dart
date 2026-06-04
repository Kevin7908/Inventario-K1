import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/ventas/ordenes/enum/enum_ordenes.dart';
import '../../../../share/widgets/dialogos/dialogo_confirmar_eliminar_widget.dart';
import '../../../../share/widgets/output/estado_error_widget.dart';
import '../../../../share/widgets/output/snack_bar_mensaje.dart';
import '../provider/ordenes_provider.dart';
import '../widgets/dialogo_crear_editar_orden.dart';
import 'widgets/cards/diagnostico_card.dart';
import 'widgets/cards/info_moto_card.dart';
import 'widgets/cards/repuestos_lista_card.dart';
import 'widgets/cards/tareas_lista_card.dart';
import 'widgets/detalle_top_bar.dart';
import 'widgets/panel_busqueda_inventario.dart';
import 'widgets/resumen_orden_panel.dart';

// Punto de entrada público — carga el detalle y gestiona los estados async.
class OrdenDetalleVista extends ConsumerWidget {
  const OrdenDetalleVista({super.key, required this.ordenId});
  final int ordenId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalleAsync = ref.watch(ordenDetalleProvider(ordenId));

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: detalleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EstadoErrorWidget(
          mensaje: e.toString(),
          alReintentar: () => ref.invalidate(ordenDetalleProvider(ordenId)),
        ),
        data: (_) => _ContenidoDetalle(ordenId: ordenId),
      ),
    );
  }
}

// Layout principal: top-bar + dos columnas. Privado a este archivo.
class _ContenidoDetalle extends ConsumerWidget {
  const _ContenidoDetalle({required this.ordenId});
  final int ordenId;

  Future<void> _cambiarEstado(
      BuildContext context, WidgetRef ref, EstadoOrden nuevo) async {
    final detalle = ref.read(ordenDetalleProvider(ordenId)).value;
    if (detalle == null) return;

    final error = await ref.read(ordenesProvider.notifier).actualizarOrden(
          detalle.id,
          estado:              nuevo,
          kilometrajeEntrada:  detalle.kilometrajeEntrada,
          diagnostico:         detalle.diagnosticoCliente,
          observaciones:       detalle.observacionesMecanico,
        );

    if (!context.mounted) return;
    if (error != null) {
      SnackBarMensaje.error(context, error);
    } else {
      ref.invalidate(ordenDetalleProvider(ordenId));
    }
  }

  void _confirmarEliminar(BuildContext context, WidgetRef ref) {
    final detalle = ref.read(ordenDetalleProvider(ordenId)).value;
    if (detalle == null) return;

    DialogoConfirmarEliminar.mostrar(
      context: context,
      nombreElemento: detalle.numeroOrden,
      tipoElemento: 'orden',
      onConfirmar: () async {
        final error =
            await ref.read(ordenesProvider.notifier).eliminar(detalle.id);
        if (!context.mounted) return;
        if (error != null) {
          SnackBarMensaje.error(context, error);
        } else {
          Navigator.of(context).pop();
          SnackBarMensaje.success(context, 'Orden eliminada.');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Leemos una sola vez para pasar al diálogo de edición
    final detalle = ref.watch(ordenDetalleProvider(ordenId)).value;
    if (detalle == null) return const SizedBox.shrink();

    return Column(
      children: [
        DetalleTopBar(
          ordenId:         ordenId,
          onVolver:        () => Navigator.of(context).pop(),
          onCambiarEstado: (nuevo) => _cambiarEstado(context, ref, nuevo),
          onEditar: () async {
            await DialogoCrearEditarOrden.mostrar(
                context, ordenAEditar: detalle);
            if (context.mounted) {
              ref.invalidate(ordenDetalleProvider(ordenId));
            }
          },
          onEliminar: () => _confirmarEliminar(context, ref),
        ),
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
                      InfoMotoCard(ordenId: ordenId),
                      const SizedBox(height: 14),
                      DiagnosticoCard(ordenId: ordenId),
                      const SizedBox(height: 14),
                      TareasListaCard(ordenId: ordenId),
                      const SizedBox(height: 14),
                      RepuestosListaCard(ordenId: ordenId),
                      const SizedBox(height: 14),
                      PanelBusquedaInventario(ordenId: ordenId),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              // Panel lateral fijo
              SizedBox(
                width: 320,
                child: ResumenOrdenPanel(ordenId: ordenId),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
