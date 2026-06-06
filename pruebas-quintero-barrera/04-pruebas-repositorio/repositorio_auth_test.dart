// Pruebas de Repositorio — Módulo Login (RepositorioAuthImpl)
// Equivalente a colección Postman: prueba la CAPA DE DATOS real con BD en memoria
//
// Cómo ejecutar desde la raíz del proyecto Flutter:
//   flutter test pruebas-quintero-barrera/04-pruebas-repositorio/repositorio_auth_test.dart
//
// Dependencias necesarias (ya en pubspec.yaml):
//   - drift: ^2.32.1   (NativeDatabase.memory())
//   - bcrypt: ^1.2.0
//   - flutter_test

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/autenticacion/excepciones/excepciones_auth.dart';
import 'package:inventario_k1/backend/features/autenticacion/modelo/usuario.dart';
import 'package:inventario_k1/backend/features/autenticacion/repositorio/repositorio_auth_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

void main() {
  late AppDb db;
  late RepositorioAuthImpl repo;

  // Inicializa una BD SQLite completamente en memoria antes de cada test
  // → ningún archivo se escribe en disco → tests aislados y reproducibles
  setUp(() {
    db = AppDb(NativeDatabase.memory());
    repo = RepositorioAuthImpl(db);
  });

  // Cierra la BD en memoria al terminar cada test para liberar recursos
  tearDown(() async {
    await db.close();
  });

  // ===========================================================================
  // GROUP 1: registrarUsuario
  // Equivalente a: POST /api/auth/register en Postman
  // ===========================================================================
  group('REP-AUTH — registrarUsuario', () {
    test(
      'RP-LG-01: Registrar usuario válido retorna un Usuario con id asignado',
      () async {
        final usuario = await repo.registrarUsuario(
          nombre: 'Kevin Prueba',
          usuario: 'kevin_test',
          email: 'kevin@test.com',
          passwordPlano: 'Seguro123!',
        );

        expect(usuario.id, isNotNull);
        expect(usuario.usuario, equals('kevin_test'));
        expect(usuario.email, equals('kevin@test.com'));
        expect(usuario.estaActivo, isTrue);
        // El hash NO es igual a la contraseña plana
        expect(usuario.passwordHash, isNot(equals('Seguro123!')));
      },
    );

    test(
      'RP-LG-02: Registrar usuario con nombre de usuario duplicado lanza UsuarioYaExisteException',
      () async {
        await repo.registrarUsuario(
          nombre: 'Usuario Original',
          usuario: 'duplicado',
          email: 'original@test.com',
          passwordPlano: 'Pass123!',
        );

        // Intentar registrar otro con el mismo nombre de usuario
        expect(
          () => repo.registrarUsuario(
            nombre: 'Usuario Duplicado',
            usuario: 'duplicado', // mismo usuario
            email: 'otro@test.com',
            passwordPlano: 'Pass456!',
          ),
          throwsA(isA<UsuarioYaExisteException>()),
          reason: 'RP-LG-02: Debe lanzar UsuarioYaExisteException para usuario duplicado',
        );
      },
    );

    test(
      'RP-LG-03: Registrar usuario con email duplicado lanza UsuarioYaExisteException',
      () async {
        await repo.registrarUsuario(
          nombre: 'Usuario 1',
          usuario: 'usuario1',
          email: 'mismo@email.com',
          passwordPlano: 'Pass123!',
        );

        expect(
          () => repo.registrarUsuario(
            nombre: 'Usuario 2',
            usuario: 'usuario2',
            email: 'mismo@email.com', // mismo email
            passwordPlano: 'Pass456!',
          ),
          throwsA(isA<UsuarioYaExisteException>()),
        );
      },
    );

    test(
      'RP-LG-04: El usuario se guarda con usuario en minúsculas (normalización)',
      () async {
        final usuario = await repo.registrarUsuario(
          nombre: 'Test Mayus',
          usuario: 'ADMIN_MAYUS',
          email: 'test@mayus.com',
          passwordPlano: 'Pass123!',
        );

        expect(usuario.usuario, equals('admin_mayus'));
        expect(usuario.email, equals('test@mayus.com'));
      },
    );
  });

  // ===========================================================================
  // GROUP 2: verificarCredenciales
  // Equivalente a: POST /api/auth/login en Postman
  // ===========================================================================
  group('REP-AUTH — verificarCredenciales', () {
    // Registrar un usuario activo antes de los tests de este grupo
    late Usuario usuarioActivo;
    late Usuario usuarioInactivo;

    setUp(() async {
      usuarioActivo = await repo.registrarUsuario(
        nombre: 'Admin',
        usuario: 'admin',
        email: 'admin@test.com',
        passwordPlano: 'Admin123!',
        esAdmin: true,
      );
      usuarioInactivo = await repo.registrarUsuario(
        nombre: 'Inactivo',
        usuario: 'inactivo',
        email: 'inactivo@test.com',
        passwordPlano: 'Inact123!',
      );
      // Desactivar al segundo usuario
      await repo.cambiarEstadoActivo(
        adminId: usuarioActivo.id!,
        usuarioId: usuarioInactivo.id!,
        nuevoEstado: false,
      );
    });

    test(
      'RP-LG-05: Credenciales correctas retornan el objeto Usuario',
      () async {
        final resultado = await repo.verificarCredenciales(
          usuario: 'admin',
          passwordPlano: 'Admin123!',
        );

        expect(resultado.usuario, equals('admin'));
        expect(resultado.estaActivo, isTrue);
      },
    );

    test(
      'RP-LG-06: Contraseña incorrecta lanza CredencialesInvalidasException',
      () async {
        expect(
          () => repo.verificarCredenciales(
            usuario: 'admin',
            passwordPlano: 'WrongPass',
          ),
          throwsA(isA<CredencialesInvalidasException>()),
        );
      },
    );

    test(
      'RP-LG-07: Usuario inexistente lanza CredencialesInvalidasException',
      () async {
        expect(
          () => repo.verificarCredenciales(
            usuario: 'no_existe',
            passwordPlano: 'cualquiera',
          ),
          throwsA(isA<CredencialesInvalidasException>()),
        );
      },
    );

    test(
      'RP-LG-08: Usuario inactivo lanza AccesoDesactivadoException',
      () async {
        expect(
          () => repo.verificarCredenciales(
            usuario: 'inactivo',
            passwordPlano: 'Inact123!',
          ),
          throwsA(isA<AccesoDesactivadoException>()),
        );
      },
    );
  });

  // ===========================================================================
  // GROUP 3: cambiarEstadoActivo
  // Equivalente a: PUT /api/users/{id}/status en Postman
  // ===========================================================================
  group('REP-AUTH — cambiarEstadoActivo', () {
    test(
      'RP-LG-09: No-administrador no puede cambiar el estado de otro usuario',
      () async {
        final noAdmin = await repo.registrarUsuario(
          nombre: 'No Admin',
          usuario: 'no_admin',
          email: 'noadmin@test.com',
          passwordPlano: 'Pass123!',
          esAdmin: false,
        );
        final objetivo = await repo.registrarUsuario(
          nombre: 'Objetivo',
          usuario: 'objetivo',
          email: 'objetivo@test.com',
          passwordPlano: 'Pass456!',
        );

        expect(
          () => repo.cambiarEstadoActivo(
            adminId: noAdmin.id!,
            usuarioId: objetivo.id!,
            nuevoEstado: false,
          ),
          throwsA(isA<SinPermisosException>()),
          reason: 'RP-LG-09: Un usuario sin rol admin no debe poder desactivar otros',
        );
      },
    );
  });

  // ===========================================================================
  // GROUP 4: obtenerPorUsuario y obtenerPorId
  // Equivalente a: GET /api/users en Postman
  // ===========================================================================
  group('REP-AUTH — consultas', () {
    test(
      'RP-LG-10: obtenerPorUsuario retorna el usuario correcto o null',
      () async {
        await repo.registrarUsuario(
          nombre: 'Encontrable',
          usuario: 'encontrable',
          email: 'encontrable@test.com',
          passwordPlano: 'Pass123!',
        );

        final encontrado = await repo.obtenerPorUsuario('encontrable');
        final noExiste = await repo.obtenerPorUsuario('no_existe');

        expect(encontrado, isNotNull);
        expect(encontrado!.usuario, equals('encontrable'));
        expect(noExiste, isNull);
      },
    );
  });
}
