import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/autenticacion/resultado/resultados_auth.dart';
import '../../../../backend/share/dominio/rol_usuario.dart';
import '../../../share2/share2.dart';
import '../provider/auth_providers.dart';
import '../validacion_cuenta.dart';
import '../validacion_password.dart';
import '../widgets/marco_autenticacion.dart';

/// La primera cuenta del taller.
///
/// Solo se ve una vez: cuando la base no tiene ningún usuario, que es el
/// estado de una instalación recién hecha. A partir de ahí las cuentas las
/// crea el administrador desde Configuración → Usuarios, y esta pantalla no
/// vuelve a aparecer.
///
/// El rol no se pregunta: quien instala la app es el administrador. Preguntar
/// dejaría abierta la posibilidad de crear el primer usuario como cajero y
/// quedarse sin nadie que pueda dar de alta a los demás.
class PrimerAdminVista extends ConsumerStatefulWidget {
  const PrimerAdminVista({super.key});

  @override
  ConsumerState<PrimerAdminVista> createState() => _PrimerAdminVistaState();
}

class _PrimerAdminVistaState extends ConsumerState<PrimerAdminVista> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _usuarioCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _repetirCtrl = TextEditingController();

  bool _oculta = true;
  bool _creando = false;
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _usuarioCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _repetirCtrl.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    if (_creando) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _creando = true;
      _error = null;
    });

    // El repositorio **anónimo**: esta cuenta se crea antes de que exista
    // ninguna sesión, así que no hay quien firme el renglón de la bitácora.
    final resultado =
        await ref.read(repositorioAuthAnonimoProvider).crearCuenta(
          nombre: _nombreCtrl.text,
          usuario: _usuarioCtrl.text,
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
          rol: RolUsuario.admin,
        );

    if (!mounted) return;

    switch (resultado) {
      case CuentaCreada(:final usuario):
        // Entra directo: acaba de escribir su propia contraseña, volver a
        // pedírsela no protege de nada.
        ref.invalidate(hayUsuariosProvider);
        ref.read(sesionProvider.notifier).abrirSesionCon(usuario);
      case UsuarioEnUso():
        setState(() {
          _creando = false;
          _error = 'Ese nombre de usuario ya está tomado.';
        });
      case CorreoEnUso():
        setState(() {
          _creando = false;
          _error = 'Ese correo ya está registrado.';
        });
      case CuentaNoGuardada(:final detalle):
        setState(() {
          _creando = false;
          _error = 'No se pudo crear la cuenta: $detalle';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MarcoAutenticacion(
      titulo: 'Crea la cuenta del administrador',
      subtitulo: 'Es la primera cuenta del taller. Desde ella se dan de alta '
          'las demás.',
      child: AtajosFormulario(
        alGuardar: _creando ? null : _crear,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CampoTexto(
                etiqueta: 'Nombre completo *',
                controlador: _nombreCtrl,
                placeholder: 'Juan García',
                autofocus: true,
                validador: (v) => (v == null || v.trim().isEmpty)
                    ? 'El nombre es obligatorio.'
                    : null,
              ),
              const SizedBox(height: 16),
              CampoTexto(
                etiqueta: 'Usuario *',
                controlador: _usuarioCtrl,
                placeholder: 'juan.garcia',
                validador: validarUsuario,
              ),
              const SizedBox(height: 16),
              CampoTexto(
                etiqueta: 'Correo *',
                controlador: _emailCtrl,
                placeholder: 'juan@taller.com',
                validador: validarCorreoObligatorio,
              ),
              const SizedBox(height: 4),
              Text(
                'Sin correo no hay forma de recuperar la contraseña.',
                style: TipografiaApp.caption.copyWith(
                  color: ColoresApp.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              CampoTexto(
                etiqueta: 'Contraseña *',
                controlador: _passwordCtrl,
                oculto: _oculta,
                alAlternarOculto: () => setState(() => _oculta = !_oculta),
                validador: validarPassword,
              ),
              const SizedBox(height: 16),
              CampoTexto(
                etiqueta: 'Repite la contraseña *',
                controlador: _repetirCtrl,
                oculto: _oculta,
                alEnviar: (_) => _crear(),
                validador: (v) => v == _passwordCtrl.text
                    ? null
                    : 'Las dos contraseñas no coinciden.',
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                AvisoEnLinea(mensaje: _error!),
              ],
              const SizedBox(height: 22),
              BotonPrimario(
                etiqueta: _creando ? 'Creando…' : 'Crear cuenta y entrar',
                icono: Icons.person_add_alt_1_rounded,
                expandido: true,
                alPresionar: _creando ? null : _crear,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
