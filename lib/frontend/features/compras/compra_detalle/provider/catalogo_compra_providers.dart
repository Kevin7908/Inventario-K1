import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/productos/repositorio/repositorio_producto.dart';
import '../../../productos/provider/productos_provider.dart';
import '../modelo/compra_editor_state.dart';
import 'compra_editor_provider.dart';

/// El catálogo del panel izquierdo, ya filtrado por lo que la ficha tiene
/// activo.
///
/// Vive aparte del notifier porque es lectura derivada: filtrar dentro de
/// `build()` repetiría el trabajo en cada repintado (§3 de `CLAUDE.md`).

/// La página de productos que muestra la rejilla, con su total real.
///
/// El `WHERE`, el `COUNT` y el `LIMIT` los resuelve SQLite. Se re-suscribe
/// solo cuando cambia algo de la consulta —búsqueda, categoría o página—, no
/// ante cualquier movimiento de la remisión: el `select` devuelve un record,
/// que solo notifica si sus campos cambiaron.
final paginaProductosCompraProvider =
    StreamProvider.autoDispose.family<PaginaProductos, int>(
  name: 'paginaProductosCompraProvider',
  (ref, compraId) {
    final repositorio = ref.watch(repositorioProductosProvider);
    final consulta = ref.watch(
      compraEditorProvider(compraId).select((s) => (
            busqueda: s.value?.busquedaCatalogo ?? '',
            categoriaId: s.value?.categoriaId,
            pagina: s.value?.paginaCatalogo ?? 0,
          )),
    );

    return repositorio.observarPagina(
      // Sin `soloActivos`: lo que llega del proveedor entra aunque el producto
      // esté dado de baja, y hay que poder recibirlo para cuadrar el stock.
      filtro: FiltroProductos(
        busqueda: consulta.busqueda,
        categoriaId: consulta.categoriaId,
      ),
      pagina: consulta.pagina,
      tamano: CompraEditorState.tamanoPaginaCatalogo,
    );
  },
);

/// Cuántas páginas hay con el filtro vigente. Mínimo 1, para que el paginador
/// no desaparezca cuando la búsqueda no encuentra nada.
final totalPaginasCompraProvider = Provider.autoDispose.family<int, int>(
  name: 'totalPaginasCompraProvider',
  (ref, compraId) {
    final total = ref.watch(
      paginaProductosCompraProvider(compraId).select((p) => p.value?.total ?? 0),
    );
    if (total <= 0) return 1;
    const tamano = CompraEditorState.tamanoPaginaCatalogo;
    return (total + tamano - 1) ~/ tamano;
  },
);
