/// El HTML de los correos que manda la app.
///
/// Aparte de [ServicioCorreo] porque son dos cosas distintas: una habla SMTP y
/// la otra es diseño. Los colores son los del logo —el verde `#01B763`, el
/// oscuro `#19211D` y el blanco de la marca—, los mismos de `ColoresApp`. Los
/// correos que había antes eran azules `#2563EB`, que no es un color de esta
/// app.
///
/// Todo va en tablas y con estilos en línea: es lo único que renderiza igual
/// en Gmail, Outlook y los clientes de escritorio. Ningún `<style>`, ninguna
/// imagen remota —el logo se dibuja con dos letras sobre un cuadro blanco, así
/// que se ve aunque el cliente bloquee imágenes—.
abstract final class PlantillasCorreo {
  PlantillasCorreo._();

  static const String _verde = '#01B763';
  static const String _verdeOscuro = '#005B31';
  static const String _oscuro = '#16201B';
  static const String _textoPrincipal = '#19211D';
  static const String _textoSecundario = '#5B6B61';
  static const String _textoTenue = '#8A988F';
  static const String _fondo = '#F4F5F6';
  static const String _tarjeta = '#FFFFFF';
  static const String _borde = '#EAECEA';
  static const String _verdeSuave = '#E4F7EE';
  static const String _ambar = '#E0892A';

  static const String _fuente =
      "-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif";

  /// Código de seis dígitos para volver a entrar.
  static String codigoRecuperacion({
    required String codigo,
    required String nombre,
    required int minutosVigencia,
  }) {
    return _marco(
      titulo: 'Recupera tu acceso',
      cuerpo: '''
        <p style="margin:0 0 28px;color:$_textoSecundario;font-size:15px;line-height:1.6;">
          Hola ${_saludo(nombre)}, alguien pidió restablecer la contraseña de tu
          cuenta. Escribe este código en la app para elegir una nueva.
        </p>
        <table width="100%" cellpadding="0" cellspacing="0" role="presentation"
               style="background:$_verdeSuave;border:1px solid $_verde;border-radius:12px;">
          <tr><td align="center" style="padding:26px 20px;">
            <p style="margin:0 0 10px;color:$_verdeOscuro;font-size:11px;font-weight:700;
                      letter-spacing:2px;text-transform:uppercase;">
              Código de verificación
            </p>
            <span style="font-family:ui-monospace,'Courier New',monospace;font-size:40px;
                         font-weight:700;color:$_verdeOscuro;letter-spacing:10px;">
              ${_escapar(codigo)}
            </span>
            <p style="margin:12px 0 0;color:$_textoSecundario;font-size:13px;">
              Vence en $minutosVigencia minutos.
            </p>
          </td></tr>
        </table>
        <p style="margin:28px 0 0;color:$_textoTenue;font-size:13px;line-height:1.6;">
          Si no fuiste tú, ignora este correo: tu contraseña actual sigue
          funcionando y nadie puede cambiarla sin este código.
        </p>
      ''',
    );
  }

  /// El administrador abrió una cuenta.
  static String bienvenida({
    required String nombre,
    required String usuario,
    required String rol,
  }) {
    return _marco(
      titulo: 'Tu cuenta ya está lista',
      cuerpo: '''
        <p style="margin:0 0 24px;color:$_textoSecundario;font-size:15px;line-height:1.6;">
          Hola ${_saludo(nombre)}, el administrador del taller te creó una
          cuenta en InventarioK1.
        </p>
        ${_filaDato('Usuario', usuario, monoespaciado: true)}
        ${_filaDato('Rol', rol)}
        <p style="margin:24px 0 0;color:$_textoSecundario;font-size:14px;line-height:1.6;">
          La contraseña te la entrega el administrador en persona; por
          seguridad no viaja por correo. Puedes entrar con tu usuario o con
          esta misma dirección.
        </p>
      ''',
    );
  }

