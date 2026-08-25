import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/autenticacion/modelo/usuario.dart';
import '../../../../backend/share/servicios/servicio_correo.dart';
import '../../../../backend/share/servicios/servicio_verificacion.dart';
import '../../../../core/resultado.dart';
import 'auth_providers.dart';

/// En qué punto va la recuperación de la contraseña.
enum PasoRecuperacion {
  /// Pidiendo el usuario o el correo de la cuenta.
  identificacion,

  /// Esperando el código de seis dígitos que se acaba de mandar.
  codigo,

  /// El código dio bien: ya se puede escribir la contraseña nueva.
  password,

  /// Contraseña cambiada. Solo queda volver al login.
  listo,
}

final class RecuperacionState {
  const RecuperacionState({
    this.paso = PasoRecuperacion.identificacion,
    this.cuenta,
    this.enCurso = false,
    this.error,
    this.aviso,
  });

  final PasoRecuperacion paso;

  /// La cuenta a la que se le está cambiando la contraseña. Nunca sale de
  /// aquí: la vista solo muestra el correo enmascarado.
  final Usuario? cuenta;

  final bool enCurso;

  /// Lo que salió mal en el último intento, ya redactado.
  final String? error;

  /// Un aviso que no es error: «se reenvió el código».
  final String? aviso;

  /// `ke***n@gmail.com`. Se muestra para que quien recupera confirme que el
  /// correo es el suyo, sin publicarlo entero en una pantalla de login.
  String get correoEnmascarado {
    final correo = cuenta?.email ?? '';
    final arroba = correo.indexOf('@');
    if (arroba <= 0) return correo;

    final local = correo.substring(0, arroba);
    final dominio = correo.substring(arroba);
    if (local.length <= 2) return '${local[0]}***$dominio';

    return '${local.substring(0, 2)}***${local[local.length - 1]}$dominio';
  }

  RecuperacionState copiaCon({
    PasoRecuperacion? paso,
    Usuario? cuenta,
    bool? enCurso,
    String? error,
    String? aviso,
  }) =>
      RecuperacionState(
        paso: paso ?? this.paso,
        cuenta: cuenta ?? this.cuenta,
        enCurso: enCurso ?? this.enCurso,
        error: error,
        aviso: aviso,
      );
}

/// El flujo de «olvidé mi contraseña», de principio a fin.
///
/// El código vive en [ServicioVerificacion], que lo guarda en memoria: si la
/// app se cierra a mitad, hay que pedir otro. Está dicho en la pantalla.
final class RecuperacionNotifier extends Notifier<RecuperacionState> {
  @override
  RecuperacionState build() => const RecuperacionState();

  /// Paso 1: busca la cuenta y le manda el código a su correo.
  ///
  /// Si el identificador no existe **también** avanza al paso del código. Es
  /// deliberado: decir «esa cuenta no existe» le confirma a cualquiera qué
  /// usuarios hay. Lo que no existe simplemente nunca recibe un código.
  Future<void> pedirCodigo(String identificador) async {
    if (state.enCurso) return;
    if (identificador.trim().isEmpty) {
      state = state.copiaCon(error: 'Escribe tu usuario o tu correo.');
      return;
    }

    state = state.copiaCon(enCurso: true);

    final cuenta = await ref
        .read(repositorioAuthProvider)
        .obtenerPorIdentificador(identificador);

    if (cuenta == null) {
      state = state.copiaCon(paso: PasoRecuperacion.codigo, enCurso: false);
      return;
    }

    if (!cuenta.tieneCorreo) {
      state = state.copiaCon(
        enCurso: false,
        error: 'Esa cuenta no tiene un correo registrado. Pídele al '
            'administrador que te ponga una contraseña nueva.',
      );
      return;
    }

    final resultado = await _mandarCodigo(cuenta);
    if (resultado != null) {
      state = state.copiaCon(enCurso: false, error: resultado);
      return;
    }

    state = state.copiaCon(
      paso: PasoRecuperacion.codigo,
      cuenta: cuenta,
      enCurso: false,
    );
  }

  /// Paso 2: comprueba el código tecleado.
  void verificarCodigo(String codigo) {
    final cuenta = state.cuenta;

    // Sin cuenta el paso anterior no encontró a nadie: se responde lo mismo
    // que a un código equivocado, para no delatar que el usuario no existe.
    if (cuenta == null) {
      state = state.copiaCon(
        paso: PasoRecuperacion.codigo,
        error: 'Código incorrecto. Verifica e intenta de nuevo.',
      );
      return;
    }

    final resultado = ref
        .read(servicioVerificacionProvider)
        .validarCodigo(cuenta.email, codigo);

    state = resultado == ResultadoValidacion.valido
        ? state.copiaCon(paso: PasoRecuperacion.password)
        : state.copiaCon(error: resultado.mensaje);
  }

  /// Paso 2 bis: manda otro código.
  Future<void> reenviarCodigo() async {
    final cuenta = state.cuenta;
    if (state.enCurso || cuenta == null) return;

    state = state.copiaCon(paso: PasoRecuperacion.codigo, enCurso: true);
    final error = await _mandarCodigo(cuenta);

    state = state.copiaCon(
      enCurso: false,
      error: error,
      aviso: error == null ? 'Te mandamos un código nuevo.' : null,
    );
  }

  /// Paso 3: guarda la contraseña nueva.
  Future<void> cambiarPassword(String passwordNueva) async {
    final cuenta = state.cuenta;
    if (state.enCurso || cuenta == null) return;

    state = state.copiaCon(enCurso: true);

    final resultado = await ref.read(repositorioAuthProvider).cambiarPassword(
          usuarioId: cuenta.id,
          passwordNueva: passwordNueva,
        );

    state = switch (resultado) {
      Exito() => state.copiaCon(paso: PasoRecuperacion.listo, enCurso: false),
      Fallo(:final mensaje) => state.copiaCon(enCurso: false, error: mensaje),
    };
  }

  void volverAEmpezar() => state = const RecuperacionState();

  /// `null` si el correo salió; el texto del error si no.
  Future<String?> _mandarCodigo(Usuario cuenta) async {
    final codigo =
        ref.read(servicioVerificacionProvider).generarCodigo(cuenta.email);

    final envio = await ref.read(servicioCorreoProvider).enviarCodigoRecuperacion(
          email: cuenta.email,
          codigo: codigo,
          nombre: cuenta.nombre,
          minutosVigencia: ServicioVerificacion.minutosExpiracion,
        );

    return switch (envio) {
      CorreoEnviado() => null,
      CorreoNoConfigurado() =>
        'El envío de correos no está configurado en este equipo. Pídele al '
            'administrador que llene el archivo .env.',
      CorreoFallido() =>
        'No se pudo enviar el correo. Revisa la conexión e intenta de nuevo.',
    };
  }
}

final recuperacionProvider =
    NotifierProvider<RecuperacionNotifier, RecuperacionState>(
  RecuperacionNotifier.new,
  name: 'recuperacionProvider',
);
