// El `.env` y lo que sale de él.
//
// Lo que fijan estos tests es lo que ya no se puede ver en el código: que las
// credenciales del correo salen de un archivo, y que si el archivo falta la
// app **no** revienta —el envío queda desactivado y el resultado lo dice—.
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/share/config/entorno.dart';
import 'package:inventario_k1/backend/share/servicios/servicio_correo.dart';

void main() {
  group('parsear un .env', () {
    test('lee pares clave=valor y se salta comentarios y líneas vacías', () {
      final valores = parsearEnv('''
# esto es un comentario
CORREO_USUARIO=taller@gmail.com

CORREO_PUERTO=587
''');

      expect(valores, {
        'CORREO_USUARIO': 'taller@gmail.com',
        'CORREO_PUERTO': '587',
      });
    });

    test('quita las comillas y respeta los = del valor', () {
      final valores = parsearEnv(
        'CORREO_PASSWORD="abcd efgh ijkl"\nOTRA=\'a=b\'\n',
      );

      expect(valores['CORREO_PASSWORD'], 'abcd efgh ijkl');
      expect(valores['OTRA'], 'a=b');
    });

    test('una línea sin = no rompe el archivo', () {
      expect(parsearEnv('basura\nCORREO_HOST=smtp.gmail.com'), {
        'CORREO_HOST': 'smtp.gmail.com',
      });
    });
  });

  group('ajustes de correo', () {
    test('sin usuario, contraseña o host no hay ajustes', () {
      expect(ajustesCorreoDe(const {}), isNull);
      expect(
        ajustesCorreoDe(const {
          'CORREO_USUARIO': 'taller@gmail.com',
          'CORREO_HOST': 'smtp.gmail.com',
        }),
        isNull,
      );
    });

    test('una clave presente pero vacía cuenta como ausente', () {
      expect(
        ajustesCorreoDe(const {
          'CORREO_USUARIO': 'taller@gmail.com',
          'CORREO_PASSWORD': '   ',
          'CORREO_HOST': 'smtp.gmail.com',
        }),
        isNull,
      );
    });

    test('con las tres claves arma los ajustes y completa lo demás', () {
      final ajustes = ajustesCorreoDe(const {
        'CORREO_USUARIO': 'taller@gmail.com',
        'CORREO_PASSWORD': 'abcd efgh',
        'CORREO_HOST': 'smtp.gmail.com',
      })!;

      expect(ajustes.puerto, 587);
      expect(ajustes.ssl, isFalse);
      expect(ajustes.remitente, 'taller@gmail.com');
      expect(ajustes.nombreRemitente, 'InventarioK1');
    });

    test('un puerto que no es número cae en el 587 en vez de reventar', () {
      final ajustes = ajustesCorreoDe(const {
        'CORREO_USUARIO': 'taller@gmail.com',
        'CORREO_PASSWORD': 'abcd',
        'CORREO_HOST': 'smtp.gmail.com',
        'CORREO_PUERTO': 'quinientos',
      })!;

      expect(ajustes.puerto, 587);
    });
  });

  group('el servicio de correo sin configurar', () {
    test('no manda nada y lo dice, en vez de fallar', () async {
      final servicio = ServicioCorreo(null);

      expect(servicio.estaConfigurado, isFalse);
      expect(
        await servicio.enviarCodigoRecuperacion(
          email: 'ana@taller.com',
          codigo: '123456',
          nombre: 'Ana',
          minutosVigencia: 10,
        ),
        isA<CorreoNoConfigurado>(),
      );
    });

    test('con ajustes pero sin destinatario tampoco intenta el envío',
        () async {
      final servicio = ServicioCorreo(
        const AjustesCorreo(
          host: 'smtp.invalido',
          puerto: 587,
          usuario: 'taller@gmail.com',
          password: 'x',
          ssl: false,
          remitente: 'taller@gmail.com',
          nombreRemitente: 'InventarioK1',
        ),
      );

      expect(
        await servicio.enviarBienvenida(
          email: '',
          nombre: 'Ana',
          usuario: 'ana',
          rol: 'Cajero',
        ),
        isA<CorreoFallido>(),
      );
    });
  });
}
