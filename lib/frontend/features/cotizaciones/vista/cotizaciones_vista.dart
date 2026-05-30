import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';
import 'package:inventario_k1/frontend/share/widgets/dialogos/dialogo_confirmar_eliminar_widget.dart';
import 'package:inventario_k1/frontend/share/widgets/output/estado_error_widget.dart';
import 'package:inventario_k1/frontend/share/widgets/output/estado_vacio_widget.dart';
import 'package:inventario_k1/frontend/share/widgets/output/snack_bar_mensaje.dart';
import 'package:inventario_k1/frontend/share/widgets/paginacion_widget.dart';
import 'package:inventario_k1/frontend/share/widgets/top_bar_widget.dart';

import '../../../../backend/features/cotizaciones/modelo/cotizacion_resumen.dart';
import '../provider/cotizaciones_provider.dart';
import '../widgets/dialogo/dialogo_cotizacion.dart';
import '../widgets/panel/panel_detalle_cotizacion.dart';
import '../widgets/tabla/cotizacion_fila_widget.dart';
import '../widgets/tabla/resumen_cards_cotizacion.dart';
import '../widgets/tabla/seccion_filtros_cot.dart';

class CotizacionesVista extends ConsumerStatefulWidget {
  const CotizacionesVista({super.key});

  @override
  ConsumerState<CotizacionesVista> createState() => _CotizacionesVistaState();
}

class _CotizacionesVistaState extends ConsumerState<CotizacionesVista> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onBuscar(String valor) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      ref.read(cotizacionesProvider.notifier).buscar(valor);
    });
  }

  void _abrirNueva() => DialogoCotizacion.mostrar(context);

  Future<void> _abrirEditar(CotizacionResumen cot) async {
    final detalle = await ref
        .read(repositorioCotizacionesProvider)
        .obtenerDetalle(cot.id);
    if (!mounted) return;
    DialogoCotizacion.mostrar(context, cotizacion: cot, detalle: detalle);
  }

  void _confirmarEliminar(CotizacionResumen cot) {
    DialogoConfirmarEliminar.mostrar(
      context: context,
      nombreElemento: cot.numero,
      tipoElemento: 'cotización',
      onConfirmar: () async {
        final error =
            await ref.read(cotizacionesProvider.notifier).eliminar(cot.id);
        if (!mounted) return;
        if (error != null) {
          SnackBarMensaje.error(context, error);
        } else {
          SnackBarMensaje.success(context, 'Cotización eliminada.');
          // Si era la seleccionada, cierra el panel
          if (ref.read(cotSeleccionadaIdProvider) == cot.id) {
            ref.read(cotSeleccionadaIdProvider.notifier).state = null;
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Derivar la cotización seleccionada desde el provider (sin ValueNotifier)
    final selId = ref.watch(cotSeleccionadaIdProvider);
    final selCot = ref.watch(cotizacionesProvider).value?.cotizaciones
        .where((c) => c.id == selId)
        .firstOrNull;

    return Scaffold(
      backgroundColor: ColoresApp.bgContent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TopBarConBoton(
            titulo: 'Cotizaciones',
            etiquetaBoton: 'Nueva Cotización',
            alPresionarBoton: _abrirNueva,
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Contenido principal ──────────────────────────────
                Expanded(
                  child: _CuerpoCotizaciones(
                    onBuscar: _onBuscar,
                    onEditar: _abrirEditar,
                    onEliminar: _confirmarEliminar,
                  ),
                ),

                // ── Panel lateral con OverflowBox para evitar layout jank ──
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeInOut,
                  width: selCot != null ? 390.0 : 0.0,
                  child: OverflowBox(
                    maxWidth: 390.0,
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 390.0,
                      child: selCot != null
                          ? PanelDetalleCotizacion(
                              cotizacion: selCot,
                              onCerrar: () => ref
                                  .read(cotSeleccionadaIdProvider.notifier)
                                  .state = null,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cuerpo principal ──────────────────────────────────────────────────────────

class _CuerpoCotizaciones extends ConsumerWidget {
  const _CuerpoCotizaciones({
    required this.onBuscar,
    required this.onEditar,
    required this.onEliminar,
  });

  final ValueChanged<String> onBuscar;
  final ValueChanged<CotizacionResumen> onEditar;
  final ValueChanged<CotizacionResumen> onEliminar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estadoAsync = ref.watch(cotizacionesProvider);
    final selId = ref.watch(cotSeleccionadaIdProvider);

    return estadoAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: ColoresApp.primary),
      ),
      error: (e, _) => EstadoErrorWidget(
        mensaje: e.toString(),
        alReintentar: () => ref.invalidate(cotizacionesProvider),
      ),
      data: (estado) {
        final paginadas = estado.paginadas;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ResumenCardsCotizacion(estado: estado),
              const SizedBox(height: 20),

              SeccionFiltrosCot(
                filtroEstado: estado.filtroEstado,
                filtroMes: estado.filtroMes,
                onBuscar: onBuscar,
                onFiltroEstado: (e) =>
                    ref.read(cotizacionesProvider.notifier).filtrarEstado(e),
                onFiltroMes: (m) =>
                    ref.read(cotizacionesProvider.notifier).filtrarMes(m),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: ColoresApp.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: ColoresApp.shadow,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CotizacionTablaEncabezado(),
                      Expanded(
                        child: paginadas.isEmpty
                            ? const EstadoVacioWidget(
                                icono: Icons.description_outlined,
                                textoSinDatos: 'Sin cotizaciones',
                                textoSinResultados:
                                    'No hay cotizaciones que coincidan.',
                                textoCTA: '',
                              )
                            : ListView.separated(
                                itemCount: paginadas.length,
                                separatorBuilder: (_, __) => const Divider(
                                  height: 1,
                                  color: ColoresApp.border,
                                ),
                                itemBuilder: (_, i) {
                                  final cot = paginadas[i];
                                  return CotizacionFilaWidget(
                                    key: ValueKey(cot.id),
                                    cotizacion: cot,
                                    seleccionada: selId == cot.id,
                                    onTap: () => ref
                                        .read(cotSeleccionadaIdProvider.notifier)
                                        .state = selId == cot.id ? null : cot.id,
                                    onEditar: () => onEditar(cot),
                                    onEliminar: () => onEliminar(cot),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              PaginacionWidget(
                paginaActual: estado.paginaActual,
                totalPaginas: estado.totalPaginas,
                totalItems: estado.totalFiltradas,
                itemsPorPagina: CotizacionesState.itemsPorPagina,
                alCambiarPagina: (p) =>
                    ref.read(cotizacionesProvider.notifier).cambiarPagina(p),
                labelEntidad: 'cotizaciones',
              ),
            ],
          ),
        );
      },
    );
  }
}
