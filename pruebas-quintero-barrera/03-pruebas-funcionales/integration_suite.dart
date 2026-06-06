// Suite de Pruebas Funcionales — InventarioK1
// Ejecutar desde la raíz del proyecto:
//   flutter test -d linux integration_test/integration_suite.dart
//
// Este archivo es la fuente. El archivo en integration_test/ es una copia.
// Si editas este, copia los cambios también a integration_test/integration_suite.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inventario_k1/backend/share/database/locator.dart';
import 'package:inventario_k1/frontend/features/autenticacion/vista/inicio_sesion_vista.dart';
import 'package:inventario_k1/frontend/share/nav/navegacion.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Resetea GetIt entre tests para evitar "Type X is already registered"
  setUp(() async {
    await GetIt.instance.reset();
    setupLocator();
  });

  // Helper — envuelve InicioSesionVista con el MaterialApp mínimo necesario.
  // InicioSesionVista provee su propio ChangeNotifierProvider<AuthViewModel>
  // internamente, así que solo necesita un Navigator (lo da MaterialApp).
  Widget appLogin() => const MaterialApp(home: InicioSesionVista());

  // ===========================================================================
  // CP-001: Pantalla de login carga con los campos esperados
  // ===========================================================================
  group('CP-001: Pantalla de login carga correctamente', () {
    testWidgets(
      'Los campos de usuario, contraseña y el botón son visibles',
      (tester) async {
        await tester.pumpWidget(appLogin());
        await tester.pumpAndSettle();

        expect(
          find.byType(TextFormField),
          findsAtLeastNWidgets(2),
          reason: 'Deben existir al menos 2 campos: usuario y contraseña',
        );
        expect(find.text('Inicia sesión para continuar'), findsOneWidget);
        expect(find.text('Iniciar sesión'), findsOneWidget);
      },
    );
  });

  // ===========================================================================
  // CP-002: Credenciales inválidas — permanece en login
  // ===========================================================================
  group('CP-002: Login con contraseña incorrecta', () {
    testWidgets(
      'Credenciales inválidas no navegan al dashboard',
      (tester) async {
        await tester.pumpWidget(appLogin());
        await tester.pumpAndSettle();

        final campos = find.byType(TextFormField);
        await tester.enterText(campos.at(0), 'usuario_que_no_existe');
        await tester.enterText(campos.at(1), 'claveIncorrecta99');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Iniciar sesión'));
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Debe seguir en login: los campos aún están visibles
        expect(
          find.byType(TextFormField),
          findsWidgets,
          reason: 'CP-002: Con credenciales inválidas debe permanecer en login',
        );
      },
    );
  });

  // ===========================================================================
  // CP-004: Campos vacíos — validación del formulario
  // ===========================================================================
  group('CP-004: Login con campos vacíos', () {
    testWidgets(
      'El formulario activa validación local sin consultar la BD',
      (tester) async {
        await tester.pumpWidget(appLogin());
        await tester.pumpAndSettle();

        // Presionar el botón sin llenar ningún campo
        await tester.tap(find.text('Iniciar sesión'));
        await tester.pumpAndSettle();

        // Los mensajes de validación del Form deben aparecer
        expect(
          find.text('El usuario es requerido'),
          findsOneWidget,
          reason: 'CP-004: Validación del campo usuario debe activarse',
        );
        expect(
          find.text('La contraseña es requerida'),
          findsOneWidget,
          reason: 'CP-004: Validación del campo contraseña debe activarse',
        );
      },
    );
  });

  // ===========================================================================
  // CP-006: Navegacion (dashboard) se monta correctamente
  // ===========================================================================
  group('CP-006: Vista principal Navegacion carga', () {
    testWidgets(
      'La Navegacion con barra lateral e IndexedStack se construye',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: Navegacion()),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(
          find.byType(Navegacion),
          findsOneWidget,
          reason: 'CP-006: La vista principal debe cargarse sin errores',
        );
        // La Navegacion usa Row con barra lateral + IndexedStack
        expect(find.byType(IndexedStack), findsOneWidget);
      },
    );
  });
}
