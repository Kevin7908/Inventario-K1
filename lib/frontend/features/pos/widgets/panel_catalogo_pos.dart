import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../share2/share2.dart';
import '../modelo/pos_state.dart';
import '../provider/pos_providers.dart';
import 'grilla_productos_pos.dart';
import 'panel_categorias_pos.dart';

/// Lado izquierdo del punto de venta: de dónde salen las líneas de la venta.
///
/// Título, buscador y rejilla, con el panel de categorías pegado al borde
/// izquierdo, como en Productos.
class PanelCatalogoPos extends StatelessWidget {
  const PanelCatalogoPos({super.key, required this.focoBusqueda});

  final FocusNode focoBusqueda;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const PanelCategoriasPos(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const EncabezadoPagina(
                  titulo: 'Punto de venta',
                  subtitulo:
                      'Agrega repuestos al carrito para registrar la venta',
                ),
                const SizedBox(height: 18),
                _Buscador(foco: focoBusqueda),
                const SizedBox(height: 18),
                const Expanded(child: GrillaProductosPos()),
                const _Paginador(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Paginador de la rejilla.
///
/// Observa solo el total de páginas y la página actual, así que cambiar de
/// página no lo reconstruye por el carrito ni por la búsqueda.
class _Paginador extends ConsumerWidget {
  const _Paginador();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalPaginas = ref.watch(totalPaginasPosProvider);
    final actual = ref.watch(posProvider.select((s) => s.pagina));
    final total = ref.watch(
      paginaProductosPosProvider.select((p) => p.value?.total ?? 0),
    );

    // Con una sola página el paginador no dice nada que no se vea.
    if (totalPaginas <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: PaginacionWidget(
        paginaActual: actual,
        totalPaginas: totalPaginas,
        totalItems: total,
        itemsPorPagina: PosState.tamanoPagina,
        alCambiarPagina: ref.read(posProvider.notifier).irAPagina,
      ),
    );
  }
}

/// Buscador de la rejilla.
///
/// Es `Stateful` solo por su `TextEditingController`; el texto que filtra vive
/// en el estado del punto de venta, que es de donde lo lee la rejilla.
class _Buscador extends ConsumerStatefulWidget {
  const _Buscador({required this.foco});

  final FocusNode foco;

  @override
  ConsumerState<_Buscador> createState() => _BuscadorState();
}

class _BuscadorState extends ConsumerState<_Buscador> {
  final _controlador = TextEditingController();

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BarraBusqueda(
      controlador: _controlador,
      focoTeclado: widget.foco,
      placeholder: 'Buscar producto por nombre o SKU…',
      alCambiar: ref.read(posProvider.notifier).buscar,
    );
  }
}
