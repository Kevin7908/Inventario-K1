import 'package:flutter/material.dart';

import '../../../../backend/features/tecnicos/modelo/tecnico.dart';
import '../../../share2/share2.dart';
import '../widgets/formulario_tecnico.dart';

/// Página de alta y edición de un técnico.
///
/// Solo aporta el marco de la página (volver, título y ancho máximo); el
/// formulario en sí es [FormularioTecnico]. Es página y no diálogo, igual
/// que en Productos y Proveedores.
class TecnicoFormularioVista extends StatelessWidget {
  const TecnicoFormularioVista({
    super.key,
    this.tecnicoAEditar,
    required this.alCerrar,
  });

  final Tecnico? tecnicoAEditar;
  final VoidCallback alCerrar;

  bool get _esEdicion => tecnicoAEditar != null;

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
              _esEdicion ? 'Editar técnico' : 'Nuevo técnico',
              style: TipografiaApp.heading1,
            ),
            const SizedBox(height: 4),
            const Text(
              'Datos del personal mecánico del taller',
              style: TipografiaApp.subtituloPagina,
            ),
            const SizedBox(height: 24),
            FormularioTecnico(
              tecnicoAEditar: tecnicoAEditar,
              alTerminar: alCerrar,
              alCancelar: alCerrar,
            ),
          ],
        ),
      ),
    );
  }
}
