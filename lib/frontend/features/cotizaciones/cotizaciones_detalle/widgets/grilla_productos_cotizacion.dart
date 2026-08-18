import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/productos/modelo/producto.dart';
import '../../../../../core/formato.dart';
import '../../../../share2/share2.dart';
import '../../../productos/vista/producto_vista.dart' show MiniaturaProducto;
import '../provider/catalogo_cotizacion_providers.dart';
import '../provider/cotizacion_editor_provider.dart';

/// Rejilla de productos del editor, con las tarjetas del punto de venta.
///
/// Un clic en la tarjeta —o en su botón verde— agrega el producto con cantidad
/// 1; si ya está en la cotización, le suma uno.
///
/// El **stock se muestra pero no bloquea**: una cotización no mueve inventario,
/// y cotizar lo que hay que pedirle al proveedor es parte del trabajo. El color
/// avisa igual, para que quien cotiza sepa que ese repuesto no está en bodega.
class GrillaProductosCotizacion extends ConsumerWidget {
  const GrillaProductosCotizacion({super.key, required this.cotizacionId});

  final int? cotizacionId;

  static Color _colorStock(Producto p) {
    if (p.stockActual <= 0) return ColoresApp.stockOut;
    if (p.stockActual <= p.stockMinimo) return ColoresApp.stockLow;
    return ColoresApp.textMuted;
  }

  static String _etiquetaStock(Producto p) {
    if (p.stockActual <= 0) return 'Sin stock · hay que pedirlo';
    return '${formatearCantidad(p.stockActual)} en stock';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productos = ref.watch(productosCotizacionProvider(cotizacionId));

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

    final agregar =
        ref.read(cotizacionEditorProvider(cotizacionId).notifier).agregarProducto;

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
          etiquetaAgregar: 'Agregar a la cotización',
          alAgregar: () => agregar(producto),
          alPresionar: () => agregar(producto),
        );
      },
    );
  }
}
