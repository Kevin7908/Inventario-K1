import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../share2/share2.dart';
import '../../productos/widgets/grilla_productos_catalogo.dart';
import '../provider/pos_providers.dart';

/// Rejilla de productos del punto de venta.
///
/// Pone la página que devuelve SQLite dentro de [GrillaProductosCatalogo], que
/// es la misma rejilla del editor de cotizaciones y del de órdenes: foto, SKU,
/// stock, ubicación en bodega, precio y botón verde.
///
/// A diferencia de esos dos, aquí el **stock sí bloquea**: lo que no está en
/// bodega no se puede entregar en el mostrador. La tarjeta agotada se ve, para
/// saber que existe, pero su botón queda deshabilitado.
///
/// Muestra **una página**, no el catálogo: el recorte lo hace SQLite y el
/// paginador vive en el pie del panel.
class GrillaProductosPos extends ConsumerWidget {
  const GrillaProductosPos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.value` conserva la página anterior mientras llega la nueva: sin eso,
    // cada tecla del buscador parpadearía en blanco.
    final pagina = ref.watch(paginaProductosPosProvider);
    final productos = pagina.value?.items;

    if (productos == null) {
      return const Center(
        child: CircularProgressIndicator(color: ColoresApp.goGreen),
      );
    }

    if (productos.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Ningún producto coincide con la búsqueda o la categoría.',
            textAlign: TextAlign.center,
            style: TipografiaApp.caption,
          ),
        ),
      );
    }

    return GrillaProductosCatalogo(
      productos: productos,
      etiquetaAgregar: 'Agregar a la venta',
      bloquearSinStock: true,
      alAgregar: ref.read(posProvider.notifier).agregarProducto,
    );
  }
}
