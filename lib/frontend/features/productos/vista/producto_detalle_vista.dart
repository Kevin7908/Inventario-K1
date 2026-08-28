import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/formato.dart';

import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../share2/share2.dart';
import '../widgets/badget_estado_stock_widget.dart';
import '../../../../backend/share/dominio/permiso.dart';
import '../../autenticacion/widgets/si_puede.dart';
import '../../inventario/widgets/dialogo_entrada_compra.dart';
import '../../inventario/widgets/panel_movimientos_producto.dart';

/// Ficha de un producto: imagen, datos de inventario y acciones.
///
/// Es una página completa dentro del módulo de Productos, no un diálogo: el
/// contenido no cabe cómodamente en un modal y así se replica el flujo del
/// diseño ("Volver a productos" → ficha → "Editar producto").
///
/// [alVolver], [alEditar] y [alEliminar] son opcionales para poder reutilizar
/// la misma ficha dentro de `DialogoDetalleProductoWidget`, que ya trae su
/// propio botón de cerrar y no ofrece edición ni borrado. Si son `null`, se
/// ocultan esos controles.
class ProductoDetalleVista extends StatelessWidget {
  const ProductoDetalleVista({
    super.key,
    required this.producto,
    this.alVolver,
    this.alEditar,
    this.alEliminar,
    this.padding = const EdgeInsets.fromLTRB(32, 24, 32, 40),
  });

  final Producto producto;
  final VoidCallback? alVolver;
  final VoidCallback? alEditar;
  final VoidCallback? alEliminar;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (alVolver != null) ...[
            BotonVolver(
              etiqueta: 'Volver a productos',
              alPresionar: alVolver!,
            ),
            const SizedBox(height: 18),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              // En ventanas angostas la ficha pasa a una sola columna en vez
              // de comprimir la imagen y los datos.
              if (constraints.maxWidth < 900) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Galeria(rutaImagen: producto.imagenUrl),
                    const SizedBox(height: 26),
                    _Ficha(producto: producto, alEditar: alEditar, alEliminar: alEliminar),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: _Galeria(rutaImagen: producto.imagenUrl),
                  ),
                  const SizedBox(width: 26),
                  Expanded(
                    flex: 5,
                    child: _Ficha(producto: producto, alEditar: alEditar, alEliminar: alEliminar),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 26),
          _PanelesSecundarios(producto: producto),
        ],
      ),
    );
  }
}

class _Galeria extends StatelessWidget {
  const _Galeria({required this.rutaImagen});

  final String? rutaImagen;

  @override
  Widget build(BuildContext context) {
    final ruta = rutaImagen;
    final hayRuta = ruta != null && ruta.isNotEmpty;

    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: ColoresApp.bgInput,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ColoresApp.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: hayRuta ? _imagen(context, ruta) : const _SinImagen(),
    );
  }

  Widget _imagen(BuildContext context, String ruta) {
    // Sin `existsSync()` en build (I/O síncrono): el `errorBuilder` ya cubre el
    // archivo que no está. `cacheHeight` evita decodificar una foto enorme para
    // pintarla en 360 px de alto.
    final escala = MediaQuery.devicePixelRatioOf(context);

    return Image.file(
      File(ruta),
      fit: BoxFit.cover,
      width: double.infinity,
      cacheHeight: (360 * escala).round(),
      errorBuilder: (_, _, _) => const _SinImagen(),
    );
  }
}

class _SinImagen extends StatelessWidget {
  const _SinImagen();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_outlined,
            size: 46,
            color: ColoresApp.textDisabled,
          ),
          SizedBox(height: 10),
          Text('Sin imagen', style: TipografiaApp.caption),
        ],
      ),
    );
  }
}

/// Columna derecha: categoría, nombre, precio, estado y datos de inventario.
class _Ficha extends StatelessWidget {
  const _Ficha({required this.producto, this.alEditar, this.alEliminar});

