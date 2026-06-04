import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/productos/modelo/producto.dart';
import '../../../productos/provider/productos_provider.dart';

/// Productos que pertenecen a [categoriaId], derivados del stream global.
/// Usa `.select` para que el provider solo notifique cuando cambian los
/// productos de ESA categoría, no ante cualquier mutación del estado global.
final productosDeCategoriaProvider =
    Provider.autoDispose.family<List<Producto>, int>(
  (ref, categoriaId) => ref.watch(
    productosProvider.select(
      (async) => (async.value?.todos ?? const <Producto>[])
          .where((p) => p.categoriaId == categoriaId)
          .toList(),
    ),
  ),
  name: 'productosDeCategoriaProvider',
);
