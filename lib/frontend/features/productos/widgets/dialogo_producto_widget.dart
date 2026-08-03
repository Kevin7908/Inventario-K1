import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../share2/share2.dart';
import '../../proveedores/view_model/proveedores_view_model.dart';
import 'formulario_producto.dart';

/// Diálogo de alta y edición de un producto.
///
/// Existe para los módulos que necesitan crear o editar un producto sin salir
/// de su pantalla (cotizaciones, facturas, órdenes, detalle de categoría). El
/// módulo de Productos usa la página `ProductoFormularioVista` en su lugar.
///
/// Ambos comparten el mismo [FormularioProducto], así que la lógica del
/// formulario no está duplicada.
class DialogoProducto extends StatelessWidget {
  const DialogoProducto({
    super.key,
    this.productoAEditar,
    required this.proveedoresVm,
  });

  final Producto? productoAEditar;
  final ProveedoresViewModel proveedoresVm;

  bool get esEdicion => productoAEditar != null;

  static Future<void> mostrar(
    BuildContext context, {
    Producto? productoAEditar,
    required ProveedoresViewModel proveedoresVm,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider.value(
        value: proveedoresVm,
        child: DialogoProducto(
          productoAEditar: productoAEditar,
          proveedoresVm: proveedoresVm,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 720,
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
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: ColoresApp.greenChipBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: ColoresApp.goGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      esEdicion ? 'Editar producto' : 'Nuevo producto',
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: FormularioProducto(
                  productoAEditar: productoAEditar,
                  proveedoresVm: proveedoresVm,
                  alTerminar: () => Navigator.of(context).pop(),
                  alCancelar: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
