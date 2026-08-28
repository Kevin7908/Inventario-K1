import 'package:flutter/material.dart';

import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../../core/formato.dart';
import '../../../share2/share2.dart';
import '../vista/producto_vista.dart' show MiniaturaProducto;

/// La rejilla de tarjetas con la que se eligen productos para un documento.
///
/// **Es la única.** El punto de venta, el editor de cotizaciones y el de
/// órdenes tenían cada uno su propia copia: el mismo `GridView`, el mismo
/// `_colorStock`, el mismo `_etiquetaStock` y el mismo mapeo a
/// [TarjetaProducto], con tres nombres distintos. Ahí fue donde se coló que la
/// ubicación en bodega apareciera en dos de las tres pantallas: cada copia
/// decidía por su cuenta qué pasarle a la tarjeta. Con una sola, o aparece en
/// las tres o en ninguna.
///
/// No va en share2 porque conoce `Producto` y lee la foto del disco
/// (`MiniaturaProducto`); share2 recibe textos ya resueltos (regla 0.3 de
/// `CLAUDE.md`). Lo que sí sale de share2 es la tarjeta.
///
/// Parámetros:
/// - [productos]: la página que se está mostrando, ya recortada por SQL.
/// - [etiquetaAgregar]: tooltip del botón verde ('Agregar a la venta'…).
/// - [alAgregar]: qué hacer con el producto elegido. Se dispara igual al tocar
///   la tarjeta entera.
/// - [bloquearSinStock]: en `true` el producto agotado se ve pero no se puede
///   agregar, y su línea dice «Agotado» —es el mostrador: lo que no está en
///   bodega no se entrega—. En `false` se puede agregar igual y dice «Sin
///   stock · hay que pedirlo», que es lo que hacen una cotización y una orden.
/// - [habilitado]: en `false` ninguna tarjeta agrega (orden ya entregada).
///
/// Ejemplo:
/// ```dart
/// GrillaProductosCatalogo(
///   productos: pagina.items,
///   etiquetaAgregar: 'Agregar a la orden',
///   alAgregar: (producto) => notifier.agregarProducto(producto),
/// )
/// ```
class GrillaProductosCatalogo extends StatelessWidget {
  const GrillaProductosCatalogo({
    super.key,
    required this.productos,
    required this.etiquetaAgregar,
    required this.alAgregar,
    this.bloquearSinStock = false,
    this.habilitado = true,
  });

  final List<Producto> productos;
  final String etiquetaAgregar;
  final ValueChanged<Producto> alAgregar;
  final bool bloquearSinStock;
  final bool habilitado;

  static Color _colorStock(Producto p) {
    if (p.stockActual <= 0) return ColoresApp.stockOut;
    if (p.stockActual <= p.stockMinimo) return ColoresApp.stockLow;
    return ColoresApp.textMuted;
  }

  String _etiquetaStock(Producto p) {
    if (p.stockActual > 0) return '${formatearCantidad(p.stockActual)} en stock';
    return bloquearSinStock ? 'Agotado' : 'Sin stock · hay que pedirlo';
  }

  @override
  Widget build(BuildContext context) {
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
        final agotado = producto.stockActual <= 0;
        final puedeAgregar =
            habilitado && !(bloquearSinStock && agotado);

        return TarjetaProducto(
          key: ValueKey(producto.id),
          nombre: producto.nombre,
          codigo: producto.sku,
          detalle: _etiquetaStock(producto),
          colorDetalle: _colorStock(producto),
          // Quien arma el documento es quien va al estante a buscar la pieza:
          // sin esto hay que abrir el producto en otra pantalla.
          ubicacion: producto.ubicacionBodega,
          precio: formatearPrecio(producto.precioVenta),
          imagen: MiniaturaProducto(
            rutaImagen: producto.imagenUrl,
            lado: 120,
            ancho: double.infinity,
            radio: 13,
            conBorde: false,
          ),
          etiquetaAgregar: bloquearSinStock && agotado
              ? 'Sin stock para vender'
              : etiquetaAgregar,
          alAgregar: puedeAgregar ? () => alAgregar(producto) : null,
          alPresionar: puedeAgregar ? () => alAgregar(producto) : null,
        );
      },
    );
  }
}
