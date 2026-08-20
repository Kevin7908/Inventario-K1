import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/productos/modelo/producto.dart';
import '../../../../../core/formato.dart';
import '../../../../share2/share2.dart';
import '../../../productos/vista/producto_vista.dart' show MiniaturaProducto;
import '../provider/catalogo_orden_providers.dart';
import '../provider/orden_editor_provider.dart';

/// Rejilla de repuestos del editor de órdenes, con las tarjetas del punto de
/// venta.
///
/// Un clic en la tarjeta —o en su botón verde— anota el repuesto con cantidad
/// 1; si ya está en la orden, le suma uno.
///
/// **El stock se muestra pero no bloquea**, y aquí el motivo es distinto que
/// en cotizaciones. Mientras la orden está `ABIERTA` el repuesto solo se
/// anota: no sale nada del estante hasta cerrarla (§1.3 de `PLAN_ORDENES.md`).
/// Eso deja abierta la puerta a que dos órdenes anoten la misma última pieza,
/// y está aceptado a propósito: al cerrar se verifica el stock de todas y, si
/// no alcanza, la orden no cambia de estado. El color avisa igual.
///
/// La **ubicación** va en la tarjeta porque quien arma la orden tiene que ir
/// a buscar la pieza al estante; sin ella habría que abrir el producto en otra
/// pantalla.
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
        // `agregarProducto` devuelve un `Resultado`, pero el fallo ya lo
        // recoge el editor y lo pone en la barra superior: la tarjeta solo
        // dispara. `unawaited` lo deja explícito para el lint del §9.
        void alTocar() => unawaited(agregar(producto));

        return TarjetaProducto(
          key: ValueKey(producto.id),
          nombre: producto.nombre,
          codigo: producto.sku,
          ubicacion: producto.ubicacionBodega,
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
          etiquetaAgregar: 'Agregar a la orden',
          alAgregar: habilitado ? alTocar : null,
          alPresionar: habilitado ? alTocar : null,
        );
      },
    );
  }
}
