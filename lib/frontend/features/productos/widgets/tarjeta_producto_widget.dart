import 'package:flutter/material.dart';

import '../../../../core/formato.dart';

import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../share2/share2.dart';
import '../vista/producto_vista.dart';
import 'badget_estado_stock_widget.dart';

/// Tarjeta de un producto para grillas.
///
/// El catálogo de Productos usa tabla, pero varios módulos siguen mostrando
/// productos como tarjetas para elegirlos (reservas, cotizaciones, venta
/// rápida, detalle de categoría), así que esta tarjeta sigue viva.
///
/// Parámetros:
/// - [producto]: datos a mostrar.
/// - [alTap]: acción al tocar la tarjeta. Si es `null`, cae en [alVerDetalle].
/// - [alVerDetalle], [alEditar], [alEliminar]: acciones opcionales; cada botón
///   solo aparece si su callback existe.
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
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.producto;
    final hayAcciones = widget.alVerDetalle != null ||
        widget.alEditar != null ||
        widget.alEliminar != null;

    // `RepaintBoundary` sí está justificado aquí: la tarjeta se anima al pasar
    // el mouse, y sin él ese repintado se propaga a toda la grilla.
    return RepaintBoundary(
      child: _AtenuadoSiInactivo(
        activo: p.activo,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: widget.alTap ?? widget.alVerDetalle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: ColoresApp.bgCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _hover ? ColoresApp.goGreen : ColoresApp.border,
                ),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _imagen(p),
                  const SizedBox(height: 13),
                  Text(
                    p.nombre,
                    style: TipografiaApp.tituloTarjeta,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    p.stockActual > 0
                        ? '${_cantidad(p.stockActual)} disponibles'
                        : 'Agotado',
                    style: TipografiaApp.caption.copyWith(
                      fontSize: 12,
                      color: ColoresApp.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatearPrecio(p.precioVenta),
                          style: TipografiaApp.subtitulo.copyWith(
                            fontSize: 16,
                            color: ColoresApp.castletonGreen,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hayAcciones) _acciones(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _imagen(Producto p) {
    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          child: MiniaturaProducto(
            rutaImagen: p.imagenUrl,
            lado: 120,
            radio: 13,
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: ColoresApp.bgCard,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              p.sku,
              style: TipografiaApp.monoespaciada(
                TipografiaApp.caption.copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: ColoresApp.textSecondary,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: BadgeEstadoStock(estado: p.estadoStock),
        ),
      ],
    );
  }

  Widget _acciones() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.alVerDetalle != null)
          BotonIcono(
            icono: Icons.visibility_outlined,
            tooltip: 'Ver detalle',
            alPresionar: widget.alVerDetalle,
          ),
        if (widget.alEditar != null)
          BotonIcono(
            icono: Icons.edit_outlined,
            tooltip: 'Editar',
            alPresionar: widget.alEditar,
          ),
        if (widget.alEliminar != null)
          BotonIcono(
            icono: Icons.delete_outline_rounded,
            tooltip: 'Eliminar',
            color: ColoresApp.statusDanger,
            alPresionar: widget.alEliminar,
          ),
      ],
    );
  }

  String _cantidad(double v) =>
      v.truncateToDouble() == v ? v.toInt().toString() : v.toStringAsFixed(2);
}

/// Atenúa la tarjeta de un producto inactivo.
///
/// Solo inserta el `Opacity` cuando hace falta: el widget reserva un buffer
/// fuera de pantalla y el caso normal —producto activo— no debe pagarlo.
class _AtenuadoSiInactivo extends StatelessWidget {
  const _AtenuadoSiInactivo({required this.activo, required this.child});

  final bool activo;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      activo ? child : Opacity(opacity: 0.55, child: child);
}
