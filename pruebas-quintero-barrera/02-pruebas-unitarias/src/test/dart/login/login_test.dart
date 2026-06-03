// Pruebas Unitarias — Módulo Login (Autenticación)
//
// Cómo ejecutar desde la raíz del proyecto Flutter:
//   flutter test pruebas-quintero-barrera/02-pruebas-unitarias/src/test/dart/login/login_test.dart
//
// Dependencias necesarias (ya en pubspec.yaml):
//   - bcrypt: ^1.2.0
//   - flutter_test (dev_dependency del SDK de Flutter)

import 'package:flutter_test/flutter_test.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:inventario_k1/backend/features/autenticacion/excepciones/excepciones_auth.dart';
import 'package:inventario_k1/backend/features/autenticacion/modelo/usuario.dart';

void main() {
  // =========================================================================
  // GROUP 1: Hashing de contraseñas con BCrypt
  // Valida la lógica de encriptación que usa RepositorioAuthImpl.registrarUsuario
  // =========================================================================
  group('Hashing de contraseñas — BCrypt', () {
    test(
      'UT-LG-01: El hash generado NO es igual a la contraseña en texto plano',
      () {
        const passwordPlano = 'Admin123!';
        final hash = BCrypt.hashpw(passwordPlano, BCrypt.gensalt());

        expect(hash, isNot(equals(passwordPlano)));
        expect(hash.length, greaterThan(20));
      },
    );

    test(
      'UT-LG-02: BCrypt.checkpw retorna true para la contraseña correcta',
      () {
        const passwordPlano = 'Seguro456@';
        final hash = BCrypt.hashpw(passwordPlano, BCrypt.gensalt());

        final esValida = BCrypt.checkpw(passwordPlano, hash);

        expect(esValida, isTrue);
      },
    );

    test(
      'UT-LG-03: BCrypt.checkpw retorna false para una contraseña incorrecta',
      () {
        const passwordPlano = 'Seguro456@';
        final hash = BCrypt.hashpw(passwordPlano, BCrypt.gensalt());

        final esValida = BCrypt.checkpw('WrongPass999', hash);

        expect(esValida, isFalse);
      },
    );

    test(
      'UT-LG-04: Dos hashes del mismo password son distintos (salt único por ejecución)',
      () {
        const passwordPlano = 'Admin123!';
        final hash1 = BCrypt.hashpw(passwordPlano, BCrypt.gensalt());
        final hash2 = BCrypt.hashpw(passwordPlano, BCrypt.gensalt());

        // Los hashes deben ser distintos porque el salt es aleatorio
        expect(hash1, isNot(equals(hash2)));
        // Pero ambos deben validar correctamente
        expect(BCrypt.checkpw(passwordPlano, hash1), isTrue);
        expect(BCrypt.checkpw(passwordPlano, hash2), isTrue);
      },
    );
  });

  // =========================================================================
  // GROUP 2: Clases de excepción de autenticación
  // Valida que las excepciones del dominio tienen los mensajes correctos
  // y pueden ser lanzadas/atrapadas por el manejador de errores de la UI
  // =========================================================================
  group('Excepciones de Autenticación', () {
    test(
      'UT-LG-05: CredencialesInvalidasException tiene mensaje por defecto correcto',
      () {
        const ex = CredencialesInvalidasException();

        expect(ex.toString(), equals('Correo o contraseña incorrectos.'));
        expect(ex, isA<Exception>());
      },
    );

    test(
      'UT-LG-06: UsuarioYaExisteException tiene mensaje por defecto correcto',
      () {
        const ex = UsuarioYaExisteException();

        // NOTA: Este mensaje dice "correo" pero también se lanza para nombre
        // de usuario duplicado (BUG-002 documentado en reporte de bugs)
        expect(ex.toString(), equals('El correo ya está registrado.'));
      },
    );

    test(
      'UT-LG-07: AccesoDesactivadoException tiene mensaje correcto',
      () {
        const ex = AccesoDesactivadoException();

        expect(
          ex.toString(),
          equals('Tu acceso ha sido desactivado por el administrador.'),
        );
      },
    );

    test(
      'UT-LG-08: SinPermisosException tiene mensaje correcto',
      () {
        const ex = SinPermisosException();

        expect(
          ex.toString(),
          equals('No tienes permisos para realizar esta acción.'),
        );
      },
    );

    test(
      'UT-LG-09: Las excepciones se pueden lanzar y atrapar con try/catch',
      () {
        expect(
          () => throw const CredencialesInvalidasException(),
          throwsA(isA<CredencialesInvalidasException>()),
        );

        expect(
          () => throw const AccesoDesactivadoException(),
          throwsA(isA<AccesoDesactivadoException>()),
        );

        expect(
          () => throw const SinPermisosException(),
          throwsA(isA<SinPermisosException>()),
        );
      },
    );
  });

  // =========================================================================
  // GROUP 3: Modelo Usuario
  // Valida la estructura y comportamiento del modelo de dominio Usuario
  // =========================================================================
  group('Modelo Usuario', () {
    final usuarioBase = Usuario(
      id: 1,
      nombre: 'Administrador',
      usuario: 'admin',
      email: 'admin@motostock.com',
      passwordHash: r'$2b$12$hash_de_ejemplo_que_no_es_plano',
      esAdmin: true,
      estaActivo: true,
      creadoEn: DateTime(2026, 1, 1),
    );

    test(
      'UT-LG-10: copyWith actualiza solo el campo especificado',
      () {
        final desactivado = usuarioBase.copyWith(estaActivo: false);

        expect(desactivado.estaActivo, isFalse);
        // Los demás campos no cambian
        expect(desactivado.usuario, equals('admin'));
        expect(desactivado.esAdmin, isTrue);
        expect(desactivado.id, equals(1));
      },
    );

    test(
      'UT-LG-11: Dos usuarios con mismo id son iguales (operador ==)',
      () {
        final usuario2 = usuarioBase.copyWith(nombre: 'Otro Nombre');
        expect(usuarioBase, equals(usuario2));
      },
    );

    test(
      'UT-LG-12: Usuario sin id es distinto a usuario con id (null != 1)',
      () {
        final sinId = Usuario(
          nombre: 'Nuevo',
          usuario: 'nuevo',
          email: 'nuevo@test.com',
          passwordHash: 'hash',
          creadoEn: DateTime.now(),
        );
        expect(sinId, isNot(equals(usuarioBase)));
      },
    );
  });
}
