import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventario_k1/frontend/features/autenticacion/vista/registro/decoracion_registro.dart';
import 'package:provider/provider.dart';

import '../../../../share/temas/colores_app.dart';
import '../../../../share/widgets/botones/boton_cargando_widget.dart';
import '../../view_model/registro_view_model.dart';
import '../../widget/text_field_custom.dart';

class PasoDatosIniciales extends StatefulWidget {
  const PasoDatosIniciales({super.key});

  @override
  State<PasoDatosIniciales> createState() => _PasoDatosInicialesState();
}

class _PasoDatosInicialesState extends State<PasoDatosIniciales> {
  final _formKey = GlobalKey<FormState>();

  final _nombreCtrl  = TextEditingController();
  final _usuarioCtrl = TextEditingController();
  final _emailCtrl   = TextEditingController();

  final _nombreFocus  = FocusNode();
  final _usuarioFocus = FocusNode();
  final _emailFocus   = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = context.read<RegistroViewModel>();
      _nombreCtrl.text  = vm.nombreGuardado;
      _usuarioCtrl.text = vm.usuarioGuardado;
      _emailCtrl.text   = vm.emailGuardado;
      _nombreFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _usuarioCtrl.dispose();
    _emailCtrl.dispose();
    _nombreFocus.dispose();
    _usuarioFocus.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await context.read<RegistroViewModel>().enviarCodigoVerificacion(
          nombre:  _nombreCtrl.text,
          usuario: _usuarioCtrl.text,
          email:   _emailCtrl.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistroViewModel>(
      builder: (_, vm, __) => Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nombre completo
            TextFieldCustom(
              etiqueta: 'Nombre completo',
              hint: 'Juan García',
              controlador: _nombreCtrl,
              focusNode: _nombreFocus,
              siguienteFoco: _usuarioFocus,
              iconoPrefijo: Icons.badge_outlined,
              validador: (v) {
                if (v == null || v.trim().isEmpty) return 'El nombre es requerido';
                if (v.trim().length < 2) return 'Mínimo 2 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Nombre de usuario
            TextFieldCustom(
              etiqueta: 'Nombre de usuario',
              hint: 'juangarcia',
              controlador: _usuarioCtrl,
              focusNode: _usuarioFocus,
              siguienteFoco: _emailFocus,
              iconoPrefijo: Icons.alternate_email,
              formatters: [_UsuarioInputFormatter()],
              validador: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'El nombre de usuario es requerido';
                }
                if (v.trim().length < 3) return 'Mínimo 3 caracteres';
                if (v.trim().length > 50) return 'Máximo 50 caracteres';
                if (!RegExp(r'^[a-z0-9_]+$').hasMatch(v.trim())) {
                  return 'Solo letras minúsculas, números y _';
                }
                return null;
              },
            ),
            const SizedBox(height: 4),
            const Text(
              'Solo letras minúsculas, números y guión bajo. Ej: juan_99',
              style: TextStyle(fontSize: 11, color: ColoresApp.textLight),
            ),
            const SizedBox(height: 12),

            // Correo electrónico
            TextFieldCustom(
              etiqueta: 'Correo electrónico',
              hint: 'tu@correo.com',
              controlador: _emailCtrl,
              focusNode: _emailFocus,
              tipoTeclado: TextInputType.emailAddress,
              iconoPrefijo: Icons.email_outlined,
              alPresionarEnter: _submit,
              validador: (v) {
                if (v == null || v.trim().isEmpty) return 'El correo es requerido';
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim())) {
                  return 'Ingresa un correo válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'Te enviaremos un código de 6 dígitos para verificar tu correo.',
              style: TextStyle(fontSize: 12, color: ColoresApp.textLight),
            ),
            const SizedBox(height: 24),

            if (vm.mensajeError != null) ...[
              BannerError(mensaje: vm.mensajeError!),
              const SizedBox(height: 16),
            ],

            BotonCargando(
              etiqueta: 'Enviar código de verificación',
              estaCargando: vm.estaCargando,
              alPresionar: _submit,
              icono: Icons.send_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

// Formatter: fuerza minúsculas y solo permite [a-z0-9_]

class _UsuarioInputFormatter extends TextInputFormatter {
  static final _permitidos = RegExp(r'[a-z0-9_]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtrado = newValue.text
        .toLowerCase()
        .split('')
        .where((c) => _permitidos.hasMatch(c))
        .join();

    final offset = filtrado.length < newValue.selection.baseOffset
        ? filtrado.length
        : newValue.selection.baseOffset;

    return newValue.copyWith(
      text: filtrado,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}