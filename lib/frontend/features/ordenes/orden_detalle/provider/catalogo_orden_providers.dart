import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/productos/modelo/producto.dart';
import '../../../../../backend/features/productos/repositorio/repositorio_producto.dart';
import '../../../../../backend/features/servicios/modelo/servicio.dart';
import '../../../productos/provider/productos_provider.dart';
import '../../../servicios/provider/servicios_provider.dart';
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

/// Foto y stock de cada producto, por id.
///
/// Las líneas de la orden solo guardan el id del producto, y la fila necesita
/// dos cosas suyas: la miniatura de 48 y cuánto queda en bodega. Resolverlas
/// aquí evita recorrer el catálogo entero dentro del `build` de cada línea.
///
/// El stock es el que acota la cantidad de la línea. Desde que anotar un
/// repuesto lo descuenta, `stock_actual` ya **no** incluye lo que esta orden
/// se llevó, así que el tope de una línea es lo que queda más lo que ella
/// misma tiene anotado: eso lo suma quien la pinta, que es el único que sabe
/// cuánto lleva.
typedef DatosProductoLinea = ({String? imagen, double stock});

final datosProductoOrdenProvider = Provider<Map<int, DatosProductoLinea>>(
  name: 'datosProductoOrdenProvider',
  (ref) {
    final todos =
        ref.watch(catalogoCompletoProvider).value ?? const <Producto>[];
    return {
      for (final p in todos)
        if (p.id != null) p.id!: (imagen: p.imagenUrl, stock: p.stockActual),
    };
  },
);
