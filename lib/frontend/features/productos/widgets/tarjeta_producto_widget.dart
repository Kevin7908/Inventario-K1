import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventario_k1/frontend/features/productos/widgets/badget_estado_stock_widget.dart';

import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/botones/accion_boton.dart';

class TarjetaProductoWidget extends StatefulWidget {
  const TarjetaProductoWidget({
    super.key,
    required this.producto,
    this.alEditar,
    this.alEliminar,
    this.alVerDetalle,
    this.alTap,
  });

  final Producto producto;
  final VoidCallback? alEditar;
  final VoidCallback? alEliminar;
  final VoidCallback? alVerDetalle;
  /// Si se proporciona, sobrescribe la acción de tap sobre la tarjeta
  /// (mantiene alVerDetalle solo para el botón de ojo).
  final VoidCallback? alTap;

  @override
  State<TarjetaProductoWidget> createState() => _TarjetaProductoWidgetState();
}

class _TarjetaProductoWidgetState extends State<TarjetaProductoWidget> {
  bool _hovering = false;

  static final _fmt = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final p = widget.producto;

    return RepaintBoundary(
      child: Opacity(
        opacity: p.activo ? 1.0 : 0.5,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: GestureDetector(
            onTap: widget.alTap ?? widget.alVerDetalle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: p.activo ? ColoresApp.bgCard : ColoresApp.bgContent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: !p.activo
                      ? ColoresApp.border
                      : _hovering
                          ? ColoresApp.primary.withValues(alpha: 0.55)
                          : ColoresApp.border,
                  width: _hovering && p.activo ? 1.5 : 1.0,
                ),
              ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Imagen + badge de stock
                  _ImagenConBadge(producto: p),

                  const SizedBox(height: 12),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          p.nombre,
                          style: const TextStyle(
                            color: ColoresApp.textDark,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(width: 8),

                      BadgeEstadoStock(estado: p.estadoStock,),
                    ],
                  ),

                  // SKU
                  Text(
                    'SKU: ${p.sku}',
                    style: const TextStyle(
                      color: ColoresApp.textLight,
                      fontSize: 11,
                    ),
                  ),

                  if (p.categoriaNombre != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      p.categoriaNombre!,
                      style: const TextStyle(
                        color: ColoresApp.textLight,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const Spacer(),

                  const Divider(height: 1, color: ColoresApp.border),
                  const SizedBox(height: 10),

                  // Precio + stock
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _fmt.format(p.precioVenta),
                        style: const TextStyle(
                          color: ColoresApp.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      _BadgeUnidades(
                        stock: p.stockActual,
                        unidad: p.unidadMedidaNombre,
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  const Divider(height: 1, color: ColoresApp.border),
                  const SizedBox(height: 8),

                  // Botones de acción
                  Row(
                    children: [
                      AccionBoton(
                        icono: Icons.visibility_outlined,
                        alPresionar: widget.alVerDetalle,
                        tooltip: 'Ver detalle',
                      ),
                      const Spacer(),
                      AccionBoton(
                        icono: Icons.edit_outlined,
                        alPresionar: widget.alEditar,
                        tooltip: 'Editar',
                      ),
                      const SizedBox(width: 8),
                      AccionBoton(
                        icono: Icons.delete_outline_rounded,
                        alPresionar: widget.alEliminar,
                        tooltip: 'Eliminar',
                        esDestructivo: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }
}

// Subwidget: imagen con badge de stock

class _ImagenConBadge extends StatelessWidget {
  const _ImagenConBadge({required this.producto});

  final Producto producto;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 110,
            width: double.infinity,
            color: ColoresApp.bgContent,
            child: _buildImagen(),
          ),
        ),
        // Positioned(
        //   top: 6,
        //   right: 6,
        //   child: BadgeEstadoStock(estado: producto.estadoStock),
        // ),
      ],
    );
  }

  Widget _buildImagen() {
    final ruta = producto.imagenUrl;
    if (ruta == null || ruta.isEmpty) {
      return const Center(
        child: Icon(
          Icons.inventory_2_outlined,
          size: 36,
          color: ColoresApp.textLight,
        ),
      );
    }

    if (ruta.startsWith('http://') || ruta.startsWith('https://')) {
      return Image.network(
        ruta,
        fit: BoxFit.cover,
        // Para imágenes de red también limitamos el cache en memoria
        cacheWidth: 250,
        errorBuilder: (context, e, st) => const Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: 28,
            color: ColoresApp.textLight,
          ),
        ),
      );
    }

    return Image.file(
      File(ruta),
      fit: BoxFit.cover,
      cacheWidth: 300,
      errorBuilder: (context, e, st) => const Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 28,
          color: ColoresApp.textLight,
        ),
      ),
    );
  }
}

class _BadgeUnidades extends StatelessWidget {
  const _BadgeUnidades({required this.stock, this.unidad});

  final double stock;
  final String? unidad;

  @override
  Widget build(BuildContext context) {
    final stockStr = stock == stock.truncateToDouble()
        ? stock.toInt().toString()
        : stock.toStringAsFixed(1);

    return Text(
      '$stockStr ${'uds'}',
      style: const TextStyle(
        color: ColoresApp.textMedium,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
