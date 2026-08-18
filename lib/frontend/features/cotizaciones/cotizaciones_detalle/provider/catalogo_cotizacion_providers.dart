import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/productos/modelo/producto.dart';
import '../../../../../backend/features/ventas/servicios/modelo/servicio.dart';
import '../../../productos/provider/productos_provider.dart';
import '../../../ventas/servicios/provider/servicios_provider.dart';
import 'cotizacion_editor_provider.dart';

/// Catálogos del panel izquierdo, ya filtrados por lo que el editor tiene
/// activo. Viven aparte del notifier porque son lectura derivada: filtrar
/// dentro de `build()` repetiría el trabajo en cada repintado.

/// Productos del catálogo ya filtrados por el buscador y la categoría activa.
///
/// El editor es uno de los casos que el §7 de las reglas contempla: necesita
/// todo el catálogo para buscar, así que lo pide a [catalogoCompletoProvider] y
/// no al estado paginado de Productos.
final productosCotizacionProvider =
    Provider.autoDispose.family<List<Producto>, int?>(
  name: 'productosCotizacionProvider',
  (ref, id) {
    final todos = ref.watch(catalogoCompletoProvider).value ?? const <Producto>[];
    final estado = ref.watch(cotizacionEditorProvider(id)).value;
    if (estado == null) return const [];

    final texto = estado.busquedaCatalogo.toLowerCase();
    return todos.where((p) {
      if (!p.activo) return false;
      if (estado.categoriaId != null && p.categoriaId != estado.categoriaId) {
        return false;
      }
      if (texto.isEmpty) return true;
      return p.nombre.toLowerCase().contains(texto) ||
          p.sku.toLowerCase().contains(texto);
    }).toList(growable: false);
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
