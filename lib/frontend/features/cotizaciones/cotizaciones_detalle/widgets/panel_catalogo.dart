import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/cotizaciones/enum/enum_cotizacion.dart';
import '../../../../share2/share2.dart';
import '../modelo/cotizacion_editor_state.dart';
import '../provider/catalogo_cotizacion_providers.dart';
import '../provider/cotizacion_editor_provider.dart';
import 'grilla_productos_cotizacion.dart';
import 'linea_libre_form.dart';
import 'panel_categorias_cotizacion.dart';
import 'tabla_servicios_cotizacion.dart';

/// Panel izquierdo del editor: de dónde salen las líneas de la cotización.
///
/// Es el punto de venta aplicado a una cotización: panel de categorías a la
/// izquierda —el mismo colapsable de Productos— y rejilla de tarjetas con
/// foto, igual que el POS del diseño.
///
/// El selector de tipo es lo único que cambia entre los tres casos, y estar a
/// la vista desde el principio deja ver que también se puede cotizar mano de
/// obra. Los servicios van en filas y no en tarjetas porque no tienen foto ni
/// categoría: una rejilla de cuadros vacíos no aportaría nada.
class PanelCatalogo extends ConsumerWidget {
  const PanelCatalogo({
    super.key,
    required this.cotizacionId,
    required this.focoBusqueda,
  });

  final int? cotizacionId;
  final FocusNode focoBusqueda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tipo = ref.watch(
      cotizacionEditorProvider(cotizacionId)
          .select((s) => s.value?.tipoActivo ?? TipoItemCotizacion.producto),
    );

    return Row(
      children: [
        // El panel de categorías solo aparece con productos: ni los servicios
        // ni las líneas libres están categorizados.
        if (tipo == TipoItemCotizacion.producto)
          PanelCategoriasCotizacion(cotizacionId: cotizacionId),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Barra(
                  cotizacionId: cotizacionId,
                  focoBusqueda: focoBusqueda,
                  tipo: tipo,
                ),
                const SizedBox(height: 16),
                // Sin botón de alta de producto: el catálogo se administra
                // desde su propia pantalla, no desde una cotización.
                Expanded(child: _contenido(context, ref, tipo)),
                // Solo los productos vienen paginados: servicios y línea libre
                // no pasan por el repositorio de productos.
                if (tipo == TipoItemCotizacion.producto)
                  _Paginador(cotizacionId: cotizacionId),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _contenido(
    BuildContext context,
    WidgetRef ref,
    TipoItemCotizacion tipo,
  ) =>
      switch (tipo) {
        TipoItemCotizacion.producto =>
          GrillaProductosCotizacion(cotizacionId: cotizacionId),
        TipoItemCotizacion.servicio =>
          TablaServiciosCotizacion(cotizacionId: cotizacionId),
        TipoItemCotizacion.libre => LineaLibreForm(
            alAgregar: (descripcion, precio) => ref
                .read(cotizacionEditorProvider(cotizacionId).notifier)
                .agregarLibre(descripcion: descripcion, precio: precio),
          ),
      };
}

/// Paginador de la rejilla de productos.
///
/// Observa solo el total y la página actual, así que pasar de página no lo
/// reconstruye por lo que se esté escribiendo ni por las líneas agregadas.
class _Paginador extends ConsumerWidget {
  const _Paginador({required this.cotizacionId});

  final int? cotizacionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalPaginas = ref.watch(totalPaginasCotizacionProvider(cotizacionId));
    final actual = ref.watch(
      cotizacionEditorProvider(cotizacionId)
          .select((s) => s.value?.paginaCatalogo ?? 0),
    );
    final total = ref.watch(
      paginaProductosCotizacionProvider(cotizacionId)
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
        itemsPorPagina: CotizacionEditorState.tamanoPaginaCatalogo,
        alCambiarPagina: ref
            .read(cotizacionEditorProvider(cotizacionId).notifier)
            .irAPaginaCatalogo,
      ),
    );
  }
}

/// Selector de tipo y buscador.
///
/// Es `Stateful` por el `TextEditingController` del buscador, que hay que
/// vaciar al cambiar de tipo: el texto que filtra productos no significa nada
/// en la lista de servicios.
class _Barra extends ConsumerStatefulWidget {
  const _Barra({
    required this.cotizacionId,
    required this.focoBusqueda,
    required this.tipo,
  });

  final int? cotizacionId;
  final FocusNode focoBusqueda;
  final TipoItemCotizacion tipo;

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

  CotizacionEditorNotifier get _notifier =>
      ref.read(cotizacionEditorProvider(widget.cotizacionId).notifier);

  void _cambiarTipo(TipoItemCotizacion tipo) {
    _busqueda.clear();
    _notifier.cambiarTipo(tipo);
  }

  @override
  Widget build(BuildContext context) {
    final hayBuscador = widget.tipo != TipoItemCotizacion.libre;

    return Row(
      children: [
        SizedBox(
          width: 190,
          child: SelectorWidget<TipoItemCotizacion>(
            etiqueta: 'Qué agregar',
            valor: widget.tipo,
            opciones: TipoItemCotizacion.values,
            constructorEtiqueta: (t) => t.etiqueta,
            alCambiar: _cambiarTipo,
          ),
        ),
        const SizedBox(width: 16),
        if (hayBuscador)
          Expanded(
            child: Padding(
              // Alinea con el input del selector, que lleva etiqueta encima.
              padding: const EdgeInsets.only(top: 22),
              child: BarraBusqueda(
                controlador: _busqueda,
                focoTeclado: widget.focoBusqueda,
                placeholder: widget.tipo == TipoItemCotizacion.producto
                    ? 'Buscar producto por nombre o SKU...'
                    : 'Buscar servicio...',
                alCambiar: _notifier.buscarEnCatalogo,
              ),
            ),
          )
        else
          const Spacer(),
      ],
    );
  }
}
