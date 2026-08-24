import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/productos/modelo/producto.dart';
import '../../../../../backend/features/productos/repositorio/repositorio_producto.dart';
import '../../../productos/provider/productos_provider.dart';
import '../modelo/deuda_editor_state.dart';
import 'deuda_editor_provider.dart';

/// El catálogo del panel izquierdo, ya filtrado por lo que la ficha tiene
/// activo.
///
/// Vive aparte del notifier porque es lectura derivada: filtrar dentro de
/// `build()` repetiría el trabajo en cada repintado (§3 de `CLAUDE.md`).

/// La página de productos que muestra la rejilla, con su total real.
///
/// El `WHERE`, el `COUNT` y el `LIMIT` los resuelve SQLite. Se re-suscribe
/// solo cuando cambia algo de la consulta —búsqueda, categoría o página—, no
/// ante cualquier movimiento de la deuda: el `select` devuelve un record, que
/// solo notifica si sus campos cambiaron.
final paginaProductosDeudaProvider =
    StreamProvider.autoDispose.family<PaginaProductos, int>(
  name: 'paginaProductosDeudaProvider',
  (ref, deudaId) {
    final repositorio = ref.watch(repositorioProductosProvider);
    final consulta = ref.watch(
      deudaEditorProvider(deudaId).select((s) => (
            busqueda: s.value?.busquedaCatalogo ?? '',
            categoriaId: s.value?.categoriaId,
            pagina: s.value?.paginaCatalogo ?? 0,
          )),
    );

    return repositorio.observarPagina(
      filtro: FiltroProductos(
        busqueda: consulta.busqueda,
        categoriaId: consulta.categoriaId,
        soloActivos: true,
      ),
      pagina: consulta.pagina,
      tamano: DeudaEditorState.tamanoPaginaCatalogo,
    );
  },
);

/// Cuántas páginas hay con el filtro vigente. Mínimo 1, para que el paginador
/// no desaparezca cuando la búsqueda no encuentra nada.
final totalPaginasDeudaProvider = Provider.autoDispose.family<int, int>(
  name: 'totalPaginasDeudaProvider',
  (ref, deudaId) {
    final total = ref.watch(
      paginaProductosDeudaProvider(deudaId).select((p) => p.value?.total ?? 0),
    );
    if (total <= 0) return 1;
    const tamano = DeudaEditorState.tamanoPaginaCatalogo;
    return (total + tamano - 1) ~/ tamano;
  },
);

/// Cuánto queda en bodega de cada producto, por id.
///
/// Sale del catálogo completo porque la línea guarda el id y necesita el tope
/// para no dejar fiar más de lo que hay.
final stockPorProductoDeudaProvider = Provider<Map<int, double>>(
  name: 'stockPorProductoDeudaProvider',
  (ref) {
    final todos =
        ref.watch(catalogoCompletoProvider).value ?? const <Producto>[];
    return {
      for (final p in todos)
        if (p.id != null) p.id!: p.stockActual,
    };
  },
);
