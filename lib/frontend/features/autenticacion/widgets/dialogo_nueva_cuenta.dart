import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/autenticacion/resultado/resultados_auth.dart';
import '../../../../backend/share/dominio/rol_usuario.dart';
import '../../../share/share.dart';
import '../provider/usuarios_provider.dart';
import '../validacion_cuenta.dart';
import '../validacion_password.dart';

/// Alta de una cuenta desde Configuración → Usuarios.
///
/// La contraseña inicial la pone el administrador y se la entrega en persona a
/// quien va a usarla: por eso el correo de bienvenida no la lleva. Quien
/// reciba la cuenta puede cambiarla después desde «¿Olvidaste tu contraseña?».
class DialogoNuevaCuenta extends ConsumerStatefulWidget {
  const DialogoNuevaCuenta({super.key});

  /// Devuelve `true` si la cuenta se creó.
  static Future<bool?> mostrar(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (_) => const DialogoNuevaCuenta(),
      );

  @override
  ConsumerState<DialogoNuevaCuenta> createState() => _DialogoNuevaCuentaState();
}

class _DialogoNuevaCuentaState extends ConsumerState<DialogoNuevaCuenta> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _usuarioCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  RolUsuario _rol = RolUsuario.cajero;
  bool _oculta = true;
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _usuarioCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final resultado = await ref.read(accionesUsuariosProvider.notifier).crear(
          nombre: _nombreCtrl.text,
          usuario: _usuarioCtrl.text,
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
          rol: _rol,
        );

    if (!mounted) return;

    switch (resultado) {
      case CuentaCreada():
        Navigator.of(context).pop(true);
      case UsuarioEnUso():
        setState(() => _error = 'Ese nombre de usuario ya está tomado.');
      case CorreoEnUso():
        setState(() => _error = 'Ese correo ya está registrado.');
      case CuentaNoGuardada(:final detalle):
        setState(() => _error = 'No se pudo crear la cuenta: $detalle');
    }
  }

  @override
  Widget build(BuildContext context) {
    final enCurso = ref.watch(accionesUsuariosProvider);
    void cerrar() => Navigator.of(context).pop(false);

    return AtajosFormulario(
      alGuardar: enCurso ? null : _guardar,
      alCancelar: cerrar,
      child: Dialog(
        backgroundColor: ColoresApp.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nueva cuenta', style: TipografiaApp.heading3),
                  const SizedBox(height: 4),
                  const Text(
                    'La contraseña se la entregas tú en persona.',
                    style: TipografiaApp.subtituloPagina,
                  ),
                  const SizedBox(height: 22),
                  CampoTexto(
                    etiqueta: 'Nombre completo *',
                    controlador: _nombreCtrl,
                    autofocus: true,
                    validador: (v) => (v == null || v.trim().isEmpty)
                        ? 'El nombre es obligatorio.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  CampoTexto(
                    etiqueta: 'Usuario *',
                    controlador: _usuarioCtrl,
                    placeholder: 'juan.garcia',
                    validador: validarUsuario,
                  ),
                  const SizedBox(height: 14),
                  CampoTexto(
                    etiqueta: 'Correo',
                    controlador: _emailCtrl,
                    placeholder: 'juan@taller.com',
                    validador: validarCorreoOpcional,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sin correo, esta cuenta no puede recuperar su '
                    'contraseña sola.',
                    style: TipografiaApp.caption.copyWith(
                      color: ColoresApp.textMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  CampoTexto(
                    etiqueta: 'Contraseña inicial *',
                    controlador: _passwordCtrl,
                    oculto: _oculta,
                    alAlternarOculto: () =>
                        setState(() => _oculta = !_oculta),
                    validador: validarPassword,
                  ),
                  const SizedBox(height: 18),
                  GrupoRadio<RolUsuario>(
                    etiqueta: 'Rol',
                    valor: _rol,
                    opciones: RolUsuario.values,
                    constructorEtiqueta: (rol) => rol.etiqueta,
                    alCambiar: (rol) => setState(() => _rol = rol),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _rol.administraUsuarios
                        ? 'Puede crear cuentas y cambiar la configuración.'
                        : 'Vende, cotiza y atiende el taller.',
                    style: TipografiaApp.caption.copyWith(
                      color: ColoresApp.textMuted,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    AvisoEnLinea(mensaje: _error!),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      BotonSecundario(
                        etiqueta: 'Cancelar',
                        alPresionar: enCurso ? null : cerrar,
                      ),
                      const SizedBox(width: 10),
                      BotonPrimario(
                        etiqueta: enCurso ? 'Creando…' : 'Crear cuenta',
                        alPresionar: enCurso ? null : _guardar,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
