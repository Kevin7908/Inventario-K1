import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventario_k1/frontend/features/autenticacion/vista/registro/registro_vista.dart';
import 'package:provider/provider.dart';

import '../../../../../backend/share/database/locator.dart';
import '../../../share/nav/navegacion.dart';
import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/botones/boton_cargando_widget.dart';
import '../view_model/auth_view_model.dart';
import '../widget/text_field_custom.dart';

class InicioSesionVista extends StatefulWidget {
  const InicioSesionVista({super.key});

  @override
  State<InicioSesionVista> createState() => _InicioSesionVistaState();
}

class _InicioSesionVistaState extends State<InicioSesionVista> {
  late final AuthViewModel _vm;

  // Controladores y focus
  final _formKey = GlobalKey<FormState>();
  final _usuarioCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  final _usuarioFocus = FocusNode();
  final _passwordFocus = FocusNode();

  /// ValueNotifier separado: solo reconstruye el ícono del ojo,
  /// no todo el formulario.
  final _mostrarPassword = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _vm = locator<AuthViewModel>();
    // Enfocar el primer campo al abrir la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _usuarioFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _vm.dispose();
    _usuarioCtrl.dispose();
    _passwordCtrl.dispose();
    _usuarioFocus.dispose();
    _passwordFocus.dispose();
    _mostrarPassword.dispose();
    super.dispose();
  }

  // Acción de login

  Future<void> _iniciarSesion() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _vm.iniciarSesion(
      usuario: _usuarioCtrl.text,
      password: _passwordCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthViewModel>.value(
      value: _vm,
      child: Scaffold(
        backgroundColor: ColoresApp.bgDark,
        body: KeyboardListener(
          // Ctrl+Enter como atajo alternativo de escritorio
          focusNode: FocusNode(),
          onKeyEvent: (event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.enter &&
                HardwareKeyboard.instance.isControlPressed) {
              _iniciarSesion();
            }
          },
          child: const _CuerpoLogin(),
        ),
      ),
    );
  }
}

// Cuerpo principal

class _CuerpoLogin extends StatelessWidget {
  const _CuerpoLogin();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: const _TarjetaLogin(),
        ),
      ),
    );
  }
}

// Tarjeta de Login

class _TarjetaLogin extends StatelessWidget {
  const _TarjetaLogin();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: ColoresApp.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _EncabezadoLogin(),
          SizedBox(height: 32),
          _FormularioLogin(),
        ],
      ),
    );
  }
}

// Encabezado

class _EncabezadoLogin extends StatelessWidget {
  const _EncabezadoLogin();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo / Ícono
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: ColoresApp.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.inventory_2_outlined,
            color: ColoresApp.textWhite,
            size: 26,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'InventarioK1',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: ColoresApp.textDark,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Inicia sesión para continuar',
          style: TextStyle(fontSize: 14, color: ColoresApp.textMedium),
        ),
      ],
    );
  }
}

// Formulario

/// El formulario accede al ViewModel del contexto.
/// Se separa en widget propio para que [Consumer] solo reconstruya esta parte.
class _FormularioLogin extends StatefulWidget {
  const _FormularioLogin();

  @override
  State<_FormularioLogin> createState() => _FormularioLoginState();
}

class _FormularioLoginState extends State<_FormularioLogin> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _usuarioFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _mostrarPassword = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _usuarioCtrl.dispose();
    _passwordCtrl.dispose();
    _usuarioFocus.dispose();
    _passwordFocus.dispose();
    _mostrarPassword.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Escuchar cuando el login sea exitoso y navegar al dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthViewModel>().addListener(_onAuthCambio);
    });
  }

  void _onAuthCambio() {
    final vm = context.read<AuthViewModel>();
    if (vm.estaAutenticado && mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const Navegacion()));
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final vm = context.read<AuthViewModel>();
    await vm.iniciarSesion(
      usuario: _usuarioCtrl.text,
      password: _passwordCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, vm, _) {
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Campo Email
              TextFieldCustom(
                etiqueta: 'Usuario',
                hint: 'juan.garcia',
                controlador: _usuarioCtrl, 
                focusNode: _usuarioFocus,
                siguienteFoco: _passwordFocus,
                iconoPrefijo: Icons.person_outline,
                validador: (v) {
                  if (v == null || v.trim().isEmpty)return 'El usuario es requerido';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Campo Contraseña
              TextFieldCustom(
                etiqueta: 'Contraseña',
                hint: '••••••••',
                controlador: _passwordCtrl,
                focusNode: _passwordFocus,
                mostrarPasswordNotifier: _mostrarPassword,
                iconoPrefijo: Icons.lock_outline,
                alPresionarEnter: _submit,
                validador: (v) {
                  if (v == null || v.isEmpty) {
                    return 'La contraseña es requerida';
                  }
                  if (v.length < 6) {
                    return 'Mínimo 6 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // Hint de accesibilidad
              Text(
                'Presiona Enter para iniciar sesión',
                style: TextStyle(fontSize: 11, color: ColoresApp.textLight),
              ),
              const SizedBox(height: 24),

              // Banner de error / acceso denegado
              if (vm.mensajeError != null) ...[
                _BannerError(mensaje: vm.mensajeError!),
                const SizedBox(height: 16),
              ],

              // Botón de login
              BotonCargando(
                etiqueta: 'Iniciar sesión',
                estaCargando: vm.estaCargando,
                alPresionar: _submit,
                icono: Icons.login,
              ),

              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegistroVista()),
                  ),
                  child: const Text(
                    '¿No tienes cuenta? Regístrate',
                    style: TextStyle(
                      fontSize: 13,
                      color: ColoresApp.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Banner de error

class _BannerError extends StatelessWidget {
  final String mensaje;

  const _BannerError({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    final esAccesoDenegado =
        context.read<AuthViewModel>().estado == EstadoAuth.accesoDenegado;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: esAccesoDenegado
            ? ColoresApp.statusPendingBg
            : ColoresApp.statusDebtBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: esAccesoDenegado
              ? ColoresApp.statusPending
              : ColoresApp.statusDebt,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            esAccesoDenegado
                ? Icons.block_outlined
                : Icons.error_outline_rounded,
            size: 18,
            color: esAccesoDenegado
                ? ColoresApp.statusPending
                : ColoresApp.statusDebt,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: TextStyle(
                fontSize: 13,
                color: esAccesoDenegado
                    ? Color(0xFF92400E) // ámbar oscuro
                    : Color(0xFF991B1B), // rojo oscuro
              ),
            ),
          ),
        ],
      ),
    );
  }
}
