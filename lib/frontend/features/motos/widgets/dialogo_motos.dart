import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/motos/modelo/moto.dart';
import '../../../../core/resultado.dart';
import '../../../share2/share2.dart';
import '../../clientes/provider/cliente_provider.dart';
import '../../clientes/widgets/dialogo_cliente_widget.dart';
import '../provider/motos_provider.dart';
import 'formulario_moto.dart';

/// Alta y edición de una moto **que se guarda al confirmar**.
///
/// Es el diálogo que abren el catálogo de Motos y —sin salir de su pantalla—
/// las órdenes, las reservas y las cotizaciones. Reutiliza [FormularioMoto],
/// igual que `DialogoCliente` reutiliza `FormularioCliente`: los campos y su
/// validación de formato están en un solo sitio.
///
/// A diferencia de `DialogoMotoCliente`, aquí el dueño se elige a mano y la
/// moto se persiste de inmediato.
///
/// Parámetros:
/// - [moto]: moto a modificar. Si es `null`, crea una nueva.
///
/// Ejemplo:
/// ```dart
/// await DialogoMoto.mostrar(context);
/// ```
class DialogoMoto extends ConsumerStatefulWidget {
  const DialogoMoto({super.key, this.moto});

  final Moto? moto;

  bool get esEdicion => moto != null;

  static Future<void> mostrar(BuildContext context, {Moto? moto}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoMoto(moto: moto),
    );
  }

  @override
  ConsumerState<DialogoMoto> createState() => _DialogoMotoState();
}

class _DialogoMotoState extends ConsumerState<DialogoMoto> {
  bool _guardando = false;

  void _mensaje(String texto, {required bool esError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          texto,
          style: TipografiaApp.sobrePrimario(TipografiaApp.cuerpo),
        ),
        backgroundColor:
            esError ? ColoresApp.statusDanger : ColoresApp.statusSuccess,
      ),
    );
  }

  Future<void> _guardar(Moto moto) async {
    setState(() => _guardando = true);

    final resultado = await ref.read(motosProvider.notifier).guardar(moto);
    if (!mounted) return;

    if (resultado case Fallo(:final mensaje)) {
      _mensaje(mensaje, esError: true);
      setState(() => _guardando = false);
      return;
    }

    Navigator.of(context).pop();
    _mensaje(
      widget.esEdicion
          ? 'Moto actualizada correctamente.'
          : 'Moto agregada correctamente.',
      esError: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientes = ref.watch(catalogoClientesProvider).value ?? const [];
    final previa = widget.moto;
    final dueno = previa == null
        ? null
        : clientes.where((c) => c.id == previa.clienteId).firstOrNull;

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
            _Encabezado(
              esEdicion: widget.esEdicion,
              alCerrar: _guardando ? null : () => Navigator.of(context).pop(),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: FormularioMoto(
                  motoAEditar: previa,
                  clientes: clientes,
                  clienteInicial: dueno,
                  mostrarEstado: true,
                  guardando: _guardando,
                  alGuardar: _guardar,
                  alCancelar: () => Navigator.of(context).pop(),
                  alAgregarCliente: () => DialogoCliente.mostrar(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.esEdicion, required this.alCerrar});

  final bool esEdicion;
  final VoidCallback? alCerrar;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            alPresionar: alCerrar,
          ),
        ],
      ),
    );
  }
}
