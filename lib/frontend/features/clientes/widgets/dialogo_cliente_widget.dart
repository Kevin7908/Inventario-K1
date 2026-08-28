import 'package:flutter/material.dart';

import '../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../share/share.dart';
import 'formulario_cliente.dart';

/// Diálogo de alta y edición de un cliente.
///
/// Existe para los módulos que necesitan crear un cliente sin salir de su
/// pantalla (deudores, facturas, el alta de motos). El módulo de Clientes usa
/// la página `ClienteFormularioVista` en su lugar.
///
/// Ambos comparten el mismo [FormularioCliente], así que la lógica del
/// formulario —y la regla de que una moto no puede tener dos dueños— no está
/// duplicada.
class DialogoCliente extends StatelessWidget {
  const DialogoCliente({super.key, this.cliente});

  final Cliente? cliente;

  bool get esEdicion => cliente != null;

  static Future<void> mostrar(BuildContext context, {Cliente? cliente}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoCliente(cliente: cliente),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 760,
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
                  const MarcadorIdentidad(
                    icono: Icons.person_outline_rounded,
                    lado: 42,
                    radio: 12,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      esEdicion ? 'Editar cliente' : 'Nuevo cliente',
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
                child: FormularioCliente(
                  clienteAEditar: cliente,
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
