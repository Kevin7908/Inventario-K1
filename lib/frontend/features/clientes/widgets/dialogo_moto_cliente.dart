import 'package:flutter/material.dart';

import '../../../../backend/features/motos/modelo/moto.dart';
import '../../../share/share.dart';
import '../../motos/widgets/formulario_moto.dart';

/// Diálogo con los datos de **una** moto del cliente.
///
/// Devuelve la moto editada al cerrarse con "Guardar", o `null` si se cancela.
/// No toca la base de datos: el alta real la hace el formulario del cliente,
/// que guarda cliente y motos en una sola transacción. Por eso aquí no se
/// elige dueño —lo es el cliente que se está editando— y solo se valida el
/// formato de los campos; que la placa ya tenga dueño lo comprueba
/// `validarCliente` al guardar, que es quien puede consultar el repositorio.
///
/// Los campos los pone [FormularioMoto], el mismo widget que usa el catálogo
/// de Motos: la diferencia entre los dos diálogos es qué hacen con el
/// resultado, no qué preguntan.
///
/// Parámetros:
/// - [motoAEditar]: moto a modificar. Si es `null`, crea una nueva.
///
/// Ejemplo:
/// ```dart
/// final moto = await DialogoMotoCliente.mostrar(context);
/// if (moto != null) setState(() => _motos.add(moto));
/// ```
class DialogoMotoCliente extends StatelessWidget {
  const DialogoMotoCliente({super.key, this.motoAEditar});

  final Moto? motoAEditar;

  bool get esEdicion => motoAEditar != null;

  static Future<Moto?> mostrar(BuildContext context, {Moto? motoAEditar}) {
    return showDialog<Moto>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoMotoCliente(motoAEditar: motoAEditar),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 640,
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
                    icono: Icons.two_wheeler_outlined,
                    lado: 42,
                    radio: 12,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      esEdicion ? 'Editar moto' : 'Agregar moto',
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
                child: FormularioMoto(
                  motoAEditar: motoAEditar,
                  alGuardar: (moto) => Navigator.of(context).pop(moto),
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
