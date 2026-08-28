import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../share/share.dart';
import '../../../productos/widgets/grilla_productos_catalogo.dart';
import '../provider/catalogo_reserva_providers.dart';
import '../provider/reserva_editor_provider.dart';

/// Rejilla de productos del editor de reservas.
///
/// Pone la página que devuelve SQLite dentro de [GrillaProductosCatalogo], la
/// misma rejilla del punto de venta, cotizaciones y órdenes. Un clic aparta
/// una unidad; si el producto ya está en la reserva, le suma una.
///
/// **Aquí el stock sí manda**, a diferencia de una cotización: apartar saca la
/// mercancía del inventario disponible en el acto, así que un producto sin
/// existencias no se puede reservar y el repositorio lo rechaza. El color de
/// la tarjeta avisa antes de intentarlo.
class GrillaProductosReserva extends ConsumerWidget {
  const GrillaProductosReserva({
    super.key,
    required this.reservaId,
    required this.habilitado,
  });

  final int reservaId;

  /// En `false` las tarjetas se ven pero no apartan: la reserva ya está
  /// completada o cancelada.
  final bool habilitado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.value` conserva la página anterior mientras llega la nueva: sin eso,
    // cada tecla del buscador parpadearía en blanco.
    final pagina = ref.watch(paginaProductosReservaProvider(reservaId));
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
        ref.read(reservaEditorProvider(reservaId).notifier).agregarProducto;

    return GrillaProductosCatalogo(
      productos: productos,
      etiquetaAgregar: 'Apartar',
      habilitado: habilitado,
      // El fallo lo recoge el editor y lo pone en la barra superior: la
      // tarjeta solo dispara. `unawaited` lo deja explícito para el §9.
      alAgregar: (producto) => unawaited(agregar(producto)),
    );
  }
}
