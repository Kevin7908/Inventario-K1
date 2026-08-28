import 'package:flutter/material.dart';

import '../../../../backend/features/proveedores/modelo/proveedor.dart';
import '../../../share2/share2.dart';
import '../widgets/formulario_proveedor.dart';

/// Página de alta y edición de un proveedor.
///
/// Solo aporta el marco de la página (volver, título y ancho máximo); el
/// formulario en sí es [FormularioProveedor]. Es página y no diálogo, igual
/// que en Productos: el formulario tiene tres bloques y no cabe cómodo en una
/// ventana modal.
class ProveedorFormularioVista extends StatelessWidget {
  const ProveedorFormularioVista({
    super.key,
    this.proveedorAEditar,
    required this.alCerrar,
  });

  final Proveedor? proveedorAEditar;
  final VoidCallback alCerrar;

  bool get _esEdicion => proveedorAEditar != null;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BotonVolver(etiqueta: 'Cancelar', alPresionar: alCerrar),
            const SizedBox(height: 18),
            Text(
              _esEdicion ? 'Editar proveedor' : 'Nuevo proveedor',
              style: TipografiaApp.heading1,
            ),
            const SizedBox(height: 4),
            const Text(
              'Datos del distribuidor o casa de repuestos',
              style: TipografiaApp.subtituloPagina,
            ),
            const SizedBox(height: 24),
            FormularioProveedor(
              proveedorAEditar: proveedorAEditar,
              alTerminar: alCerrar,
              alCancelar: alCerrar,
            ),
          ],
        ),
      ),
    );
  }
}
