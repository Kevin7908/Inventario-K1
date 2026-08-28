import 'package:flutter/material.dart';

import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../share/share.dart';
import '../vista/producto_detalle_vista.dart';

/// Ficha de un producto dentro de un diálogo.
///
/// La usan los módulos que necesitan consultar un producto sin salir de su
/// pantalla (cotizaciones, detalle de categoría). El módulo de Productos
/// muestra esa misma ficha como página completa.
///
/// El contenido es [ProductoDetalleVista], así que no hay dos versiones del
/// detalle que mantener sincronizadas: aquí solo se le pone el marco de
/// diálogo y el botón de cerrar.
class DialogoDetalleProductoWidget extends StatelessWidget {
  const DialogoDetalleProductoWidget({super.key, required this.producto});

  final Producto producto;

  static void mostrar(BuildContext context, {required Producto producto}) {
    showDialog(
      context: context,
      builder: (_) => DialogoDetalleProductoWidget(producto: producto),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 860,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: ColoresApp.bgCard,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: ColoresApp.shadowMedium,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Detalle del producto',
                      style: TipografiaApp.heading3,
                    ),
                  ),
                  BotonIcono(
                    icono: Icons.close_rounded,
                    tooltip: 'Cerrar',
                    alPresionar: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ProductoDetalleVista(
                producto: producto,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
