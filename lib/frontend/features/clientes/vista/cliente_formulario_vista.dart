import 'package:flutter/material.dart';

import '../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../share2/share2.dart';
import '../widgets/formulario_cliente.dart';

/// Página de alta y edición de un cliente.
///
/// Solo aporta el marco de la página (volver, título y ancho máximo); el
/// formulario en sí es [FormularioCliente]. Es página y no diálogo, igual que
/// en Productos, Proveedores y Técnicos: aquí además se administran las motos
/// del cliente, que en un modal quedarían apretadas.
class ClienteFormularioVista extends StatelessWidget {
  const ClienteFormularioVista({
    super.key,
    this.clienteAEditar,
    required this.alCerrar,
  });

  final Cliente? clienteAEditar;
  final VoidCallback alCerrar;

  bool get _esEdicion => clienteAEditar != null;

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
              _esEdicion ? 'Editar cliente' : 'Nuevo cliente',
              style: TipografiaApp.heading1,
            ),
            const SizedBox(height: 4),
            const Text(
              'Información de contacto y vehículos asociados',
              style: TipografiaApp.subtituloPagina,
            ),
            const SizedBox(height: 24),
            FormularioCliente(
              clienteAEditar: clienteAEditar,
              alTerminar: alCerrar,
              alCancelar: alCerrar,
            ),
          ],
        ),
      ),
    );
  }
}
