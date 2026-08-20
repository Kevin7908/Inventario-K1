import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/productos/modelo/producto.dart';
import '../../../../../backend/features/productos/repositorio/repositorio_producto.dart';
import '../../../../../backend/features/ventas/servicios/modelo/servicio.dart';
import '../../../productos/provider/productos_provider.dart';
import '../../../ventas/servicios/provider/servicios_provider.dart';
import '../modelo/orden_editor_state.dart';
import 'orden_editor_provider.dart';

/// Catálogos del panel izquierdo del editor de órdenes, ya filtrados por lo
/// que el editor tiene activo.
///
/// Viven aparte del notifier porque son lectura derivada: filtrar dentro de
/// `build()` repetiría el trabajo en cada repintado (§3 de `CLAUDE.md`).

/// La página de productos que muestra la rejilla, con su total real.
///
/// El `WHERE`, el `COUNT` y el `LIMIT` los resuelve SQLite (§5 de
/// `REGLAS_BD.md`). Se re-suscribe solo cuando cambia algo de la consulta
/// —búsqueda, categoría o página—, no ante cualquier movimiento de la orden:
/// el `select` devuelve un record, que solo notifica si sus campos cambiaron.
final paginaProductosOrdenProvider =
    StreamProvider.autoDispose.family<PaginaProductos, int>(
  name: 'paginaProductosOrdenProvider',
  (ref, ordenId) {
    final repositorio = ref.watch(repositorioProductosProvider);
    final consulta = ref.watch(
      ordenEditorProvider(ordenId).select((s) => (
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
      tamano: OrdenEditorState.tamanoPaginaCatalogo,
    );
  },
);

/// Cuántas páginas hay con el filtro vigente. Mínimo 1, para que el paginador
/// no desaparezca cuando la búsqueda no encuentra nada.
final totalPaginasOrdenProvider = Provider.autoDispose.family<int, int>(
  name: 'totalPaginasOrdenProvider',
  (ref, ordenId) {
    final total = ref.watch(
      paginaProductosOrdenProvider(ordenId).select((p) => p.value?.total ?? 0),
    );
    if (total <= 0) return 1;
    const tamano = OrdenEditorState.tamanoPaginaCatalogo;
    return (total + tamano - 1) ~/ tamano;
  },
);

/// Servicios activos ya filtrados por el buscador.
final serviciosOrdenProvider =
    Provider.autoDispose.family<List<Servicio>, int>(
  name: 'serviciosOrdenProvider',
  (ref, ordenId) {
    final todos = ref.watch(serviciosProvider).value ?? const <Servicio>[];
    final texto = ref.watch(
      ordenEditorProvider(ordenId)
          .select((s) => s.value?.busquedaCatalogo.toLowerCase() ?? ''),
    );

    return [
      for (final servicio in todos)
        if (servicio.activo &&
            (texto.isEmpty ||
                servicio.nombre.toLowerCase().contains(texto) ||
                (servicio.descripcion?.toLowerCase().contains(texto) ?? false)))
          servicio,
    ];
  },
);

/// Foto de cada producto, por id.
///
/// Las líneas de la orden solo guardan el id del producto, y la fila del
/// diseño lleva una miniatura de 48. Resolver la ruta aquí evita recorrer el
/// catálogo entero dentro del `build` de cada línea.
final imagenPorProductoOrdenProvider = Provider<Map<int, String?>>(
  name: 'imagenPorProductoOrdenProvider',
  (ref) {
    final todos =
        ref.watch(catalogoCompletoProvider).value ?? const <Producto>[];
    return {
      for (final p in todos)
        if (p.id != null) p.id!: p.imagenUrl,
    };
  },
);
