import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/features/autenticacion/vista/registro/tarjeta_registro.dart';
import 'package:provider/provider.dart';

import '../../../../../backend/share/database/locator.dart';
import '../../../../share/temas/colores_app.dart';
import '../../view_model/registro_view_model.dart';

/// Punto de entrada de la pantalla de registro.
///
/// Responsabilidades de este archivo (y solo estas):
///   1. Montar el Scaffold con su fondo.
///   2. Proveer el [RegistroViewModel] al árbol.
///   3. Orquestar el efecto secundario de "registro completado"
///      (SnackBar + callback / pop) sin interferir con el ciclo de build.
class RegistroVista extends StatefulWidget {
  final VoidCallback? alCompletarRegistro;
  const RegistroVista({super.key, this.alCompletarRegistro});

  @override
  State<RegistroVista> createState() => _RegistroVistaState();
}

class _RegistroVistaState extends State<RegistroVista> {
  late final RegistroViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = locator<RegistroViewModel>();
  }

  /// Reacciona al estado `completado` fuera del ciclo de build
  /// usando addPostFrameCallback, evitando el error
  /// "setState/markNeedsBuild called during build".
  void _onRegistroCompletado(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Cuenta creada! Ya puedes iniciar sesión.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      if (widget.alCompletarRegistro != null) {
        widget.alCompletarRegistro!();
      } else {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RegistroViewModel>.value(
      value: _vm,
      child: Scaffold(
        backgroundColor: ColoresApp.bgDark,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              // Consumer acotado: solo reacciona al estado `completado`.
              // TarjetaRegistro tiene su propio context.watch para el resto.
              child: Consumer<RegistroViewModel>(
                builder: (context, vm, child) {
                  if (vm.paso == PasoRegistro.completado) {
                    _onRegistroCompletado(context);
                  }
                  // child es la TarjetaRegistro pre-construida: no se
                  // reconstruye cuando el Consumer reacciona al estado completado.
                  return child!;
                },
                child: TarjetaRegistro(
                  alVolverLogin: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}