import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/share/servicios/servicio_verificacion.dart';
import '../../../share2/share2.dart';
import '../provider/recuperacion_provider.dart';
import '../validacion_password.dart';
import '../widgets/campo_codigo.dart';
import '../widgets/marco_autenticacion.dart';

/// «Olvidé mi contraseña», en tres pasos: identificarse, teclear el código que
/// llegó al correo y escribir la nueva.
///
/// El código vive en memoria mientras la app corre. Cerrarla a mitad obliga a
/// pedir otro, y la pantalla lo dice.
///
/// Quien la abre —`LoginVista`— invalida antes `recuperacionProvider`, para
/// que el flujo empiece de cero. No se hace aquí, en un `dispose`: Riverpod 3
/// prohíbe tocar `ref` cuando el widget ya se está desmontando.
class RecuperarVista extends ConsumerWidget {
  const RecuperarVista({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paso = ref.watch(recuperacionProvider.select((s) => s.paso));
    void cerrar() => Navigator.of(context).pop();

    return switch (paso) {
      PasoRecuperacion.identificacion => _PasoIdentificacion(alVolver: cerrar),
      PasoRecuperacion.codigo => _PasoCodigo(alVolver: cerrar),
      PasoRecuperacion.password => const _PasoPassword(),
      PasoRecuperacion.listo => _PasoListo(alVolver: cerrar),
    };
  }
}

/// Paso 1 — a quién le mandamos el código.
class _PasoIdentificacion extends ConsumerStatefulWidget {
  const _PasoIdentificacion({required this.alVolver});

  final VoidCallback alVolver;

  @override
  ConsumerState<_PasoIdentificacion> createState() =>
      _PasoIdentificacionState();
}

class _PasoIdentificacionState extends ConsumerState<_PasoIdentificacion> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _continuar() =>
      ref.read(recuperacionProvider.notifier).pedirCodigo(_ctrl.text);

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(recuperacionProvider);

    return MarcoAutenticacion(
      titulo: 'Recupera tu acceso',
      subtitulo: 'Te mandamos un código al correo de tu cuenta.',
      alVolver: widget.alVolver,
      etiquetaVolver: 'Volver al inicio de sesión',
      child: AtajosFormulario(
        alGuardar: estado.enCurso ? null : _continuar,
        alCancelar: widget.alVolver,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CampoTexto(
              etiqueta: 'Usuario o correo',
              controlador: _ctrl,
              autofocus: true,
              alEnviar: (_) => _continuar(),
            ),
            if (estado.error != null) ...[
              const SizedBox(height: 16),
              AvisoEnLinea(mensaje: estado.error!),
            ],
            const SizedBox(height: 22),
            BotonPrimario(
              etiqueta: estado.enCurso ? 'Enviando…' : 'Enviar código',
              icono: Icons.mail_outline_rounded,
              expandido: true,
              alPresionar: estado.enCurso ? null : _continuar,
            ),
          ],
        ),
      ),
    );
  }
}

/// Paso 2 — el código de seis dígitos.
class _PasoCodigo extends ConsumerStatefulWidget {
  const _PasoCodigo({required this.alVolver});

  final VoidCallback alVolver;

  @override
  ConsumerState<_PasoCodigo> createState() => _PasoCodigoState();
}

class _PasoCodigoState extends ConsumerState<_PasoCodigo> {
  String _codigo = '';

  void _verificar() =>
      ref.read(recuperacionProvider.notifier).verificarCodigo(_codigo);

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(recuperacionProvider);

    return MarcoAutenticacion(
      titulo: 'Escribe el código',
      subtitulo: estado.cuenta == null
          ? 'Si esa cuenta existe, le acaba de llegar un código de seis '
              'dígitos.'
          : 'Se lo mandamos a ${estado.correoEnmascarado}.',
      alVolver: widget.alVolver,
      etiquetaVolver: 'Volver al inicio de sesión',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CampoCodigo(
            alCambiar: (valor) => _codigo = valor,
            alCompletar: (valor) {
              _codigo = valor;
              _verificar();
            },
          ),
          if (estado.error != null) ...[
            const SizedBox(height: 18),
            AvisoEnLinea(mensaje: estado.error!),
          ],
          if (estado.aviso != null) ...[
            const SizedBox(height: 18),
            AvisoEnLinea(mensaje: estado.aviso!, tono: TonoAviso.exito),
          ],
          const SizedBox(height: 22),
          BotonPrimario(
            etiqueta: 'Verificar código',
            icono: Icons.check_rounded,
            expandido: true,
            alPresionar: estado.enCurso ? null : _verificar,
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: estado.enCurso || estado.cuenta == null
                  ? null
                  : ref.read(recuperacionProvider.notifier).reenviarCodigo,
              child: Text(
                'Reenviar el código',
                style: TipografiaApp.enlace(TipografiaApp.caption),
              ),
            ),
          ),
          Text(
            'El código vale ${ServicioVerificacion.minutosExpiracion} minutos '
            'y se pierde si cierras la app.',
            style: TipografiaApp.caption.copyWith(color: ColoresApp.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Paso 3 — la contraseña nueva.
class _PasoPassword extends ConsumerStatefulWidget {
  const _PasoPassword();

  @override
  ConsumerState<_PasoPassword> createState() => _PasoPasswordState();
}

class _PasoPasswordState extends ConsumerState<_PasoPassword> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _repetirCtrl = TextEditingController();
  bool _oculta = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _repetirCtrl.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ref
        .read(recuperacionProvider.notifier)
        .cambiarPassword(_passwordCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(recuperacionProvider);

    return MarcoAutenticacion(
      titulo: 'Elige una contraseña',
      subtitulo: 'Al menos $minimoCaracteresPassword caracteres.',
      child: AtajosFormulario(
        alGuardar: estado.enCurso ? null : _guardar,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CampoTexto(
                etiqueta: 'Contraseña nueva',
                controlador: _passwordCtrl,
                autofocus: true,
                oculto: _oculta,
                alAlternarOculto: () => setState(() => _oculta = !_oculta),
                validador: validarPassword,
              ),
              const SizedBox(height: 16),
              CampoTexto(
                etiqueta: 'Repite la contraseña',
                controlador: _repetirCtrl,
                oculto: _oculta,
                alEnviar: (_) => _guardar(),
                validador: (v) => v == _passwordCtrl.text
                    ? null
                    : 'Las dos contraseñas no coinciden.',
              ),
              if (estado.error != null) ...[
                const SizedBox(height: 16),
                AvisoEnLinea(mensaje: estado.error!),
              ],
              const SizedBox(height: 22),
              BotonPrimario(
                etiqueta: estado.enCurso ? 'Guardando…' : 'Guardar contraseña',
                icono: Icons.lock_reset_rounded,
                expandido: true,
                alPresionar: estado.enCurso ? null : _guardar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paso 4 — listo.
class _PasoListo extends StatelessWidget {
  const _PasoListo({required this.alVolver});

  final VoidCallback alVolver;

  @override
  Widget build(BuildContext context) {
    return MarcoAutenticacion(
      titulo: 'Contraseña cambiada',
      subtitulo: 'Ya puedes entrar con la nueva.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AvisoEnLinea(
            tono: TonoAviso.exito,
            mensaje: 'Tu contraseña quedó actualizada.',
          ),
          const SizedBox(height: 22),
          BotonPrimario(
            etiqueta: 'Ir al inicio de sesión',
            icono: Icons.login_rounded,
            expandido: true,
            alPresionar: alVolver,
          ),
        ],
      ),
    );
  }
}
