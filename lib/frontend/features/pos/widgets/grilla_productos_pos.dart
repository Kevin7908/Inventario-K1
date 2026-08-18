import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../../core/formato.dart';
import '../../../share2/share2.dart';
import '../../productos/vista/producto_vista.dart' show MiniaturaProducto;
import '../provider/pos_providers.dart';

/// Rejilla de productos del punto de venta: las tarjetas del diseño, con foto,
/// SKU, stock, precio y botón verde.
///
/// A diferencia del editor de cotizaciones, aquí el **stock sí bloquea**: lo
/// que no está en bodega no se puede entregar en el mostrador. La tarjeta
/// agotada se ve, para saber que existe, pero su botón queda deshabilitado.
///
/// Muestra **una página**, no el catálogo: el recorte lo hace SQLite y el
/// paginador vive en el pie del panel.
class GrillaProductosPos extends ConsumerWidget {
  const GrillaProductosPos({super.key});

  static Color _colorStock(Producto producto) {
    if (producto.stockActual <= 0) return ColoresApp.stockOut;
    if (producto.stockActual <= producto.stockMinimo) return ColoresApp.stockLow;
    return ColoresApp.textMuted;
  }

  static String _etiquetaStock(Producto producto) =>
      producto.stockActual <= 0
          ? 'Agotado'
          : '${formatearCantidad(producto.stockActual)} en stock';

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

    final agregar = ref.read(posProvider.notifier).agregarProducto;

    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 4),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        // `minmax(210px, 1fr)` del diseño, con su gap de 16.
        maxCrossAxisExtent: 260,
        mainAxisExtent: TarjetaProducto.altoSugerido,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: productos.length,
      itemBuilder: (context, i) {
        final producto = productos[i];
        final hayStock = producto.stockActual >= 1;

        return TarjetaProducto(
          key: ValueKey(producto.id),
          nombre: producto.nombre,
          codigo: producto.sku,
          detalle: _etiquetaStock(producto),
          colorDetalle: _colorStock(producto),
          precio: formatearPrecio(producto.precioVenta),
          imagen: MiniaturaProducto(
            rutaImagen: producto.imagenUrl,
            lado: 120,
            ancho: double.infinity,
            radio: 13,
            conBorde: false,
          ),
          etiquetaAgregar:
              hayStock ? 'Agregar a la venta' : 'Sin stock para vender',
          alAgregar: hayStock ? () => agregar(producto) : null,
          alPresionar: hayStock ? () => agregar(producto) : null,
        );
      },
    );
  }
}
