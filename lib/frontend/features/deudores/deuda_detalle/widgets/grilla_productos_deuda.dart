import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../share2/share2.dart';
import '../../../productos/widgets/grilla_productos_catalogo.dart';
import '../provider/catalogo_deuda_providers.dart';
import '../provider/deuda_editor_provider.dart';

/// Rejilla de productos de la ficha de una deuda.
///
/// Pone la página que devuelve SQLite dentro de [GrillaProductosCatalogo], la
/// misma rejilla del punto de venta, cotizaciones, órdenes y reservas. Un clic
/// fía una unidad; si el repuesto ya está en la deuda, le suma una.
///
/// **Aquí el stock manda de verdad**: fiar saca la mercancía del taller, no la
/// aparta. Un producto sin existencias no se puede fiar y el repositorio lo
/// rechaza; el color de la tarjeta avisa antes de intentarlo.
class GrillaProductosDeuda extends ConsumerWidget {
  const GrillaProductosDeuda({
    super.key,
    required this.deudaId,
    required this.habilitado,
  });

  final int deudaId;

  /// En `false` las tarjetas se ven pero no fían: la deuda ya está pagada o
  /// dada por perdida.
  final bool habilitado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.value` conserva la página anterior mientras llega la nueva: sin eso,
    // cada tecla del buscador parpadearía en blanco.
    final pagina = ref.watch(paginaProductosDeudaProvider(deudaId));
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
        ref.read(deudaEditorProvider(deudaId).notifier).agregarProducto;

    return GrillaProductosCatalogo(
      productos: productos,
      etiquetaAgregar: 'Fiar',
      habilitado: habilitado,
      // El fallo lo recoge la ficha y lo pone en la barra superior: la tarjeta
      // solo dispara. `unawaited` lo deja explícito para el §9.
      alAgregar: (producto) => unawaited(agregar(producto)),
    );
  }
}
