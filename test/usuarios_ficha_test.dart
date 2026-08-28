// La pantalla de Configuración → Usuarios y la ficha de cada cuenta.
//
// Los permisos se editaban en un diálogo. Ahora la fila abre una **ficha**,
// como el detalle de una deuda o de un producto, y eso son tres decisiones que
// el analizador no ve:
//
// - tocar una fila lleva a la ficha de esa cuenta, no a un modal;
// - a un administrador no se le ofrecen interruptores, porque los tiene todos;
// - «Volver a las cuentas» devuelve al listado sin haber guardado nada.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/autenticacion/modelo/usuario.dart';
import 'package:inventario_k1/backend/share/dominio/permiso.dart';
import 'package:inventario_k1/backend/share/dominio/rol_usuario.dart';
import 'package:inventario_k1/frontend/features/autenticacion/provider/auth_providers.dart';
import 'package:inventario_k1/frontend/features/autenticacion/vista/usuario_detalle_vista.dart';
import 'package:inventario_k1/frontend/features/autenticacion/vista/usuarios_vista.dart';

import 'soporte/repositorio_auth_falso.dart';

final _admin = usuarioDePrueba(id: 1, nombre: 'Juan García', usuario: 'juan');

final _cajero = usuarioDePrueba(
  id: 2,
  nombre: 'Marta Ríos',
  usuario: 'marta',
  email: 'marta@taller.com',
  rol: RolUsuario.cajero,
);

Future<void> _montar(
  WidgetTester tester,
  RepositorioAuthFalso auth, {
  Usuario? enSesion,
}) async {
  // Una ventana de escritorio de verdad: la tabla son seis columnas y los 800
  // px que trae un test por defecto no son un tamaño en el que esta pantalla
  // se use nunca.
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositorioAuthProvider.overrideWithValue(auth),
        repositorioAuthAnonimoProvider.overrideWithValue(auth),
        // La sesión se inyecta ya abierta: lo que se está probando es la
        // pantalla, no cómo se entra.
        usuarioEnSesionProvider.overrideWithValue(enSesion ?? _admin),
      ],
      child: const MaterialApp(
        home: Scaffold(body: Padding(padding: EdgeInsets.all(16), child: UsuariosVista())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('el listado lleva a la ficha', () {
    testWidgets('tocar una cuenta abre su ficha, sin diálogo', (tester) async {
      await _montar(
        tester,
        RepositorioAuthFalso(lista: [_admin, _cajero]),
      );

      expect(find.byType(UsuarioDetalleVista), findsNothing);

      await tester.tap(find.text('Marta Ríos'));
      await tester.pumpAndSettle();

      expect(find.byType(UsuarioDetalleVista), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      // La ficha dice de quién es antes que qué puede hacer.
      expect(find.text('marta@taller.com'), findsOneWidget);
    });

    testWidgets('la ficha de un cajero trae sus interruptores',
        (tester) async {
      await _montar(
        tester,
        RepositorioAuthFalso(
          lista: [_admin, _cajero],
          permisosPorCuenta: {_cajero.id: {Permiso.productosVer}},
        ),
      );

      await tester.tap(find.text('Marta Ríos'));
      await tester.pumpAndSettle();

      expect(find.text('Guardar permisos'), findsOneWidget);
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('a un administrador no se le ofrecen permisos',
        (tester) async {
      await _montar(tester, RepositorioAuthFalso(lista: [_admin, _cajero]));

      await tester.tap(find.text('Juan García'));
      await tester.pumpAndSettle();

      expect(find.byType(UsuarioDetalleVista), findsOneWidget);
      expect(find.textContaining('Un administrador puede todo'), findsOneWidget);
      expect(find.text('Guardar permisos'), findsNothing);
    });

    testWidgets('volver deja el listado como estaba y no guarda nada',
        (tester) async {
      final auth = RepositorioAuthFalso(
        lista: [_admin, _cajero],
        permisosPorCuenta: {_cajero.id: {Permiso.productosVer}},
      );
      await _montar(tester, auth);

      await tester.tap(find.text('Marta Ríos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver a las cuentas'));
      await tester.pumpAndSettle();

      expect(find.byType(UsuarioDetalleVista), findsNothing);
      expect(find.text('Nueva cuenta'), findsOneWidget);
      expect(auth.permisosGuardados, isNull);
    });
  });
}
