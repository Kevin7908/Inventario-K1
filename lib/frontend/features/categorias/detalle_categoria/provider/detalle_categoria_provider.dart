import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/productos/repositorio/repositorio_producto.dart';
import '../../../productos/provider/productos_provider.dart';

/// Claves de la consulta paginada de productos de una categoría.
///
/// Es un record, así que tiene igualdad estructural: dos búsquedas idénticas
/// comparten la misma instancia del provider en vez de abrir otra consulta.
typedef ClaveProductosCategoria = ({
  int categoriaId,
  String busqueda,
  FiltroStock stock,
  int pagina,
  int tamano,
});

/// Una página de productos de una categoría, filtrada **en SQL**.
///
/// Antes esto derivaba del catálogo completo cargado en memoria; ahora el
/// `WHERE`, el `COUNT` y el `LIMIT` los resuelve SQLite, igual que en la tabla
/// de Productos.
final productosDeCategoriaProvider = StreamProvider.autoDispose
    .family<PaginaProductos, ClaveProductosCategoria>(
  name: 'productosDeCategoriaProvider',
  (ref, clave) => ref.watch(repositorioProductosProvider).observarPagina(
        filtro: FiltroProductos(
          busqueda: clave.busqueda,
          categoriaId: clave.categoriaId,
          soloEnStock: clave.stock == FiltroStock.enStock,
          soloStockBajo: clave.stock == FiltroStock.stockBajo,
          soloSinStock: clave.stock == FiltroStock.sinStock,
        ),
        pagina: clave.pagina,
        tamano: clave.tamano,
      ),
);
