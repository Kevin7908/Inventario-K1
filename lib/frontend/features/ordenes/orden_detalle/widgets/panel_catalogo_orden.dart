import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../share2/share2.dart';
import '../modelo/linea_orden_editor.dart';
import '../modelo/orden_editor_state.dart';
import '../provider/catalogo_orden_providers.dart';
import '../provider/orden_editor_provider.dart';
import 'cargo_libre_form.dart';
import 'grilla_productos_orden.dart';
import 'panel_categorias_orden.dart';
import 'tabla_servicios_orden.dart';

/// Panel izquierdo del editor: de dónde salen las líneas de la orden.
///
/// Es el mismo punto de venta del editor de cotizaciones —panel de categorías
/// colapsable y rejilla de tarjetas con foto— con dos diferencias:
///
/// - el selector ofrece **Repuesto** primero, no Producto: al armar una orden
///   se empieza por las piezas mucho más a menudo que por la mano de obra;
/// - los servicios **se expanden en la fila** para pedir técnico y precio (ver
///   [TablaServiciosOrden]), en vez de saltar directo al panel derecho.
class PanelCatalogoOrden extends ConsumerWidget {
  const PanelCatalogoOrden({
    super.key,
    required this.ordenId,
    required this.focoBusqueda,
  });

  final int ordenId;
  final FocusNode focoBusqueda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vista = ref.watch(
      ordenEditorProvider(ordenId).select((s) => (
            tipo: s.value?.tipoActivo ?? TipoLineaOrden.repuesto,
            editable: s.value?.editable ?? false,
          )),
    );

    return Row(
      children: [
        // El panel se queda siempre, apagado cuando el filtro no aplica.
        // Hacerlo desaparecer con los servicios y el cargo corría la rejilla
        // entera 208 px a la izquierda en cada cambio de tipo.
        PanelCategoriasOrden(
          ordenId: ordenId,
          habilitado: vista.tipo == TipoLineaOrden.repuesto,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Barra(
                  ordenId: ordenId,
                  focoBusqueda: focoBusqueda,
                  tipo: vista.tipo,
                ),
                if (!vista.editable) ...[
                  const SizedBox(height: 12),
                  const _AvisoCerrada(),
                ],
                const SizedBox(height: 16),
                // Sin botón de alta de producto: el catálogo se administra
                // desde su propia pantalla, no desde una orden.
                Expanded(
                  child: _contenido(context, ref, vista.tipo, vista.editable),
                ),
                // Solo los repuestos vienen paginados: servicios y cargo suelto
                // no pasan por el repositorio de productos.
                if (vista.tipo == TipoLineaOrden.repuesto)
                  _Paginador(ordenId: ordenId),
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
    TipoLineaOrden tipo,
    bool editable,
  ) =>
      switch (tipo) {
        TipoLineaOrden.repuesto =>
          GrillaProductosOrden(ordenId: ordenId, habilitado: editable),
        TipoLineaOrden.servicio =>
          TablaServiciosOrden(ordenId: ordenId, habilitado: editable),
        TipoLineaOrden.cargo => CargoLibreForm(
            habilitado: editable,
            alAgregar: (descripcion, precio) => unawaited(
              ref.read(ordenEditorProvider(ordenId).notifier).agregarCargo(
                    descripcion: descripcion,
                    precio: precio,
                  ),
            ),
          ),
      };
}

/// Por qué el panel está apagado.
///
/// Una orden `ENTREGADA` o `ANULADA` no admite más tareas ni repuestos: lo
/// impide una guarda de la base (§3.4 de `REGLAS_BD.md`). Decirlo aquí evita
/// que alguien toque cinco tarjetas antes de entender que no pasa nada.
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
              'La orden está cerrada: no admite más líneas. Cámbiale el estado '
              'para volver a editarla.',
              style: TipografiaApp.caption,
            ),
          ),
        ],
      ),
    );
  }
}

/// Paginador de la rejilla de repuestos.
///
/// Observa solo el total y la página actual, así que pasar de página no lo
/// reconstruye por lo que se esté escribiendo ni por las líneas agregadas.
class _Paginador extends ConsumerWidget {
  const _Paginador({required this.ordenId});

  final int ordenId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalPaginas = ref.watch(totalPaginasOrdenProvider(ordenId));
    final actual = ref.watch(
      ordenEditorProvider(ordenId).select((s) => s.value?.paginaCatalogo ?? 0),
    );
    final total = ref.watch(
      paginaProductosOrdenProvider(ordenId).select((p) => p.value?.total ?? 0),
    );

    // Con una sola página el paginador no dice nada que no se vea.
    if (totalPaginas <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: PaginacionWidget(
        paginaActual: actual,
        totalPaginas: totalPaginas,
        totalItems: total,
        itemsPorPagina: OrdenEditorState.tamanoPaginaCatalogo,
        alCambiarPagina:
            ref.read(ordenEditorProvider(ordenId).notifier).irAPaginaCatalogo,
      ),
    );
  }
}

/// Selector de tipo y buscador.
///
/// Es `Stateful` por el `TextEditingController` del buscador, que hay que
/// vaciar al cambiar de tipo: el texto que filtra repuestos no significa nada
/// en la lista de servicios.
class _Barra extends ConsumerStatefulWidget {
  const _Barra({
    required this.ordenId,
    required this.focoBusqueda,
    required this.tipo,
  });

  final int ordenId;
  final FocusNode focoBusqueda;
  final TipoLineaOrden tipo;

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

  OrdenEditorNotifier get _notifier =>
      ref.read(ordenEditorProvider(widget.ordenId).notifier);

  void _cambiarTipo(TipoLineaOrden tipo) {
    _busqueda.clear();
    _notifier.cambiarTipo(tipo);
  }

  /// Cada tipo con su ícono: leerlos es más rápido que leer tres etiquetas.
  static IconData _iconoDe(TipoLineaOrden tipo) => switch (tipo) {
        TipoLineaOrden.repuesto => Icons.inventory_2_outlined,
        TipoLineaOrden.servicio => Icons.build_outlined,
        TipoLineaOrden.cargo => Icons.edit_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final hayBuscador = widget.tipo != TipoLineaOrden.cargo;

    // Radio arriba y buscador debajo, en vez de lado a lado: las tres
    // pastillas no dejan ancho útil para el buscador en la misma fila.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GrupoRadio<TipoLineaOrden>(
          etiqueta: 'Qué agregar',
          valor: widget.tipo,
          opciones: TipoLineaOrden.ordenCatalogo,
          constructorEtiqueta: (t) => t.etiqueta,
          constructorIcono: _iconoDe,
          alCambiar: _cambiarTipo,
        ),
        if (hayBuscador) ...[
          const SizedBox(height: 14),
          BarraBusqueda(
            controlador: _busqueda,
            focoTeclado: widget.focoBusqueda,
            placeholder: widget.tipo == TipoLineaOrden.repuesto
                ? 'Buscar repuesto por nombre o SKU...'
                : 'Buscar servicio...',
            alCambiar: _notifier.buscarEnCatalogo,
          ),
        ],
      ],
    );
  }
}
