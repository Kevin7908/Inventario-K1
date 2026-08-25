import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Datos de conexión al servidor de correo de esta instalación.
///
/// No están en el código: salen del archivo `.env`, que está en `.gitignore`.
/// Una contraseña de aplicación en una constante de Dart se va al repositorio
/// con el primer commit y ya no hay forma de sacarla del historial.
final class AjustesCorreo {
  const AjustesCorreo({
    required this.host,
    required this.puerto,
    required this.usuario,
    required this.password,
    required this.ssl,
    required this.remitente,
    required this.nombreRemitente,
  });

  final String host;
  final int puerto;
  final String usuario;
  final String password;
  final bool ssl;

  /// Dirección que aparece en el «de». Cae en [usuario] cuando no se declara.
  final String remitente;

  final String nombreRemitente;
}

/// Lee el `.env` de la instalación.
///
/// Se busca en dos sitios, en este orden: el directorio de trabajo —que en
/// desarrollo es la raíz del proyecto— y el del ejecutable, que es donde queda
/// en una instalación real. El primero que exista gana.
///
/// **Que falte no es un error.** La app arranca igual con [correo] en `null` y
/// `ServicioCorreo` responde `CorreoNoConfigurado` a cada envío, que es un
/// resultado que la vista sabe explicar. Reventar al arrancar porque no hay
/// SMTP dejaría sin app a un taller que solo quiere facturar.
abstract final class Entorno {
  Entorno._();

  static Map<String, String>? _valores;

  /// Pares clave/valor del `.env`, o vacío si no hay archivo.
  ///
  /// Se lee una sola vez: el archivo no cambia mientras la app corre, y esto
  /// es I/O síncrono que no tiene por qué repetirse.
  static Map<String, String> get valores => _valores ??= _leerArchivo();

  static AjustesCorreo? _correo;
  static bool _correoResuelto = false;

  /// Ajustes de correo, o `null` si el `.env` no los trae completos.
  static AjustesCorreo? get correo {
    if (!_correoResuelto) {
      _correo = ajustesCorreoDe(valores);
      _correoResuelto = true;
    }
    return _correo;
  }

  /// Reemplaza lo leído del disco. Solo para tests.
  static void sobrescribirParaTests(Map<String, String>? valores) {
    _valores = valores;
    _correoResuelto = false;
    _correo = null;
  }

  static Map<String, String> _leerArchivo() {
    for (final ruta in _rutasCandidatas()) {
      final archivo = File(ruta);
      if (archivo.existsSync()) {
        return parsearEnv(archivo.readAsStringSync());
      }
    }
    return const {};
  }

  static Iterable<String> _rutasCandidatas() sync* {
    yield p.join(Directory.current.path, '.env');
    yield p.join(p.dirname(Platform.resolvedExecutable), '.env');
  }
}

/// Convierte el texto de un `.env` en pares clave/valor.
///
/// Acepta líneas en blanco, comentarios con `#` y valores entre comillas
/// simples o dobles. Todo lo que no tenga un `=` se ignora, para que un
/// archivo mal escrito no impida arrancar.
Map<String, String> parsearEnv(String contenido) {
  final valores = <String, String>{};

  for (final linea in const LineSplitter().convert(contenido)) {
    final limpia = linea.trim();
    if (limpia.isEmpty || limpia.startsWith('#')) continue;

    final corte = limpia.indexOf('=');
    if (corte <= 0) continue;

    final clave = limpia.substring(0, corte).trim();
    var valor = limpia.substring(corte + 1).trim();

    if (valor.length >= 2 &&
        ((valor.startsWith('"') && valor.endsWith('"')) ||
            (valor.startsWith("'") && valor.endsWith("'")))) {
      valor = valor.substring(1, valor.length - 1);
    }

    valores[clave] = valor;
  }

  return valores;
}

/// Arma los ajustes de correo, o devuelve `null` si falta lo imprescindible.
///
/// Imprescindible es usuario, contraseña y host: sin los tres no hay envío
/// posible, y unos ajustes a medias fallarían en el primer correo en vez de
/// aquí, que es donde se puede avisar.
AjustesCorreo? ajustesCorreoDe(Map<String, String> valores) {
  String? dato(String clave) {
    final valor = valores[clave]?.trim();
    return (valor == null || valor.isEmpty) ? null : valor;
  }

  final usuario = dato('CORREO_USUARIO');
  final password = dato('CORREO_PASSWORD');
  final host = dato('CORREO_HOST');
  if (usuario == null || password == null || host == null) return null;

  return AjustesCorreo(
    host: host,
    puerto: int.tryParse(dato('CORREO_PUERTO') ?? '') ?? 587,
    usuario: usuario,
    password: password,
    ssl: (dato('CORREO_SSL') ?? 'false').toLowerCase() == 'true',
    remitente: dato('CORREO_REMITENTE') ?? usuario,
    nombreRemitente: dato('CORREO_NOMBRE') ?? 'InventarioK1',
  );
}
