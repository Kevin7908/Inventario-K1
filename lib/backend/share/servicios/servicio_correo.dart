import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../config/entorno.dart';
import 'plantillas_correo.dart';

/// Cómo terminó un envío.
///
/// Es un tipo sellado porque «no se pudo enviar» y «no hay correo configurado»
/// piden respuestas distintas del usuario: la primera es reintentar, la
/// segunda es pedirle al administrador que llene el `.env`.
sealed class ResultadoCorreo {
  const ResultadoCorreo();
}

final class CorreoEnviado extends ResultadoCorreo {
  const CorreoEnviado();
}

/// El `.env` no trae las credenciales SMTP. Ver `.env.ejemplo`.
final class CorreoNoConfigurado extends ResultadoCorreo {
  const CorreoNoConfigurado();
}

final class CorreoFallido extends ResultadoCorreo {
  const CorreoFallido(this.detalle);

  final String detalle;
}

/// Manda los correos de la app por SMTP.
///
/// Las credenciales salen de [AjustesCorreo], que vienen del `.env`. Cuando no
/// hay ajustes el servicio **sigue existiendo** y responde
/// [CorreoNoConfigurado] a cada envío: así ninguna pantalla tiene que decidir
/// si el servicio está o no, y la app arranca igual en un taller sin internet.
class ServicioCorreo {
  ServicioCorreo(this.ajustes);

  /// Construye el servicio con lo que haya en el `.env`.
  factory ServicioCorreo.desdeEntorno() => ServicioCorreo(Entorno.correo);

  final AjustesCorreo? ajustes;

  bool get estaConfigurado => ajustes != null;

  /// El código de seis dígitos para recuperar la contraseña.
  Future<ResultadoCorreo> enviarCodigoRecuperacion({
    required String email,
    required String codigo,
    required String nombre,
    required int minutosVigencia,
  }) {
    return _enviar(
      destinatario: email,
      asunto: '$codigo es tu código para recuperar el acceso — InventarioK1',
      cuerpoHtml: PlantillasCorreo.codigoRecuperacion(
        codigo: codigo,
        nombre: nombre,
        minutosVigencia: minutosVigencia,
      ),
    );
  }

  /// Le avisa a alguien que el administrador le abrió una cuenta.
  ///
  /// **No lleva la contraseña.** La inicial se la da el administrador en
  /// persona; mandarla por correo la deja escrita para siempre en una bandeja
  /// de entrada.
  Future<ResultadoCorreo> enviarBienvenida({
    required String email,
    required String nombre,
    required String usuario,
    required String rol,
  }) {
    return _enviar(
      destinatario: email,
      asunto: 'Tu cuenta de InventarioK1 está lista',
      cuerpoHtml: PlantillasCorreo.bienvenida(
        nombre: nombre,
        usuario: usuario,
        rol: rol,
      ),
    );
  }

  /// Le avisa a alguien que su cuenta se activó o se desactivó.
  Future<ResultadoCorreo> enviarCambioDeEstado({
    required String email,
    required String nombre,
    required bool activa,
  }) {
    return _enviar(
      destinatario: email,
      asunto: activa
          ? 'Tu cuenta de InventarioK1 se reactivó'
          : 'Tu acceso a InventarioK1 quedó suspendido',
      cuerpoHtml: PlantillasCorreo.cambioDeEstado(
        nombre: nombre,
        activa: activa,
      ),
    );
  }

  Future<ResultadoCorreo> _enviar({
    required String destinatario,
    required String asunto,
    required String cuerpoHtml,
  }) async {
    final config = ajustes;
    if (config == null) return const CorreoNoConfigurado();
    if (destinatario.trim().isEmpty) {
      return const CorreoFallido('La cuenta no tiene correo registrado.');
    }

    final servidor = SmtpServer(
      config.host,
      port: config.puerto,
      ssl: config.ssl,
      username: config.usuario,
      password: config.password,
    );

    final mensaje = Message()
      ..from = Address(config.remitente, config.nombreRemitente)
      ..recipients.add(destinatario)
      ..subject = asunto
      ..html = cuerpoHtml;

    try {
      await send(mensaje, servidor);
      return const CorreoEnviado();
    } catch (e) {
      return CorreoFallido(e.toString());
    }
  }
}
