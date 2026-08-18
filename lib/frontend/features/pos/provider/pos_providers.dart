import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/productos/repositorio/repositorio_producto.dart';
import '../../productos/provider/productos_provider.dart';
import '../modelo/pos_state.dart';
import 'pos_notifier.dart';

final posProvider = NotifierProvider<PosNotifier, PosState>(
  PosNotifier.new,
  name: 'posProvider',
);

/// La página de productos que muestra la rejilla, con su total real.
///
/// El `WHERE`, el `COUNT` y el `LIMIT` los resuelve SQLite (§7): la vista no
/// ve el catálogo entero. Se re-suscribe solo cuando cambia algo de la
/// consulta —búsqueda, categoría o página—, no ante cualquier movimiento del
/// carrito, porque el `select` devuelve un record y este solo notifica si sus
/// campos cambiaron.
final paginaProductosPosProvider = StreamProvider<PaginaProductos>(
  name: 'paginaProductosPosProvider',
  (ref) {
    final repositorio = ref.watch(repositorioProductosProvider);
    final consulta = ref.watch(
      posProvider.select((s) => (
            busqueda: s.busqueda,
            categoriaId: s.categoriaId,
            pagina: s.pagina,
          )),
    );

    return repositorio.observarPagina(
      filtro: FiltroProductos(
        busqueda: consulta.busqueda,
        categoriaId: consulta.categoriaId,
        soloActivos: true,
      ),
      pagina: consulta.pagina,
      tamano: PosState.tamanoPagina,
    );
  },
);

/// Cuántas páginas hay con el filtro vigente. Mínimo 1, para que el paginador
/// no desaparezca cuando la búsqueda no encuentra nada.
final totalPaginasPosProvider = Provider<int>(
  name: 'totalPaginasPosProvider',
  (ref) {
    final total = ref.watch(
      paginaProductosPosProvider.select((p) => p.value?.total ?? 0),
    );
    if (total <= 0) return 1;
    return (total + PosState.tamanoPagina - 1) ~/ PosState.tamanoPagina;
  },
);
