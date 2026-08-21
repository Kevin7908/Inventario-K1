import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../share2/share2.dart';
import '../../../productos/widgets/grilla_productos_catalogo.dart';
import '../provider/catalogo_orden_providers.dart';
import '../provider/orden_editor_provider.dart';

/// Rejilla de repuestos del editor de órdenes.
///
/// Pone la página que devuelve SQLite dentro de [GrillaProductosCatalogo], la
/// misma rejilla del punto de venta y del editor de cotizaciones. Un clic en
/// la tarjeta —o en su botón verde— anota el repuesto con cantidad 1; si ya
/// está en la orden, le suma uno.
///
/// **El stock se muestra pero no bloquea**, y aquí el motivo es distinto que
/// en cotizaciones. Mientras la orden está `ABIERTA` el repuesto solo se
/// anota: no sale nada del estante hasta cerrarla. Eso deja abierta la puerta
/// a que dos órdenes anoten la misma última pieza, y está aceptado a
/// propósito: al cerrar se verifica el stock de todas y, si no alcanza, la
/// orden no cambia de estado. El color avisa igual.
class GrillaProductosOrden extends ConsumerWidget {
  const GrillaProductosOrden({
    super.key,
    required this.ordenId,
    required this.habilitado,
  });

  final int ordenId;

  /// En `false` las tarjetas se ven pero no agregan: la orden ya está
  /// entregada o anulada, y una guarda de la base rechazaría la escritura.
  final bool habilitado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.value` conserva la página anterior mientras llega la nueva: sin eso,
    // cada tecla del buscador parpadearía en blanco.
    final pagina = ref.watch(paginaProductosOrdenProvider(ordenId));
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
            'Ningún repuesto coincide con la búsqueda o la categoría.',
            textAlign: TextAlign.center,
            style: TipografiaApp.caption,
          ),
        ),
      );
    }

    final agregar =
        ref.read(ordenEditorProvider(ordenId).notifier).agregarProducto;

    return GrillaProductosCatalogo(
      productos: productos,
      etiquetaAgregar: 'Agregar a la orden',
      habilitado: habilitado,
      // `agregarProducto` devuelve un `Resultado`, pero el fallo ya lo recoge
      // el editor y lo pone en la barra superior: la tarjeta solo dispara.
      // `unawaited` lo deja explícito para el lint del §9.
      alAgregar: (producto) => unawaited(agregar(producto)),
    );
  }
}
