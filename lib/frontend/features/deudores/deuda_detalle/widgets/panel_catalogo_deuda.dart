import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../share/share.dart';
import '../../../categorias/widgets/panel_categorias_catalogo.dart';
import '../modelo/deuda_editor_state.dart';
import '../provider/catalogo_deuda_providers.dart';
import '../provider/deuda_editor_provider.dart';
import 'grilla_productos_deuda.dart';
import 'panel_pagos_deuda.dart';

/// Panel izquierdo de la ficha: qué se fía y qué se cobra.
///
/// Es el mismo punto de venta de cotizaciones, órdenes y reservas, con **dos**
/// opciones: una deuda solo lleva repuestos. La segunda no es otra clase de
/// línea sino la otra mitad del trabajo —el dinero—, y comparte sitio porque
/// fiar y abonar son el mismo momento en el mostrador: el cliente se lleva la
/// moto arreglada y deja algo a cuenta sin moverse de ahí.
class PanelCatalogoDeuda extends ConsumerWidget {
  const PanelCatalogoDeuda({
    super.key,
    required this.deudaId,
    required this.focoBusqueda,
  });

  final int deudaId;
  final FocusNode focoBusqueda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vista = ref.watch(
      deudaEditorProvider(deudaId).select((s) => (
            panel: s.value?.seccionActiva ?? SeccionDeuda.productos,
            editable: s.value?.editable ?? false,
          )),
    );

    return Row(
      children: [
        // El panel de categorías se queda siempre, apagado cuando no aplica:
        // hacerlo desaparecer al pasar a Abonos correría la mitad de la
        // pantalla 208 px a la izquierda en cada cambio.
        _PanelCategorias(
          deudaId: deudaId,
          habilitado: vista.panel == SeccionDeuda.productos,
        ),
        Expanded(
          child: vista.panel == SeccionDeuda.abonos
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Barra(
                      deudaId: deudaId,
                      focoBusqueda: focoBusqueda,
                      panel: vista.panel,
                    ),
                    Expanded(child: PanelPagosDeuda(deudaId: deudaId)),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Barra(
                        deudaId: deudaId,
                        focoBusqueda: focoBusqueda,
                        panel: vista.panel,
                        conPadding: false,
                      ),
                      if (!vista.editable) ...[
                        const SizedBox(height: 12),
                        const _AvisoCerrada(),
                      ],
                      const SizedBox(height: 16),
                      Expanded(
                        child: GrillaProductosDeuda(
                          deudaId: deudaId,
                          habilitado: vista.editable,
                        ),
                      ),
                      _Paginador(deudaId: deudaId),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// Selector de panel y buscador.
class _Barra extends ConsumerStatefulWidget {
  const _Barra({
    required this.deudaId,
    required this.focoBusqueda,
    required this.panel,
    this.conPadding = true,
  });

  final int deudaId;
  final FocusNode focoBusqueda;
  final SeccionDeuda panel;
  final bool conPadding;

  @override
  ConsumerState<_Barra> createState() => _BarraState();
}

class _BarraState extends ConsumerState<_Barra> {
  final _busqueda = TextEditingController();

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  DeudaEditorNotifier get _notifier =>
      ref.read(deudaEditorProvider(widget.deudaId).notifier);

  /// Pasar a Abonos limpia la búsqueda: al volver, el catálogo entero es un
  /// punto de partida más honesto que el filtro que se dejó puesto antes.
  void _cambiarSeccion(SeccionDeuda panel) {
    _busqueda.clear();
    _notifier
      ..buscarEnCatalogo('')
      ..cambiarSeccion(panel);
  }

  /// Cada panel con su ícono: leerlos es más rápido que leer dos etiquetas.
  static IconData _iconoDe(SeccionDeuda panel) => switch (panel) {
        SeccionDeuda.productos => Icons.inventory_2_outlined,
        SeccionDeuda.abonos => Icons.savings_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.conPadding
          ? const EdgeInsets.fromLTRB(24, 20, 24, 0)
          : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GrupoRadio<SeccionDeuda>(
            etiqueta: 'Qué hacer',
            valor: widget.panel,
            opciones: SeccionDeuda.values,
            constructorEtiqueta: (p) => p.etiqueta,
            constructorIcono: _iconoDe,
            alCambiar: _cambiarSeccion,
          ),
          // El buscador solo tiene sentido sobre el catálogo: en Abonos no hay
          // nada que buscar, y dejarlo encendido invita a teclear en balde.
          if (widget.panel == SeccionDeuda.productos) ...[
            const SizedBox(height: 14),
            BarraBusqueda(
              controlador: _busqueda,
              focoTeclado: widget.focoBusqueda,
              placeholder: 'Buscar repuesto por nombre o SKU...',
              alCambiar: _notifier.buscarEnCatalogo,
            ),
          ],
        ],
      ),
    );
  }
}

/// Por qué el panel está apagado.
class _AvisoCerrada extends StatelessWidget {
  const _AvisoCerrada();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ColoresApp.statusWarningBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline_rounded,
              size: 15, color: ColoresApp.statusWarning),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'La deuda está cerrada: no admite más repuestos.',
              style: TipografiaApp.caption,
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel de categorías del catálogo, con el filtro de la ficha.
class _PanelCategorias extends ConsumerWidget {
  const _PanelCategorias({required this.deudaId, required this.habilitado});

  final int deudaId;
  final bool habilitado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriaId = ref.watch(
      deudaEditorProvider(deudaId).select((s) => s.value?.categoriaId),
    );

    return PanelCategoriasCatalogo(
      seleccionada: categoriaId,
      habilitado: habilitado,
      alSeleccionar:
          ref.read(deudaEditorProvider(deudaId).notifier).filtrarPorCategoria,
    );
  }
}

/// Paginador de la rejilla de productos.
class _Paginador extends ConsumerWidget {
  const _Paginador({required this.deudaId});

  final int deudaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalPaginas = ref.watch(totalPaginasDeudaProvider(deudaId));
    final actual = ref.watch(
      deudaEditorProvider(deudaId).select((s) => s.value?.paginaCatalogo ?? 0),
    );
    final total = ref.watch(
      paginaProductosDeudaProvider(deudaId).select((p) => p.value?.total ?? 0),
    );

    // Con una sola página el paginador no dice nada que no se vea.
    if (totalPaginas <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: PaginacionWidget(
        paginaActual: actual,
        totalPaginas: totalPaginas,
        totalItems: total,
        itemsPorPagina: DeudaEditorState.tamanoPaginaCatalogo,
        alCambiarPagina:
            ref.read(deudaEditorProvider(deudaId).notifier).irAPaginaCatalogo,
      ),
    );
  }
}
