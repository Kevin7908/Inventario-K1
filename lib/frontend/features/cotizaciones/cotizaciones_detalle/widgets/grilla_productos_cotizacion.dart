import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../share/share.dart';
import '../../../productos/widgets/grilla_productos_catalogo.dart';
import '../provider/catalogo_cotizacion_providers.dart';
import '../provider/cotizacion_editor_provider.dart';

/// Rejilla de productos del editor de cotizaciones.
///
/// Pone la página que devuelve SQLite dentro de [GrillaProductosCatalogo], la
/// misma rejilla del punto de venta y del editor de órdenes. Un clic en la
/// tarjeta —o en su botón verde— agrega el producto con cantidad 1; si ya está
/// en la cotización, le suma uno.
///
/// El **stock se muestra pero no bloquea**: una cotización no mueve inventario,
/// y cotizar lo que hay que pedirle al proveedor es parte del trabajo. El color
/// avisa igual, para que quien cotiza sepa que ese repuesto no está en bodega.
///
/// Muestra **una página**, no el catálogo: el recorte lo hace SQLite y el
/// paginador vive en el pie del panel.
class GrillaProductosCotizacion extends ConsumerWidget {
  const GrillaProductosCotizacion({super.key, required this.cotizacionId});

  final int? cotizacionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.value` conserva la página anterior mientras llega la nueva: sin eso,
    // cada tecla del buscador parpadearía en blanco.
    final pagina = ref.watch(paginaProductosCotizacionProvider(cotizacionId));
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
      etiquetaAgregar: 'Agregar a la cotización',
      alAgregar:
          ref.read(cotizacionEditorProvider(cotizacionId).notifier).agregarProducto,
    );
  }
}