  /// La cuenta se activó o se suspendió.
  static String cambioDeEstado({
    required String nombre,
    required bool activa,
  }) {
    final color = activa ? _verde : _ambar;
    final titulo = activa ? 'Tu cuenta se reactivó' : 'Tu acceso quedó suspendido';
    final detalle = activa
        ? 'Ya puedes volver a entrar con tu usuario y contraseña de siempre.'
        : 'Mientras esté suspendida no podrás iniciar sesión. Habla con el '
            'administrador del taller si crees que es un error.';

    return _marco(
      titulo: titulo,
      colorTitulo: color,
      cuerpo: '''
        <p style="margin:0;color:$_textoSecundario;font-size:15px;line-height:1.6;">
          Hola ${_saludo(nombre)}, ${_escapar(detalle)}
        </p>
      ''',
    );
  }

  // Piezas compartidas

  /// La tarjeta con la cabecera oscura, el contenido y el pie.
  static String _marco({
    required String titulo,
    required String cuerpo,
    String colorTitulo = _textoPrincipal,
  }) {
    return '''
<!DOCTYPE html>
<html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:$_fondo;font-family:$_fuente;">
<table width="100%" cellpadding="0" cellspacing="0" role="presentation"
       style="background:$_fondo;padding:40px 16px;">
  <tr><td align="center">
    <table width="520" cellpadding="0" cellspacing="0" role="presentation"
           style="width:520px;max-width:100%;background:$_tarjeta;
                  border:1px solid $_borde;border-radius:16px;overflow:hidden;">
      <tr><td style="background:$_oscuro;padding:22px 32px;">$_encabezado</td></tr>
      <tr><td style="padding:36px 32px 32px;">
        <h1 style="margin:0 0 6px;color:$colorTitulo;font-size:21px;font-weight:700;">
          ${_escapar(titulo)}
        </h1>
        <div style="height:3px;width:36px;background:$_verde;border-radius:2px;
                    margin:0 0 22px;"></div>
        $cuerpo
      </td></tr>
      <tr><td style="background:#FAFBFA;border-top:1px solid $_borde;
                     padding:18px 32px;text-align:center;">
        <p style="margin:0;color:$_textoTenue;font-size:12px;">
          InventarioK1 — Taller de motos
        </p>
      </td></tr>
    </table>
  </td></tr>
</table>
</body></html>
''';
  }

  /// El logo: el cuadro blanco con la «K1», como el SVG de la app.
  static const String _encabezado = '''
<table cellpadding="0" cellspacing="0" role="presentation"><tr>
  <td width="40" style="width:40px;height:40px;background:$_tarjeta;
      border-radius:11px;text-align:center;vertical-align:middle;
      font-size:18px;font-weight:800;letter-spacing:-1px;line-height:40px;">
    <span style="color:$_verde;">K</span><span style="color:$_textoPrincipal;">1</span>
  </td>
  <td style="padding-left:12px;vertical-align:middle;">
    <div style="color:#FFFFFF;font-size:15px;font-weight:700;">InventarioK1</div>
    <div style="color:#6E7F75;font-size:12px;">Taller de motos</div>
  </td>
</tr></table>''';

  /// Un renglón «etiqueta / valor» dentro del cuerpo.
  static String _filaDato(
    String etiqueta,
    String valor, {
    bool monoespaciado = false,
  }) {
    final fuente = monoespaciado
        ? "font-family:ui-monospace,'Courier New',monospace;"
        : '';
    return '''
<table width="100%" cellpadding="0" cellspacing="0" role="presentation"
       style="border:1px solid $_borde;border-radius:10px;margin-bottom:10px;">
  <tr>
    <td style="padding:12px 16px;color:$_textoTenue;font-size:12px;
               font-weight:600;letter-spacing:.4px;text-transform:uppercase;">
      ${_escapar(etiqueta)}
    </td>
    <td align="right" style="padding:12px 16px;color:$_textoPrincipal;
               font-size:14px;font-weight:600;$fuente">
      ${_escapar(valor)}
    </td>
  </tr>
</table>''';
  }

  static String _saludo(String nombre) {
    final limpio = nombre.trim();
    if (limpio.isEmpty) return 'de nuevo';
    return _escapar(limpio.split(RegExp(r'\s+')).first);
  }

  /// Un nombre con `<` o `&` rompería el HTML del correo. Nada de lo que entra
  /// aquí lo escribe la app: lo teclea un usuario.
  static String _escapar(String texto) => texto
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
