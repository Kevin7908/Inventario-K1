import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/cotizaciones/enum/enum_cotizacion.dart';
import '../../../../share/share.dart';
import '../../../categorias/widgets/panel_categorias_catalogo.dart';
import '../modelo/cotizacion_editor_state.dart';
import '../provider/catalogo_cotizacion_providers.dart';
import '../provider/cotizacion_editor_provider.dart';
import 'grilla_productos_cotizacion.dart';
import 'linea_libre_form.dart';
import 'tabla_servicios_cotizacion.dart';

/// Panel izquierdo del editor: de dónde salen las líneas de la cotización.
///
/// Es el punto de venta aplicado a una cotización: panel de categorías a la
/// izquierda —el mismo colapsable de Productos— y rejilla de tarjetas con
/// foto, igual que el POS del diseño.
///
/// El selector de tipo es lo único que cambia entre los tres casos, y estar a
/// la vista desde el principio deja ver que también se puede cotizar mano de
/// obra: por eso son tres radios y no un desplegable, que escondía dos de las
/// tres opciones detrás de un clic. Los servicios van en filas y no en
/// tarjetas porque no tienen foto ni categoría: una rejilla de cuadros vacíos
/// no aportaría nada.
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
        // El panel se queda siempre, apagado cuando el filtro no aplica.
        // Hacerlo desaparecer con los servicios y la línea libre corría la
        // rejilla entera 208 px a la izquierda en cada cambio de tipo.
        _PanelCategorias(
          cotizacionId: cotizacionId,
          habilitado: tipo == TipoItemCotizacion.producto,
        ),
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

  /// Cada tipo con su ícono: leerlos es más rápido que leer tres etiquetas.
  static IconData _iconoDe(TipoItemCotizacion tipo) => switch (tipo) {
        TipoItemCotizacion.producto => Icons.inventory_2_outlined,
        TipoItemCotizacion.servicio => Icons.build_outlined,
        TipoItemCotizacion.libre => Icons.edit_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final hayBuscador = widget.tipo != TipoItemCotizacion.libre;

    // Radio arriba y buscador debajo, en vez de lado a lado: las tres
    // pastillas no dejan ancho útil para el buscador en la misma fila.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GrupoRadio<TipoItemCotizacion>(
          etiqueta: 'Qué agregar',
          valor: widget.tipo,
          opciones: TipoItemCotizacion.values,
          constructorEtiqueta: (t) => t.etiqueta,
          constructorIcono: _iconoDe,
          alCambiar: _cambiarTipo,
        ),
        if (hayBuscador) ...[
          const SizedBox(height: 14),
          BarraBusqueda(
            controlador: _busqueda,
            focoTeclado: widget.focoBusqueda,
            placeholder: widget.tipo == TipoItemCotizacion.producto
                ? 'Buscar producto por nombre o SKU...'
                : 'Buscar servicio...',
            alCambiar: _notifier.buscarEnCatalogo,
          ),
        ],
      ],
    );
  }
}

/// El panel de categorías, atado al filtro del editor.
///
/// Es un `Consumer` propio y no un `ref.watch` en el panel entero para que
/// elegir una categoría no reconstruya la barra ni la rejilla: cada uno
/// observa lo suyo (§3).
class _PanelCategorias extends ConsumerWidget {
  const _PanelCategorias({
    required this.cotizacionId,
    required this.habilitado,
  });

  final int? cotizacionId;
  final bool habilitado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PanelCategoriasCatalogo(
      seleccionada: ref.watch(
        cotizacionEditorProvider(cotizacionId)
            .select((s) => s.value?.categoriaId),
      ),
      alSeleccionar: (id) => ref
          .read(cotizacionEditorProvider(cotizacionId).notifier)
          .filtrarPorCategoria(id),
      habilitado: habilitado,
    );
  }
}
