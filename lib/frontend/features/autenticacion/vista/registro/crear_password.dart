import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/features/autenticacion/vista/registro/decoracion_registro.dart';
import 'package:provider/provider.dart';

import '../../../../share/temas/colores_app.dart';
import '../../../../share/widgets/botones/boton_cargando_widget.dart';
import '../../view_model/registro_view_model.dart';
import '../../widget/text_field_custom.dart';

class PasoCrearPassword extends StatefulWidget {
  const PasoCrearPassword({super.key});

  @override
  State<PasoCrearPassword> createState() => _PasoCrearPasswordState();
}

class _PasoCrearPasswordState extends State<PasoCrearPassword> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  // ValueNotifier: toggle de visibilidad sin setState en el widget padre.
  final _verPassword = ValueNotifier<bool>(false);
  final _verConfirm = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _passwordFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    _verPassword.dispose();
    _verConfirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await context
        .read<RegistroViewModel>()
        .crearUsuario(password: _passwordCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistroViewModel>(
      builder: (_, vm, __) => Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumen del usuario verificado
            _ResumenUsuario(
              nombre: vm.nombreGuardado,
              usuario: vm.usuarioGuardado,
              email: vm.emailGuardado,
            ),
            const SizedBox(height: 20),

            TextFieldCustom(
              etiqueta: 'Contraseña',
              hint: '••••••••',
              controlador: _passwordCtrl,
              focusNode: _passwordFocus,
              siguienteFoco: _confirmFocus,
              mostrarPasswordNotifier: _verPassword,
              iconoPrefijo: Icons.lock_outline,
              validador: (v) {
                if (v == null || v.isEmpty) return 'La contraseña es requerida';
                if (v.length < 6) return 'Mínimo 6 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFieldCustom(
              etiqueta: 'Confirmar contraseña',
              hint: '••••••••',
              controlador: _confirmCtrl,
              focusNode: _confirmFocus,
              mostrarPasswordNotifier: _verConfirm,
              iconoPrefijo: Icons.lock_outline,
              alPresionarEnter: _submit,
              validador: (v) {
                if (v == null || v.isEmpty) return 'Confirma tu contraseña';
                if (v != _passwordCtrl.text) return 'Las contraseñas no coinciden';
                return null;
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'Presiona Enter para crear la cuenta',
              style: TextStyle(fontSize: 11, color: ColoresApp.textLight),
            ),
            const SizedBox(height: 24),

            if (vm.mensajeError != null) ...[
              BannerError(mensaje: vm.mensajeError!),
              const SizedBox(height: 16),
            ],

            BotonCargando(
              etiqueta: 'Crear cuenta',
              estaCargando: vm.estaCargando,
              alPresionar: _submit,
              icono: Icons.person_add_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widget estático: se renderiza una sola vez ───────────────────────────

class _ResumenUsuario extends StatelessWidget {
  final String nombre;
  final String usuario;
  final String email;

  const _ResumenUsuario({
    required this.nombre,
    required this.usuario,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ColoresApp.bgContent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColoresApp.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              size: 16, color: ColoresApp.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ColoresApp.textDark),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '@$usuario · $email',
                  style: const TextStyle(
                      fontSize: 12, color: ColoresApp.textMedium),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}