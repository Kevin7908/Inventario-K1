import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/productos/modelo/producto.dart';
import '../../../../../backend/features/productos/repositorio/repositorio_producto.dart';
import '../../../../../backend/features/servicios/modelo/servicio.dart';
import '../../../productos/provider/productos_provider.dart';
import '../../../servicios/provider/servicios_provider.dart';
import '../modelo/cotizacion_editor_state.dart';
import 'cotizacion_editor_provider.dart';

/// Catálogos del panel izquierdo, ya filtrados por lo que el editor tiene
/// activo. Viven aparte del notifier porque son lectura derivada: filtrar
/// dentro de `build()` repetiría el trabajo en cada repintado.

/// La página de productos que muestra la rejilla, con su total real.
///
/// El `WHERE`, el `COUNT` y el `LIMIT` los resuelve SQLite (§7). Se
/// re-suscribe solo cuando cambia algo de la consulta —búsqueda, categoría o
/// página—, no ante cualquier movimiento de la cotización: el `select`
/// devuelve un record, que solo notifica si sus campos cambiaron.
final paginaProductosCotizacionProvider =
    StreamProvider.autoDispose.family<PaginaProductos, int?>(
  name: 'paginaProductosCotizacionProvider',
  (ref, id) {
    final repositorio = ref.watch(repositorioProductosProvider);
    final consulta = ref.watch(
      cotizacionEditorProvider(id).select((s) => (
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
      tamano: CotizacionEditorState.tamanoPaginaCatalogo,
    );
  },
);

/// Cuántas páginas hay con el filtro vigente. Mínimo 1, para que el paginador
/// no desaparezca cuando la búsqueda no encuentra nada.
final totalPaginasCotizacionProvider =
    Provider.autoDispose.family<int, int?>(
  name: 'totalPaginasCotizacionProvider',
  (ref, id) {
    final total = ref.watch(
      paginaProductosCotizacionProvider(id).select((p) => p.value?.total ?? 0),
    );
    if (total <= 0) return 1;
    const tamano = CotizacionEditorState.tamanoPaginaCatalogo;
    return (total + tamano - 1) ~/ tamano;
  },
);

/// Servicios activos ya filtrados por el buscador.
final serviciosCotizacionProvider =
    Provider.autoDispose.family<List<Servicio>, int?>(
  name: 'serviciosCotizacionProvider',
  (ref, id) {
    final todos = ref.watch(serviciosProvider).value ?? const <Servicio>[];
    final estado = ref.watch(cotizacionEditorProvider(id)).value;
    if (estado == null) return const [];

    final texto = estado.busquedaCatalogo.toLowerCase();
    return todos.where((s) {
      if (!s.activo) return false;
      if (texto.isEmpty) return true;
      return s.nombre.toLowerCase().contains(texto) ||
          (s.descripcion?.toLowerCase().contains(texto) ?? false);
    }).toList(growable: false);
  },
);

/// Foto de cada producto, por id.
///
/// Las líneas de la cotización solo guardan `referenciaId`, y la fila del
/// diseño lleva una miniatura de 48. Resolver la ruta aquí evita recorrer el
/// catálogo entero dentro del `build` de cada línea.
final imagenPorProductoProvider = Provider<Map<int, String?>>(
  name: 'imagenPorProductoProvider',
  (ref) {
    final todos = ref.watch(catalogoCompletoProvider).value ?? const <Producto>[];
    return {
      for (final p in todos)
        if (p.id != null) p.id!: p.imagenUrl,
    };
  },
);