  final Producto producto;
  final VoidCallback? alEditar;
  final VoidCallback? alEliminar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IndicadorEstado(
          etiqueta: producto.categoriaNombre ?? 'Sin categoría',
          color: ColoresApp.castletonGreen,
          colorFondo: ColoresApp.greenChipBg,
        ),
        const SizedBox(height: 12),
        Text(producto.nombre, style: TipografiaApp.heading1.copyWith(fontSize: 28)),
        const SizedBox(height: 6),
        Text(
          'SKU ${producto.sku}',
          style: TipografiaApp.monoespaciada(
            TipografiaApp.cuerpo.copyWith(color: ColoresApp.textDisabled),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text(
              formatearPrecio(producto.precioVenta),
              style: TipografiaApp.heading1.copyWith(
                fontSize: 32,
                color: ColoresApp.castletonGreen,
              ),
            ),
            const SizedBox(width: 16),
            BadgeEstadoStock(estado: producto.estadoStock),
          ],
        ),
        if (producto.aplicaIva) ...[
          const SizedBox(height: 6),
          Text(
            'Incluye ${formatearPrecio(producto.ivaDelPrecio)} de IVA',
            style: TipografiaApp.caption,
          ),
        ],
        const SizedBox(height: 22),
        _GrillaDatos(producto: producto),
        const SizedBox(height: 22),
        _Compatibilidad(descripcion: producto.descripcion),
        if (alEditar != null || alEliminar != null) ...[
          const SizedBox(height: 22),
          // Dar entrada vive aquí además de en Movimientos: cuando llega la
          // remisión, quien la recibe está mirando el producto, no el kardex.
          // Es el mismo diálogo, con el producto ya elegido.
          SiPuede(
            permiso: Permiso.inventarioEntrada,
            child: BotonSecundario(
              etiqueta: 'Dar entrada',
              icono: Icons.local_shipping_outlined,
              expandido: true,
              alPresionar: () =>
                  DialogoEntradaCompra.mostrar(context, producto: producto),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (alEditar != null)
                Expanded(
                  child: BotonSecundario(
                    etiqueta: 'Editar producto',
                    icono: Icons.edit_outlined,
                    oscuro: true,
                    expandido: true,
                    alPresionar: alEditar,
                  ),
                ),
              if (alEditar != null && alEliminar != null)
                const SizedBox(width: 12),
              // Eliminar vive solo aquí, en la ficha: obliga a abrir el
              // producto y ver qué se está borrando antes de hacerlo.
              if (alEliminar != null)
                BotonDestructivo(
                  etiqueta: 'Eliminar',
                  icono: Icons.delete_outline_rounded,
                  alPresionar: alEliminar,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Los cuatro datos de inventario, en dos filas de dos.
class _GrillaDatos extends StatelessWidget {
  const _GrillaDatos({required this.producto});

  final Producto producto;

  @override
  Widget build(BuildContext context) {
    String cantidad(double v) {
      final entero = v.truncateToDouble() == v;
      return entero ? v.toInt().toString() : v.toStringAsFixed(2);
    }

    final unidad = producto.unidadMedidaNombre ?? 'und';

    // `IntrinsicHeight` iguala el alto de las dos tarjetas de cada fila.
    // No se usa `CrossAxisAlignment.stretch`: la ficha vive dentro de un
    // `SingleChildScrollView`, así que no tiene alto acotado y estirar los
    // hijos hasta el infinito reventaba el layout.
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: TarjetaInfo(
                  etiqueta: 'Stock disponible',
                  valor: '${cantidad(producto.stockActual)} $unidad',
                  colorValor: producto.estadoStock == EstadoStock.sinStock
                      ? ColoresApp.stockOut
                      : null,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: TarjetaInfo(
                  etiqueta: 'Stock mínimo',
                  valor: '${cantidad(producto.stockMinimo)} $unidad',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: TarjetaInfo(
                  etiqueta: 'Ubicación',
                  valor: producto.ubicacionBodega ?? '—',
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: TarjetaInfo(
                  etiqueta: 'Unidad de medida',
                  valor: producto.unidadMedidaNombre ?? '—',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bloque "Compatibilidad" del diseño.
///
/// El modelo `Producto` no tiene todavía un campo de motos compatibles, así
/// que el bloque queda como marcador hasta que exista en el backend.
class _Compatibilidad extends StatelessWidget {
  const _Compatibilidad({required this.descripcion});

  final String? descripcion;

  @override
  Widget build(BuildContext context) {
    final texto = descripcion?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Compatibilidad',
          style: TipografiaApp.caption.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (texto.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: ColoresApp.bgInput,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: ColoresApp.borderFila),
            ),
            child: Text(
              'Sin información de compatibilidad',
              style: TipografiaApp.caption.copyWith(
                color: ColoresApp.textDisabled,
              ),
            ),
          )
        else
          Text(texto, style: TipografiaApp.caption.copyWith(fontSize: 13)),
      ],
    );
  }
}

/// Paneles inferiores: proveedor y movimientos recientes.
class _PanelesSecundarios extends StatelessWidget {
  const _PanelesSecundarios({required this.producto});

  final Producto producto;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final proveedor = _PanelProveedor(producto: producto);
        final movimientos = PanelMovimientosProducto(productoId: producto.id!);

        // En ventanas angostas los dos paneles se apilan.
        if (constraints.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              proveedor,
              const SizedBox(height: 22),
              movimientos,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: proveedor),
            const SizedBox(width: 22),
            Expanded(child: movimientos),
          ],
        );
      },
    );
  }
}

class _PanelProveedor extends StatelessWidget {
  const _PanelProveedor({required this.producto});

  final Producto producto;

  @override
  Widget build(BuildContext context) {
    return PanelSeccion(
      titulo: 'Proveedor',
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: ColoresApp.statusInfoBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              color: ColoresApp.statusInfo,
              size: 21,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto.proveedorNombre ?? 'Sin proveedor asignado',
                  style: TipografiaApp.tituloTarjeta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Precio de compra: ${formatearPrecio(producto.precioCompra)}',
                  style: TipografiaApp.caption.copyWith(
                    color: ColoresApp.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
