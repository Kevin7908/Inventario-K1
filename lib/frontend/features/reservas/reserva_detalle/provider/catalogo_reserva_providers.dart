import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/productos/repositorio/repositorio_producto.dart';
import '../../../productos/provider/productos_provider.dart';
import '../modelo/reserva_editor_state.dart';
import 'reserva_editor_provider.dart';

/// El catálogo del panel izquierdo, ya filtrado por lo que el editor tiene
/// activo.
///
/// Vive aparte del notifier porque es lectura derivada: filtrar dentro de
/// `build()` repetiría el trabajo en cada repintado (§3 de `CLAUDE.md`).

/// La página de productos que muestra la rejilla, con su total real.
///
/// El `WHERE`, el `COUNT` y el `LIMIT` los resuelve SQLite. Se re-suscribe
/// solo cuando cambia algo de la consulta —búsqueda, categoría o página—, no
/// ante cualquier movimiento de la reserva: el `select` devuelve un record,
/// que solo notifica si sus campos cambiaron.
final paginaProductosReservaProvider =
    StreamProvider.autoDispose.family<PaginaProductos, int>(
  name: 'paginaProductosReservaProvider',
  (ref, reservaId) {
    final repositorio = ref.watch(repositorioProductosProvider);
    final consulta = ref.watch(
      reservaEditorProvider(reservaId).select((s) => (
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
      tamano: ReservaEditorState.tamanoPaginaCatalogo,
    );
  },
);

/// Cuántas páginas hay con el filtro vigente. Mínimo 1, para que el paginador
/// no desaparezca cuando la búsqueda no encuentra nada.
final totalPaginasReservaProvider = Provider.autoDispose.family<int, int>(
  name: 'totalPaginasReservaProvider',
  (ref, reservaId) {
    final total = ref.watch(
      paginaProductosReservaProvider(reservaId)
          .select((p) => p.value?.total ?? 0),
    );
    if (total <= 0) return 1;
    const tamano = ReservaEditorState.tamanoPaginaCatalogo;
    return (total + tamano - 1) ~/ tamano;
  },
);
