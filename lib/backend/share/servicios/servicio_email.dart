import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// Servicio de correo electrónico usando la dependencia `mailer` (SMTP).
/// Dependencia: mailer: ^6.1.1
class ServicioEmail {
  final SmtpServer _smtpServer;
  final String _remitente;
  final String _nombreRemitente;

  ServicioEmail({
    required String host,
    required int puerto,
    required String usuario,
    required String password,
    String remitente = '',
    String nombreRemitente = 'InventarioK1',
    bool ssl = true,
  })  : _remitente = remitente.isEmpty ? usuario : remitente,
        _nombreRemitente = nombreRemitente,
        _smtpServer = SmtpServer(
          host,
          port: puerto,
          ssl: ssl,
          username: usuario,
          password: password,
        );

  factory ServicioEmail.gmail({
    required String email,
    required String appPassword,
    String nombreRemitente = 'InventarioK1',
  }) {
    return ServicioEmail(
      host: 'smtp.gmail.com',
      puerto: 587,
      usuario: email,
      password: appPassword,
      ssl: false,
      nombreRemitente: nombreRemitente,
    );
  }

  Future<void> _enviar({
    required String destinatario,
    required String asunto,
    required String cuerpoHtml,
  }) async {
    final mensaje = Message()
      ..from = Address(_remitente, _nombreRemitente)
      ..recipients.add(destinatario)
      ..subject = asunto
      ..html = cuerpoHtml;

    try {
      await send(mensaje, _smtpServer);
    } on MailerException catch (e) {
      // ignore: avoid_print
      print('[ServicioEmail] Error al enviar correo: $e');
      rethrow;
    }
  }

  // Código OTP

  Future<void> enviarCodigoVerificacion({
    required String email,
    required String codigo,
    required String nombre,
  }) async {
    await _enviar(
      destinatario: email,
      asunto: '$codigo es tu código de verificación — InventarioK1',
      cuerpoHtml: '''
        <!DOCTYPE html><html><body style="margin:0;padding:0;background:#F3F4F6;
          font-family:'Segoe UI',sans-serif;">
          <table width="100%" cellpadding="0" cellspacing="0" style="padding:40px 0;">
            <tr><td align="center">
              <table width="480" cellpadding="0" cellspacing="0"
                style="background:#FFFFFF;border-radius:16px;overflow:hidden;
                       box-shadow:0 4px 24px rgba(0,0,0,0.08);">
                <tr>
                  <td style="background:#2563EB;padding:32px 40px;text-align:center;">
                    <h1 style="color:#FFFFFF;margin:0;font-size:22px;font-weight:700;">
                      📦 InventarioK1
                    </h1>
                  </td>
                </tr>
                <tr>
                  <td style="padding:40px;">
                    <h2 style="color:#111827;margin:0 0 8px;font-size:20px;font-weight:700;">
                      Verifica tu correo
                    </h2>
                    <p style="color:#6B7280;margin:0 0 32px;font-size:15px;line-height:1.6;">
                      Hola ${nombre.isNotEmpty ? nombre : 'usuario'},<br>
                      Usa el siguiente código para completar tu registro.
                      Expira en <strong>10 minutos</strong>.
                    </p>
                    <div style="background:#EFF6FF;border:2px solid #BFDBFE;
                                border-radius:12px;padding:28px;text-align:center;
                                margin-bottom:32px;">
                      <p style="color:#6B7280;font-size:11px;font-weight:600;
                                letter-spacing:2px;text-transform:uppercase;margin:0 0 12px;">
                        CÓDIGO DE VERIFICACIÓN
                      </p>
                      <span style="font-size:48px;font-weight:800;color:#1D4ED8;
                                   letter-spacing:12px;font-family:monospace;">
                        $codigo
                      </span>
                    </div>
                    <p style="color:#9CA3AF;font-size:13px;margin:0;line-height:1.6;">
                      Si no solicitaste este código, puedes ignorar este correo.
                    </p>
                  </td>
                </tr>
                <tr>
                  <td style="background:#F9FAFB;padding:20px 40px;
                             border-top:1px solid #E5E7EB;text-align:center;">
                    <p style="color:#9CA3AF;font-size:12px;margin:0;">
                      InventarioK1 — Sistema de gestión de inventario
                    </p>
                  </td>
                </tr>
              </table>
            </td></tr>
          </table>
        </body></html>
      ''',
    );
  }

  // Bienvenida

  Future<void> enviarBienvenida({
    required String email,
    required String nombre,
  }) async {
    await _enviar(
      destinatario: email,
      asunto: '¡Bienvenido a InventarioK1, $nombre!',
      cuerpoHtml: '''
        <div style="font-family:'Segoe UI',sans-serif;max-width:480px;margin:auto;padding:32px;">
          <h2 style="color:#2563EB;">¡Hola, $nombre! 👋</h2>
          <p style="color:#374151;">Tu cuenta en <strong>InventarioK1</strong>
             ha sido creada y verificada exitosamente.</p>
          <p style="color:#374151;">Ya puedes iniciar sesión con tu correo y contraseña.</p>
          <hr style="border:none;border-top:1px solid #E5E7EB;margin:24px 0">
          <p style="color:#9CA3AF;font-size:12px;">InventarioK1 — Sistema de gestión</p>
        </div>
      ''',
    );
  }

  // Acceso denegado

  Future<void> enviarNotificacionAccesoDenegado({
    required String email,
    required String nombre,
  }) async {
    await _enviar(
      destinatario: email,
      asunto: 'Acceso a InventarioK1 restringido',
      cuerpoHtml: '''
        <div style="font-family:'Segoe UI',sans-serif;max-width:480px;margin:auto;padding:32px;">
          <h2 style="color:#DC2626;">Acceso restringido</h2>
          <p style="color:#374151;">Hola ${nombre.isNotEmpty ? nombre : 'usuario'},</p>
          <p style="color:#374151;">Tu cuenta ha sido desactivada por un administrador.</p>
          <hr style="border:none;border-top:1px solid #E5E7EB;margin:24px 0">
          <p style="color:#9CA3AF;font-size:12px;">InventarioK1 — Sistema de gestión</p>
        </div>
      ''',
    );
  }

  // Estado de cuenta

  Future<void> enviarNotificacionEstadoCuenta({
    required String email,
    required String nombre,
    required bool estaActivo,
  }) async {
    final accion = estaActivo ? 'activada' : 'desactivada';
    final color  = estaActivo ? '#16A34A' : '#DC2626';
    await _enviar(
      destinatario: email,
      asunto: 'Tu cuenta ha sido $accion — InventarioK1',
      cuerpoHtml: '''
        <div style="font-family:'Segoe UI',sans-serif;max-width:480px;margin:auto;padding:32px;">
          <h2 style="color:$color;">Cuenta $accion</h2>
          <p style="color:#374151;">Hola $nombre, tu cuenta ha sido <strong>$accion</strong>.</p>
          <hr style="border:none;border-top:1px solid #E5E7EB;margin:24px 0">
          <p style="color:#9CA3AF;font-size:12px;">InventarioK1 — Sistema de gestión</p>
        </div>
      ''',
    );
  }
}