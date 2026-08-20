import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Tarjeta de producto de las rejillas de venta: foto, código, nombre, un dato
/// secundario, precio y botón de agregar.
///
/// Es la tarjeta del punto de venta del diseño (`minmax(210px, 1fr)`, gap 16).
/// Se usa dondequiera que se arme un documento eligiendo productos —punto de
/// venta, cotizaciones, órdenes, facturas—, así que no sabe nada del modelo:
/// recibe los textos **ya resueltos y ya formateados**. El precio llega como
/// `String` porque share2 no puede depender de `intl`; quien la usa le pasa
/// `formatearPrecio`.
///
/// La foto también llega de fuera, en [imagen]: leer un archivo del disco es
/// cosa del módulo, no de un widget compartido. Si no se pasa ninguna, se
/// pinta el marcador con [iconoVacio].
///
/// Parámetros:
/// - [nombre]: título del producto. Hasta dos líneas.
/// - [precio]: precio ya formateado (`'$32.000'`).
/// - [codigo]: se pinta como etiqueta sobre la foto (el SKU). Opcional.
/// - [ubicacion]: dónde está guardado ("Estante A-3"). Se pinta como etiqueta
///   sobre la foto, arriba a la derecha, con un ícono de pin. Va ahí y no en
///   una línea propia porque quien arma un documento necesita el dato para ir
///   a buscar la pieza, pero no puede costarle alto a la tarjeta: la rejilla
///   reserva [altoSugerido] exacto. Opcional.
/// - [detalle]: línea tenue bajo el nombre ("12 en stock"). Opcional.
/// - [colorDetalle]: color de esa línea, para marcar stock bajo o agotado.
/// - [imagen]: widget de la foto. Si es `null`, marcador con [iconoVacio].
/// - [alAgregar]: acción del botón verde. Si es `null`, el botón se ve
///   deshabilitado.
/// - [etiquetaAgregar]: tooltip del botón. Obligatorio: es un botón de solo
///   ícono.
/// - [alPresionar]: acción al tocar la tarjeta entera. Opcional.
///
/// Ejemplo:
/// ```dart
/// TarjetaProducto(
///   nombre: producto.nombre,
///   codigo: producto.sku,
///   detalle: '${producto.stockActual} en stock',
///   precio: formatearPrecio(producto.precioVenta),
///   imagen: MiniaturaProducto(rutaImagen: producto.imagenUrl),
///   etiquetaAgregar: 'Agregar a la cotización',
///   alAgregar: () => notifier.agregarProducto(producto),
/// )
/// ```
class TarjetaProducto extends StatelessWidget {
  const TarjetaProducto({
    super.key,
    required this.nombre,
    required this.precio,
    required this.etiquetaAgregar,
    this.codigo,
    this.ubicacion,
    this.detalle,
    this.colorDetalle,
    this.imagen,
    this.iconoVacio = Icons.image_outlined,
    this.alAgregar,
    this.alPresionar,
  });

  /// Alto que hay que reservarle en la rejilla.
  ///
  /// Sale de sumar lo que ocupa el contenido en el peor caso: 28 de padding +
  /// 120 de foto + 13 + 36,4 del nombre en dos líneas + 3 + 16,1 del detalle +
  /// 38 del botón = 254,5. Quedarse corto no recorta la tarjeta: desborda el
  /// `Column` y Flutter pinta la franja amarilla y negra.
  static const double altoSugerido = 256;

  /// Ancho mínimo de columna del diseño.
  static const double anchoMinimo = 210;

  final String nombre;
  final String precio;
  final String etiquetaAgregar;
  final String? codigo;
  final String? ubicacion;
  final String? detalle;
  final Color? colorDetalle;
  final Widget? imagen;
  final IconData iconoVacio;
  final VoidCallback? alAgregar;
  final VoidCallback? alPresionar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColoresApp.bgCard,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alPresionar,
        hoverColor: ColoresApp.bgCardHover,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ColoresApp.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Foto(
                imagen: imagen,
                iconoVacio: iconoVacio,
                codigo: codigo,
                ubicacion: ubicacion,
              ),
              const SizedBox(height: 13),
              Text(
                nombre,
                style: TipografiaApp.tituloTarjeta,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (detalle != null) ...[
                const SizedBox(height: 3),
                Text(
                  detalle!,
                  style: TipografiaApp.caption.copyWith(
                    fontSize: 11.5,
                    color: colorDetalle ?? ColoresApp.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      precio,
                      style: TipografiaApp.heading3.copyWith(
                        fontSize: 16,
                        color: ColoresApp.castletonGreen,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _BotonAgregar(
                    tooltip: etiquetaAgregar,
                    alPresionar: alAgregar,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cuadro de la foto con la etiqueta del código encima.
class _Foto extends StatelessWidget {
  const _Foto({
    required this.imagen,
    required this.iconoVacio,
    required this.codigo,
    required this.ubicacion,
  });

  final Widget? imagen;
  final IconData iconoVacio;
  final String? codigo;
  final String? ubicacion;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: ColoresApp.bgInput,
              borderRadius: BorderRadius.circular(13),
            ),
            child: imagen == null
                ? Icon(iconoVacio, size: 30, color: ColoresApp.textDisabled)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: imagen,
                  ),
          ),
          if (codigo != null && codigo!.isNotEmpty)
            Positioned(
              top: 9,
              left: 9,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ColoresApp.bgCard,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  codigo!,
                  style: TipografiaApp.monoespaciada(
                    TipografiaApp.caption.copyWith(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          if (ubicacion != null && ubicacion!.isNotEmpty)
            Positioned(
              // Enfrentada al código, en la esquina libre: las dos etiquetas
              // caben sin pisarse mientras la foto mida los 120 de siempre.
              top: 9,
              right: 9,
              // Deja 12 px de aire hacia el SKU. Una ubicación larga se
              // recorta antes que empujar a la otra etiqueta.
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 108),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: ColoresApp.bgCard,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 11,
                        color: ColoresApp.textMuted,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          ubicacion!,
                          style: TipografiaApp.caption.copyWith(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: ColoresApp.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Botón verde de 38×38 del diseño.
class _BotonAgregar extends StatelessWidget {
  const _BotonAgregar({required this.tooltip, required this.alPresionar});

  final String tooltip;
  final VoidCallback? alPresionar;

  @override
  Widget build(BuildContext context) {
    final deshabilitado = alPresionar == null;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: deshabilitado ? ColoresApp.border : ColoresApp.goGreen,
        borderRadius: BorderRadius.circular(11),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alPresionar,
          hoverColor: ColoresApp.castletonGreen,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(
              Icons.add_rounded,
              size: 20,
              color: deshabilitado
                  ? ColoresApp.textDisabled
                  : ColoresApp.textOnPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
