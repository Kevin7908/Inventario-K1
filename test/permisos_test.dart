// Los permisos, que se configuran y no se programan.
//
// Lo que fijan estos tests es lo que hace que un interruptor de la pantalla
// signifique algo: la compuerta vive en el **repositorio**, así que da igual
// que una vista se olvide de esconder el botón.
//
// Y lo que no protegen: el `.sqlite` está en el disco del taller. Esto evita
// la equivocación, no a alguien decidido a saltárselo.
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/autenticacion/repositorio/repositorio_auth_impl.dart';
import 'package:inventario_k1/backend/features/autenticacion/resultado/resultados_auth.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';
import 'package:inventario_k1/backend/features/productos/repositorio/repositorio_producto_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/backend/share/dominio/permiso.dart';
import 'package:inventario_k1/backend/share/dominio/rol_usuario.dart';
import 'package:inventario_k1/backend/share/dominio/sesion_actual.dart';
import 'package:inventario_k1/core/resultado.dart';

import 'soporte/base_en_memoria.dart';
import 'soporte/sesion_de_prueba.dart';

late AppDb db;

/// Quien firma lo que escriben estos tests. Ver `sesionDePrueba`.
late SesionActual sesion;

late RepositorioAuthImpl auth;

Producto _producto({String sku = 'ACE-1'}) => Producto(
      sku: sku,
      nombre: 'Aceite 20W50',
      precioCompra: 25000,
      precioVenta: 40000,
      stockActual: 0,
      stockMinimo: 0,
      aplicaIva: true,
      activo: true,
    );

/// Una sesión de cajero con exactamente los permisos que se le pasen.
SesionActual _cajeroCon(Set<Permiso> permisos) => SesionActual(
      usuarioId: sesion.usuarioId,
      rol: RolUsuario.cajero,
      permisos: permisos,
    );

