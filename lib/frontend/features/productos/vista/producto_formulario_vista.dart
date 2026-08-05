import 'package:flutter/material.dart';

import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../../backend/share/database/locator.dart';
import '../../../share2/share2.dart';
import '../../proveedores/view_model/proveedores_view_model.dart';
import '../widgets/formulario_producto.dart';

/// Página de alta y edición de un producto.
///
/// Solo aporta el marco de la página (volver, título y ancho máximo); el
/// formulario en sí es [FormularioProducto], compartido con `DialogoProducto`.
class ProductoFormularioVista extends StatelessWidget {
  const ProductoFormularioVista({
    super.key,
    this.productoAEditar,
    required this.alCerrar,
  });

  final Producto? productoAEditar;
  final VoidCallback alCerrar;

  bool get _esEdicion => productoAEditar != null;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: alCerrar,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.arrow_back_rounded,
                        size: 16,
                        color: ColoresApp.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Cancelar',
                        style: TipografiaApp.caption.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ColoresApp.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _esEdicion ? 'Editar producto' : 'Nuevo producto',
              style: TipografiaApp.heading1,
            ),
            const SizedBox(height: 4),
            const Text(
              'Completa la información del repuesto',
              style: TipografiaApp.subtituloPagina,
            ),
            const SizedBox(height: 24),
            FormularioProducto(
              productoAEditar: productoAEditar,
              proveedoresVm: locator<ProveedoresViewModel>(),
              alTerminar: alCerrar,
              alCancelar: alCerrar,
            ),
          ],
        ),
      ),
    );
  }
}
