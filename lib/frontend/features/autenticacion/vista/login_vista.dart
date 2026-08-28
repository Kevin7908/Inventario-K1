import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/autenticacion/resultado/resultados_auth.dart';
import '../../../share2/share2.dart';
import '../provider/auth_providers.dart';
import '../provider/recuperacion_provider.dart';
import '../widgets/marco_autenticacion.dart';
import 'recuperar_vista.dart';

/// Pantalla de inicio de sesión.
///
/// Se entra con **usuario o correo**: el repositorio busca por los dos, así
/// que quien no recuerde cuál registró puede probar con el que tenga a mano.
///
/// No hay «Regístrate»: las cuentas las crea el administrador desde
/// Configuración → Usuarios. La única del taller que nace sola es la primera,
/// y de esa se encarga `PrimerAdminVista`.
class LoginVista extends ConsumerStatefulWidget {
  const LoginVista({super.key});

  @override
  ConsumerState<LoginVista> createState() => _LoginVistaState();
}

class _LoginVistaState extends ConsumerState<LoginVista> {
  final _formKey = GlobalKey<FormState>();
  final _identificadorCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFoco = FocusNode();

  bool _ocultarPassword = true;
  bool _entrando = false;
  String? _error;

  @override
  void dispose() {
    _identificadorCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFoco.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_entrando) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _entrando = true;
      _error = null;
    });

    final resultado = await ref.read(sesionProvider.notifier).entrar(
          identificador: _identificadorCtrl.text,
          password: _passwordCtrl.text,
        );

    if (!mounted) return;

    // En el caso bueno no se toca el estado: el portal ya está cambiando de
    // pantalla y un `setState` sobre un widget que se va no pinta nada.
    switch (resultado) {
      case AccesoConcedido():
        return;
      case CredencialesIncorrectas():
        setState(() {
          _entrando = false;
          _error = 'Usuario, correo o contraseña incorrectos.';
          _passwordCtrl.clear();
        });
        _passwordFoco.requestFocus();
      case CuentaDesactivada():
        setState(() {
          _entrando = false;
          _error = 'Tu cuenta está desactivada. Habla con el administrador '
              'del taller.';
        });
    }
  }

  void _abrirRecuperacion() {
    // El flujo se reinicia aquí y no al cerrar la pantalla: `ref` no se puede
    // tocar desde un `dispose`, y así volver a entrar siempre empieza en el
    // primer paso en vez de reaparecer a mitad de camino.
    ref.invalidate(recuperacionProvider);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RecuperarVista()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MarcoAutenticacion(
      titulo: 'Bienvenido de nuevo',
      subtitulo: 'Escribe tus datos para entrar.',
      child: AtajosFormulario(
        alGuardar: _entrando ? null : _entrar,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CampoTexto(
                etiqueta: 'Usuario o correo',
                controlador: _identificadorCtrl,
                placeholder: 'juan.garcia',
                autofocus: true,
                alEnviar: (_) => _passwordFoco.requestFocus(),
                validador: (v) => (v == null || v.trim().isEmpty)
                    ? 'Escribe tu usuario o tu correo.'
                    : null,
              ),
              const SizedBox(height: 16),
              CampoTexto(
                etiqueta: 'Contraseña',
                controlador: _passwordCtrl,
                nodoFoco: _passwordFoco,
                oculto: _ocultarPassword,
                alAlternarOculto: () =>
                    setState(() => _ocultarPassword = !_ocultarPassword),
                alEnviar: (_) => _entrar(),
                validador: (v) => (v == null || v.isEmpty)
                    ? 'Escribe tu contraseña.'
                    : null,
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _abrirRecuperacion,
                  child: Text(
                    '¿Olvidaste tu contraseña?',
                    style: TipografiaApp.enlace(TipografiaApp.caption),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                AvisoEnLinea(mensaje: _error!),
              ],
              const SizedBox(height: 20),
              BotonPrimario(
                etiqueta: _entrando ? 'Entrando…' : 'Iniciar sesión',
                icono: Icons.login_rounded,
                expandido: true,
                alPresionar: _entrando ? null : _entrar,
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  'Las cuentas las crea el administrador del taller.',
                  textAlign: TextAlign.center,
                  style: TipografiaApp.caption.copyWith(
                    color: ColoresApp.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
