import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/autenticacion/repositorio/repositorio_auth.dart';
import 'package:inventario_k1/backend/features/autenticacion/repositorio/repositorio_auth_impl.dart';
import 'package:inventario_k1/backend/features/autenticacion/resultado/resultados_auth.dart';
import 'package:inventario_k1/backend/features/persona/modelo/persona.dart';
import 'package:inventario_k1/backend/features/persona/repositorio/repositorio_persona.dart';
import 'package:inventario_k1/backend/features/persona/repositorio/repositorio_persona_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/backend/share/dominio/rol_usuario.dart';
import 'package:inventario_k1/core/resultado.dart';

import 'soporte/base_en_memoria.dart';

late AppDb db;
late RepositorioAuth auth;

/// Crea una cuenta y devuelve el usuario, fallando el test si no se pudo.
Future<int> _crear({
  String nombre = 'Juan García',
  String usuario = 'juan',
  String email = 'juan@taller.com',
  String password = 'clave-larga-1',
  RolUsuario rol = RolUsuario.admin,
  String? documento,
}) async {
  final resultado = await auth.crearCuenta(
    nombre: nombre,
    usuario: usuario,
    email: email,
    password: password,
    rol: rol,
    documento: documento,
  );

  expect(resultado, isA<CuentaCreada>());
  return (resultado as CuentaCreada).usuario.id;
}