void main() {
  setUp(() async {
    db = baseEnMemoria();
    sesion = await sesionDePrueba(db);
    auth = RepositorioAuthImpl(db, sesion);
  });

  tearDown(() => db.close());

  group('la compuerta está en el repositorio', () {
    test('sin el permiso de borrar, el producto sigue ahí', () async {
      final admin = RepositorioProductosImpl(db, sesion);
      final creado = await admin.crear(_producto());

      final cajero = RepositorioProductosImpl(
        db,
        _cajeroCon({Permiso.productosVer, Permiso.productosCrear}),
      );

      expect(
        () => cajero.eliminar(creado.id!),
        throwsA(isA<PermisoDenegado>()),
      );
      expect(await admin.obtenerPorId(creado.id!), isNotNull);
    });

    test('con el permiso, sí borra', () async {
      final admin = RepositorioProductosImpl(db, sesion);
      final creado = await admin.crear(_producto());

      final cajero = RepositorioProductosImpl(
        db,
        _cajeroCon({Permiso.productosEliminar}),
      );

      await cajero.eliminar(creado.id!);
      expect(await admin.obtenerPorId(creado.id!), isNull);
    });

    test('ajustar stock a mano es su propio permiso', () async {
      final admin = RepositorioProductosImpl(db, sesion);
      final creado = await admin.crear(_producto());

      // Puede editar la ficha pero no corregir existencias: son cosas
      // distintas y por eso son dos interruptores.
      final cajero = RepositorioProductosImpl(
        db,
        _cajeroCon({Permiso.productosVer, Permiso.productosEditar}),
      );

      await expectLater(
        cajero.ajustarStock(creado.id!, 5),
        throwsA(isA<PermisoDenegado>()),
      );
    });

    test('el mensaje nombra la acción, no el código', () {
      const denegado = PermisoDenegado(Permiso.productosEliminar);

      expect(denegado.mensaje, contains('eliminar productos'));
      expect(denegado.mensaje, isNot(contains('PRODUCTOS_ELIMINAR')));
    });

    test('sin sesión no puede nada', () {
      final anonimo = RepositorioProductosImpl(db, null);

      // Con closure y no con `expectLater(anonimo.crear(...))`: la compuerta
      // es lo primero del método, así que en los de cuerpo síncrono lanza
      // **antes** de devolver el `Future`. Está documentado en `exigir`.
      expect(
        () => anonimo.crear(_producto()),
        throwsA(isA<PermisoDenegado>()),
      );
    });
  });

  group('qué permisos tiene cada cuenta', () {
    test('un administrador los tiene todos, sin fila que los guarde',
        () async {
      expect(
        await auth.permisosDe(sesion.usuarioId),
        Permiso.values.toSet(),
      );
      expect(await db.select(db.tablaUsuarioPermiso).get(), isEmpty);
    });

    test('un cajero nace con los de su rol, y sin poder borrar nada',
        () async {
      final creada = await auth.crearCuenta(
        nombre: 'Ana',
        usuario: 'ana',
        email: 'ana@taller.com',
        password: 'clave-larga-1',
        rol: RolUsuario.cajero,
      );

      final permisos = await auth.permisosDe((creada as CuentaCreada).usuario.id);

      expect(permisos, RolUsuario.cajero.permisosPorDefecto);
      expect(permisos, contains(Permiso.posVender));
      expect(permisos, isNot(contains(Permiso.productosEliminar)));
      expect(permisos, isNot(contains(Permiso.posAnular)));
      expect(permisos, isNot(contains(Permiso.usuariosAdministrar)));
    });

    test('fijar permisos reemplaza el conjunto entero', () async {
      final creada = await auth.crearCuenta(
        nombre: 'Ana',
        usuario: 'ana',
        email: 'ana@taller.com',
        password: 'clave-larga-1',
        rol: RolUsuario.cajero,
      );
      final anaId = (creada as CuentaCreada).usuario.id;

      final resultado = await auth.fijarPermisos(
        adminId: sesion.usuarioId,
        usuarioId: anaId,
        permisos: {Permiso.posVer, Permiso.posVender},
      );

      expect(resultado, isA<Exito>());
      expect(await auth.permisosDe(anaId), {Permiso.posVer, Permiso.posVender});
    });

    test('los de un administrador no se editan', () async {
      final resultado = await auth.fijarPermisos(
        adminId: sesion.usuarioId,
        usuarioId: sesion.usuarioId,
        permisos: {Permiso.posVer},
      );

      expect(resultado, isA<Fallo>());
      expect((resultado as Fallo).motivo, MotivoFallo.validacion);
      expect(await auth.permisosDe(sesion.usuarioId), Permiso.values.toSet());
    });

    test('un cajero no puede fijarle permisos a nadie', () async {
      final creada = await auth.crearCuenta(
        nombre: 'Ana',
        usuario: 'ana',
        email: 'ana@taller.com',
        password: 'clave-larga-1',
        rol: RolUsuario.cajero,
      );
      final anaId = (creada as CuentaCreada).usuario.id;

      final resultado = await auth.fijarPermisos(
        adminId: anaId,
        usuarioId: anaId,
        permisos: Permiso.values.toSet(),
      );

      expect(resultado, isA<Fallo>());
    });

    test('cambiar el rol vuelve a poner los permisos del rol nuevo', () async {
      final creada = await auth.crearCuenta(
        nombre: 'Ana',
        usuario: 'ana',
        email: 'ana@taller.com',
        password: 'clave-larga-1',
        rol: RolUsuario.cajero,
      );
      final anaId = (creada as CuentaCreada).usuario.id;

      await auth.fijarPermisos(
        adminId: sesion.usuarioId,
        usuarioId: anaId,
        permisos: {Permiso.posVer},
      );

      await auth.cambiarRol(
        adminId: sesion.usuarioId,
        usuarioId: anaId,
        rol: RolUsuario.admin,
      );
      expect(await auth.permisosDe(anaId), Permiso.values.toSet());

      await auth.cambiarRol(
        adminId: sesion.usuarioId,
        usuarioId: anaId,
        rol: RolUsuario.cajero,
      );
      expect(await auth.permisosDe(anaId), RolUsuario.cajero.permisosPorDefecto);
    });

    test('la base rechaza un permiso que no existe', () async {
      // El `CHECK` es la garantía; el enum de Dart solo protege al código que
      // pasa por él.
      final creada = await auth.crearCuenta(
        nombre: 'Ana',
        usuario: 'ana',
        email: 'ana@taller.com',
        password: 'clave-larga-1',
        rol: RolUsuario.cajero,
      );
      final anaId = (creada as CuentaCreada).usuario.id;

      expect(
        db.customStatement(
          'INSERT INTO usuario_permisos (usuario_id, permiso) VALUES (?, ?)',
          [anaId, 'BORRAR_TODO'],
        ),
        throwsA(anything),
      );
    });

    test('borrar la cuenta se lleva sus permisos', () async {
      final creada = await auth.crearCuenta(
        nombre: 'Ana',
        usuario: 'ana',
        email: 'ana@taller.com',
        password: 'clave-larga-1',
        rol: RolUsuario.cajero,
      );
      final anaId = (creada as CuentaCreada).usuario.id;

      expect(await auth.permisosDe(anaId), isNotEmpty);

      // `cascade`: los permisos no son un documento contable, son un detalle
      // de la cuenta.
      await db.customStatement('DELETE FROM usuarios WHERE id = ?', [anaId]);

      final restantes = await db.select(db.tablaUsuarioPermiso).get();
      expect(restantes.where((p) => p.usuarioId == anaId), isEmpty);
    });
  });
}
