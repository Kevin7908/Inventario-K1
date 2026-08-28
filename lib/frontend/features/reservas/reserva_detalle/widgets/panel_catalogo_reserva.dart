import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../share2/share2.dart';
import '../../../categorias/widgets/panel_categorias_catalogo.dart';
import '../modelo/reserva_editor_state.dart';
import '../provider/catalogo_reserva_providers.dart';
import '../provider/reserva_editor_provider.dart';
import 'grilla_productos_reserva.dart';
import 'panel_abonos.dart';

/// Panel izquierdo del editor: qué se aparta y qué se cobra.
///
/// Es el mismo punto de venta de cotizaciones y órdenes, con **dos** opciones
/// en vez de tres: una reserva solo aparta productos. La segunda no es otra
/// clase de línea sino la otra mitad del trabajo —el dinero—, y comparte sitio
/// porque apartar y abonar son el mismo momento en el mostrador: el cliente
/// elige, se le da un total y entrega algo a cuenta sin moverse de ahí.
class PanelCatalogoReserva extends ConsumerWidget {
  const PanelCatalogoReserva({
    super.key,
    required this.reservaId,
    required this.focoBusqueda,
  });

  final int reservaId;
  final FocusNode focoBusqueda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vista = ref.watch(
      reservaEditorProvider(reservaId).select((s) => (
            panel: s.value?.seccionActiva ?? SeccionReserva.productos,
            editable: s.value?.editable ?? false,
          )),
    );

    return Row(
      children: [
        // El panel de categorías se queda siempre, apagado cuando no aplica:
        // hacerlo desaparecer al pasar a Abonos correría la mitad de la
        // pantalla 208 px a la izquierda en cada cambio.
        _PanelCategorias(
          reservaId: reservaId,
          habilitado: vista.panel == SeccionReserva.productos,
        ),
        Expanded(
          child: vista.panel == SeccionReserva.abonos
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Barra(
                      reservaId: reservaId,
                      focoBusqueda: focoBusqueda,
                      panel: vista.panel,
                    ),
                    Expanded(child: PanelAbonos(reservaId: reservaId)),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Barra(
                        reservaId: reservaId,
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
                        child: GrillaProductosReserva(
                          reservaId: reservaId,
                          habilitado: vista.editable,
                        ),
                      ),
                      _Paginador(reservaId: reservaId),
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
    required this.reservaId,
    required this.focoBusqueda,
    required this.panel,
    this.conPadding = true,
  });

  final int reservaId;
  final FocusNode focoBusqueda;
  final SeccionReserva panel;
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

  ReservaEditorNotifier get _notifier =>
      ref.read(reservaEditorProvider(widget.reservaId).notifier);

  /// Pasar a Abonos limpia la búsqueda: al volver, el catálogo entero es un
  /// punto de partida más honesto que el filtro que se dejó puesto antes.
  void _cambiarSeccion(SeccionReserva panel) {
    _busqueda.clear();
    _notifier
      ..buscarEnCatalogo('')
      ..cambiarSeccion(panel);
  }

  /// Cada panel con su ícono: leerlos es más rápido que leer dos etiquetas.
  static IconData _iconoDe(SeccionReserva panel) => switch (panel) {
        SeccionReserva.productos => Icons.inventory_2_outlined,
        SeccionReserva.abonos => Icons.savings_outlined,
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
          GrupoRadio<SeccionReserva>(
            etiqueta: 'Qué hacer',
            valor: widget.panel,
            opciones: SeccionReserva.values,
            constructorEtiqueta: (p) => p.etiqueta,
            constructorIcono: _iconoDe,
            alCambiar: _cambiarSeccion,
          ),
          // El buscador solo tiene sentido sobre el catálogo: en Abonos no hay
          // nada que buscar, y dejarlo encendido invita a teclear en balde.
          if (widget.panel == SeccionReserva.productos) ...[
            const SizedBox(height: 14),
            BarraBusqueda(
              controlador: _busqueda,
              focoTeclado: widget.focoBusqueda,
              placeholder: 'Buscar producto por nombre o SKU...',
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
          Icon(Icons.lock_outline_rounded, size: 15,
              color: ColoresApp.statusWarning),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'La reserva está cerrada: no admite más productos.',
              style: TipografiaApp.caption,
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel de categorías del catálogo, con el filtro del editor.
class _PanelCategorias extends ConsumerWidget {
  const _PanelCategorias({required this.reservaId, required this.habilitado});

  final int reservaId;
  final bool habilitado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriaId = ref.watch(
      reservaEditorProvider(reservaId).select((s) => s.value?.categoriaId),
    );

    return PanelCategoriasCatalogo(
      seleccionada: categoriaId,
      habilitado: habilitado,
      alSeleccionar: ref
          .read(reservaEditorProvider(reservaId).notifier)
          .filtrarPorCategoria,
    );
  }
}

/// Paginador de la rejilla de productos.
class _Paginador extends ConsumerWidget {
  const _Paginador({required this.reservaId});

  final int reservaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalPaginas = ref.watch(totalPaginasReservaProvider(reservaId));
    final actual = ref.watch(
      reservaEditorProvider(reservaId)
          .select((s) => s.value?.paginaCatalogo ?? 0),
    );
    final total = ref.watch(
      paginaProductosReservaProvider(reservaId)
          .select((p) => p.value?.total ?? 0),
    );

    // Con una sola página el paginador no dice nada que no se vea.
    if (totalPaginas <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: PaginacionWidget(
        paginaActual: actual,
        totalPaginas: totalPaginas,
        totalItems: total,
        itemsPorPagina: ReservaEditorState.tamanoPaginaCatalogo,
        alCambiarPagina: ref
            .read(reservaEditorProvider(reservaId).notifier)
            .irAPaginaCatalogo,
      ),
    );
  }
}