void main() {
  setUp(() {
    db = baseEnMemoria();
    auth = RepositorioAuthImpl(db);
  });

  tearDown(() => db.close());

  group('alta de cuentas', () {
    test('la base recién creada no tiene ninguna cuenta', () async {
      expect(await auth.hayUsuarios(), isFalse);
      await _crear();
      expect(await auth.hayUsuarios(), isTrue);
    });

    test('el usuario y el correo se guardan normalizados', () async {
      final id = await _crear(usuario: '  JUAN  ', email: '  Juan@Taller.COM ');
      final creado = await auth.obtenerPorId(id);

      expect(creado!.usuario, 'juan');
      expect(creado.email, 'juan@taller.com');
    });

    test('no deja repetir el usuario ni el correo', () async {
      await _crear(usuario: 'juan', email: 'juan@taller.com');

      expect(
        await auth.crearCuenta(
          nombre: 'Otro',
          usuario: 'JUAN',
          email: 'otro@taller.com',
          password: 'clave-larga-1',
          rol: RolUsuario.cajero,
        ),
        isA<UsuarioEnUso>(),
      );

      expect(
        await auth.crearCuenta(
          nombre: 'Otro',
          usuario: 'otro',
          email: 'JUAN@taller.com',
          password: 'clave-larga-1',
          rol: RolUsuario.cajero,
        ),
        isA<CorreoEnUso>(),
      );

      // Ninguno de los dos intentos puede haber dejado una persona suelta: la
      // cuenta y la persona nacen en la misma transacción.
      final personas = await db.select(db.tablaPersona).get();
      expect(personas, hasLength(1));
    });

    test('reutiliza la persona cuando el documento ya existe', () async {
      final RepositorioPersona personas = RepositorioPersonaImpl(db);
      final personaId = await personas.guardar(
        const DatosPersona(documento: '1144', nombres: 'Ana', telefono: '300'),
      );

      final cuentaId = await _crear(
        nombre: 'Ana',
        usuario: 'ana',
        email: 'ana@taller.com',
        documento: '1144',
      );

      final cuenta = await auth.obtenerPorId(cuentaId);
      expect(cuenta!.personaId, personaId);
      expect(await db.select(db.tablaPersona).get(), hasLength(1));
    });

    test('la base rechaza un rol que no existe', () async {
      // El `CHECK` de `usuarios` es la garantía real: el enum de Dart solo
      // protege al código que pasa por él.
      await _crear();
      expect(
        db.customStatement("UPDATE usuarios SET rol = 'BODEGUERO'"),
        throwsA(anything),
      );
    });
  });

  group('entrar', () {
    setUp(() => _crear(usuario: 'juan', email: 'juan@taller.com'));

    test('entra con el usuario', () async {
      final r = await auth.autenticar(
        identificador: 'juan',
        password: 'clave-larga-1',
      );
      expect(r, isA<AccesoConcedido>());
      expect((r as AccesoConcedido).usuario.rol, RolUsuario.admin);
    });

    test('entra con el correo, sin importar mayúsculas', () async {
      expect(
        await auth.autenticar(
          identificador: '  JUAN@Taller.com ',
          password: 'clave-larga-1',
        ),
        isA<AccesoConcedido>(),
      );
    });

    test('la contraseña equivocada no entra', () async {
      expect(
        await auth.autenticar(identificador: 'juan', password: 'otra-cosa-99'),
        isA<CredencialesIncorrectas>(),
      );
    });

    test('un usuario que no existe da el mismo resultado', () async {
      expect(
        await auth.autenticar(
          identificador: 'nadie',
          password: 'clave-larga-1',
        ),
        isA<CredencialesIncorrectas>(),
      );
    });

    test('una cuenta desactivada no entra, aunque la clave sea correcta',
        () async {
      final adminId = (await auth.obtenerPorIdentificador('juan'))!.id;
      final cajeroId = await _crear(
        nombre: 'Ana',
        usuario: 'ana',
        email: 'ana@taller.com',
        rol: RolUsuario.cajero,
      );

      await auth.cambiarEstado(
        adminId: adminId,
        usuarioId: cajeroId,
        activo: false,
      );

      expect(
        await auth.autenticar(
          identificador: 'ana',
          password: 'clave-larga-1',
        ),
        isA<CuentaDesactivada>(),
      );
    });
  });

  group('contraseña', () {
    test('rechaza una más corta que el mínimo', () async {
      final id = await _crear();
      final r = await auth.cambiarPassword(usuarioId: id, passwordNueva: '123');

      expect(r, isA<Fallo>());
      expect((r as Fallo).motivo, MotivoFallo.validacion);
    });

    test('la nueva entra y la vieja deja de servir', () async {
      final id = await _crear();
      expect(
        await auth.cambiarPassword(
          usuarioId: id,
          passwordNueva: 'otra-clave-larga',
        ),
        isA<Exito>(),
      );

      expect(
        await auth.autenticar(
          identificador: 'juan',
          password: 'otra-clave-larga',
        ),
        isA<AccesoConcedido>(),
      );
      expect(
        await auth.autenticar(
          identificador: 'juan',
          password: 'clave-larga-1',
        ),
        isA<CredencialesIncorrectas>(),
      );
    });
  });

  group('administrar cuentas', () {
    late int adminId;
    late int cajeroId;

    setUp(() async {
      adminId = await _crear();
      cajeroId = await _crear(
        nombre: 'Ana',
        usuario: 'ana',
        email: 'ana@taller.com',
        rol: RolUsuario.cajero,
      );
    });

    test('un cajero no puede desactivar a nadie', () async {
      final r = await auth.cambiarEstado(
        adminId: cajeroId,
        usuarioId: adminId,
        activo: false,
      );

      expect(r, isA<Fallo>());
      expect((await auth.obtenerPorId(adminId))!.estaActivo, isTrue);
    });

    test('un admin desactivado tampoco puede', () async {
      final otroAdmin = await _crear(
        nombre: 'Luis',
        usuario: 'luis',
        email: 'luis@taller.com',
      );
      await auth.cambiarEstado(
        adminId: adminId,
        usuarioId: otroAdmin,
        activo: false,
      );

      final r = await auth.cambiarEstado(
        adminId: otroAdmin,
        usuarioId: cajeroId,
        activo: false,
      );
      expect(r, isA<Fallo>());
    });

    test('el admin cambia el rol de un cajero', () async {
      expect(
        await auth.cambiarRol(
          adminId: adminId,
          usuarioId: cajeroId,
          rol: RolUsuario.admin,
        ),
        isA<Exito>(),
      );
      expect((await auth.obtenerPorId(cajeroId))!.rol, RolUsuario.admin);
    });

    test('el último administrador activo no se puede desactivar', () async {
      final r = await auth.cambiarEstado(
        adminId: adminId,
        usuarioId: adminId,
        activo: false,
      );

      expect(r, isA<Fallo>());
      expect((r as Fallo).motivo, MotivoFallo.validacion);
      expect((await auth.obtenerPorId(adminId))!.estaActivo, isTrue);
    });

    test('ni bajarlo a cajero', () async {
      expect(
        await auth.cambiarRol(
          adminId: adminId,
          usuarioId: adminId,
          rol: RolUsuario.cajero,
        ),
        isA<Fallo>(),
      );
      expect((await auth.obtenerPorId(adminId))!.rol, RolUsuario.admin);
    });

    test('con otro admin activo, el primero sí puede salir', () async {
      await auth.cambiarRol(
        adminId: adminId,
        usuarioId: cajeroId,
        rol: RolUsuario.admin,
      );

      expect(
        await auth.cambiarEstado(
          adminId: adminId,
          usuarioId: adminId,
          activo: false,
        ),
        isA<Exito>(),
      );
    });

    test('observarUsuarios los emite en orden de creación', () async {
      expect(
        await auth.observarUsuarios().first,
        [
          isA<dynamic>().having((u) => u.usuario, 'usuario', 'juan'),
          isA<dynamic>().having((u) => u.usuario, 'usuario', 'ana'),
        ],
      );
    });
  });
}
