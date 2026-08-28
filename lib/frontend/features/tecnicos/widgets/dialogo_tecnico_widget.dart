import 'package:flutter/material.dart';

import '../../../../backend/features/tecnicos/modelo/tecnico.dart';
import '../../../share/share.dart';
import 'formulario_tecnico.dart';

/// Diálogo de alta y edición de un técnico.
///
/// Existe para los módulos que necesitan crear o editar un técnico sin salir
/// de su pantalla (cotizaciones, facturas, órdenes). El módulo de Técnicos
/// usa la página `TecnicoFormularioVista` en su lugar.
///
/// Ambos comparten el mismo [FormularioTecnico], así que la lógica del
/// formulario no está duplicada.
class DialogoTecnico extends StatelessWidget {
  const DialogoTecnico({super.key, this.tecnicoAEditar});

  final Tecnico? tecnicoAEditar;

  bool get esEdicion => tecnicoAEditar != null;

  static Future<void> mostrar(
    BuildContext context, {
    Tecnico? tecnicoAEditar,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoTecnico(tecnicoAEditar: tecnicoAEditar),
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
                      Icons.engineering_outlined,
                      color: ColoresApp.goGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      esEdicion ? 'Editar técnico' : 'Nuevo técnico',
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
                child: FormularioTecnico(
                  tecnicoAEditar: tecnicoAEditar,
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
