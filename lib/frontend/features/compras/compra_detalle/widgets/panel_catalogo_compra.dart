import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../share/share.dart';
import '../../../categorias/widgets/panel_categorias_catalogo.dart';
import '../provider/catalogo_compra_providers.dart';
import '../provider/compra_editor_provider.dart';
import 'grilla_productos_compra.dart';

/// Panel izquierdo de la ficha: de dónde salen las líneas de la remisión.
///
/// Es el mismo punto de venta de órdenes, cotizaciones, reservas y deudas, sin
/// el selector de secciones: una compra solo lleva productos.
class PanelCatalogoCompra extends ConsumerWidget {
  const PanelCatalogoCompra({
    super.key,
    required this.compraId,
    required this.focoBusqueda,
  });

  final int compraId;
  final FocusNode focoBusqueda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editable = ref.watch(
      compraEditorProvider(compraId).select((s) => s.value?.editable ?? false),
    );

    return Row(
      children: [
        _PanelCategorias(compraId: compraId),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Buscador(compraId: compraId, foco: focoBusqueda),
                if (!editable) ...[
                  const SizedBox(height: 12),
                  const _AvisoAnulada(),
                ],
                const SizedBox(height: 16),
                Expanded(
                  child: GrillaProductosCompra(
                    compraId: compraId,
                    habilitado: editable,
                  ),
                ),
                _Paginador(compraId: compraId),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// La columna de categorías, con su propio consumer para que teclear en el
/// buscador no la reconstruya.
class _PanelCategorias extends ConsumerWidget {
  const _PanelCategorias({required this.compraId});

  final int compraId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seleccionada = ref.watch(
      compraEditorProvider(compraId).select((s) => s.value?.categoriaId),
    );

    return PanelCategoriasCatalogo(
      seleccionada: seleccionada,
      alSeleccionar: (id) => ref
          .read(compraEditorProvider(compraId).notifier)
          .filtrarPorCategoria(id),
    );
  }
}

/// El buscador del catálogo. Es `StatefulWidget` por su controlador, que no
/// puede vivir en el estado del editor: es de la interfaz, no del documento.
class _Buscador extends ConsumerStatefulWidget {
  const _Buscador({required this.compraId, required this.foco});

  final int compraId;
  final FocusNode foco;

  @override
  ConsumerState<_Buscador> createState() => _BuscadorState();
}

class _BuscadorState extends ConsumerState<_Buscador> {
  final _busqueda = TextEditingController();

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BarraBusqueda(
      controlador: _busqueda,
      focoTeclado: widget.foco,
      placeholder: 'Buscar lo que llegó por nombre o SKU...',
      alCambiar: ref
          .read(compraEditorProvider(widget.compraId).notifier)
          .buscarEnCatalogo,
    );
  }
}

class _Paginador extends ConsumerWidget {
  const _Paginador({required this.compraId});

  final int compraId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagina = ref.watch(
      compraEditorProvider(compraId).select((s) => s.value?.paginaCatalogo ?? 0),
    );
    final total = ref.watch(totalPaginasCompraProvider(compraId));
    if (total <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: PaginacionWidget(
        paginaActual: pagina,
        totalPaginas: total,
        alCambiarPagina: (p) => ref
            .read(compraEditorProvider(compraId).notifier)
            .irAPaginaCatalogo(p),
      ),
    );
  }
}

/// Por qué el panel está apagado.
class _AvisoAnulada extends StatelessWidget {
  const _AvisoAnulada();

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
              'La compra está anulada: su mercancía ya salió del inventario.',
              style: TipografiaApp.caption,
            ),
          ),
        ],
      ),
    );
  }
}
