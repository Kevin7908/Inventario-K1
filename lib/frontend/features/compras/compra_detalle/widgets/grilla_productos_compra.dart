import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../share/share.dart';
import '../../../productos/widgets/grilla_productos_catalogo.dart';
import '../provider/catalogo_compra_providers.dart';
import '../provider/compra_editor_provider.dart';

/// Rejilla de productos de la ficha de una remisión.
///
/// Pone la página que devuelve SQLite dentro de [GrillaProductosCatalogo], la
/// misma rejilla del punto de venta, cotizaciones, órdenes y deudas. Un clic
/// anota una unidad con el último costo conocido; si el producto ya está en la
/// remisión, le suma una.
///
/// **Aquí el stock no acota nada**, al revés que en los otros cuatro: una
/// compra mete mercancía, así que un producto en cero es justo el que más se
/// va a teclear.
class GrillaProductosCompra extends ConsumerWidget {
  const GrillaProductosCompra({
    super.key,
    required this.compraId,
    required this.habilitado,
  });

  final int compraId;

  /// En `false` las tarjetas se ven pero no anotan: la remisión está anulada.
  final bool habilitado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.value` conserva la página anterior mientras llega la nueva: sin eso,
    // cada tecla del buscador parpadearía en blanco.
    final pagina = ref.watch(paginaProductosCompraProvider(compraId));
    final productos = pagina.value?.items;

    if (productos == null) {
      return const Center(
        child: CircularProgressIndicator(color: ColoresApp.goGreen),
      );
    }

    if (productos.isEmpty) {
      return const EstadoVacio(
        icono: Icons.search_off_rounded,
        titulo: 'Ningún producto coincide',
        pista: 'Prueba con otro nombre o quita el filtro de categoría.',
      );
    }

    final agregar =
        ref.read(compraEditorProvider(compraId).notifier).agregarProducto;

    return GrillaProductosCatalogo(
      productos: productos,
      etiquetaAgregar: 'Recibir',
      habilitado: habilitado,
      // El fallo lo recoge la ficha y lo pone en la barra superior: la tarjeta
      // solo dispara. `unawaited` lo deja explícito para el §9.
      alAgregar: (producto) => unawaited(agregar(producto)),
    );
  }
}
