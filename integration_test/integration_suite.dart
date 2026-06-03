// Suite de Pruebas Funcionales — InventarioK1
// Ejecutar desde la raíz del proyecto:
//   flutter test -d linux integration_test/integration_suite.dart

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inventario_k1/backend/share/database/locator.dart';
import 'package:inventario_k1/frontend/features/autenticacion/vista/inicio_sesion_vista.dart';
import 'package:inventario_k1/frontend/share/nav/navegacion.dart';

// ---------------------------------------------------------------------------
// Wrapper de animación lenta
// ---------------------------------------------------------------------------
// _verifyInvariants() corre DENTRO de _runTestBody(), antes de cualquier
// tearDown. La única forma de garantizar que timeDilation == 1.0 en ese
// momento es resetearlo con try/finally DENTRO del cuerpo del test.
// Este wrapper lo hace automáticamente por cada test.
// ---------------------------------------------------------------------------
typedef _Cuerpo = Future<void> Function(WidgetTester tester);

_Cuerpo lento(_Cuerpo cuerpo, {double factor = 4.0}) {
  return (WidgetTester tester) async {
    timeDilation = factor;
    try {
      await cuerpo(tester);
    } finally {
      timeDilation = 1.0; // siempre se ejecuta, incluso si el test falla
    }
  };
}

// Pausa visible entre pasos
Future<void> pausa([int ms = 800]) =>
    Future.delayed(Duration(milliseconds: ms));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await GetIt.instance.reset();
    setupLocator();
  });

  Widget appLogin() => const MaterialApp(home: InicioSesionVista());

  // ===========================================================================
  // CP-001: Pantalla de login carga con los campos esperados
  // ===========================================================================
  group('CP-001: Pantalla de login carga correctamente', () {
    testWidgets(
      'Los campos de usuario, contraseña y el botón son visibles',
      lento((tester) async {
        await tester.pumpWidget(appLogin());
        await tester.pumpAndSettle();
        await pausa(1200);

        expect(find.byType(TextFormField), findsAtLeastNWidgets(2),
            reason: 'Deben existir al menos 2 campos: usuario y contraseña');
        expect(find.text('Inicia sesión para continuar'), findsOneWidget);
        expect(find.text('Iniciar sesión'), findsOneWidget);
        await pausa(800);
      }),
    );
  });

  // ===========================================================================
  // CP-002: Credenciales inválidas — permanece en login
  // ===========================================================================
  group('CP-002: Login con contraseña incorrecta', () {
    testWidgets(
      'Credenciales inválidas no navegan al dashboard',
      lento((tester) async {
        await tester.pumpWidget(appLogin());
        await tester.pumpAndSettle();
        await pausa(1200);

        final campos = find.byType(TextFormField);
        await tester.enterText(campos.at(0), 'usuario_que_no_existe');
        await pausa(600);
        await tester.enterText(campos.at(1), 'claveIncorrecta99');
        await tester.pumpAndSettle();
        await pausa(800);

        await tester.tap(find.text('Iniciar sesión'));
        await tester.pumpAndSettle(const Duration(seconds: 4));
        await pausa(1200);

        expect(find.byType(TextFormField), findsWidgets,
            reason: 'CP-002: Con credenciales inválidas debe permanecer en login');
        await pausa(800);
      }),
    );
  });

  // ===========================================================================
  // CP-003: Campos vacíos — validación del formulario
  // ===========================================================================
  group('CP-003: Login con campos vacíos', () {
    testWidgets(
      'El formulario activa validación local sin consultar la BD',
      lento((tester) async {
        await tester.pumpWidget(appLogin());
        await tester.pumpAndSettle();
        await pausa(1200);

        await tester.tap(find.text('Iniciar sesión'));
        await tester.pumpAndSettle();
        await pausa(1200);

        expect(find.text('El usuario es requerido'), findsOneWidget,
            reason: 'CP-003: Validación del campo usuario debe activarse');
        expect(find.text('La contraseña es requerida'), findsOneWidget,
            reason: 'CP-003: Validación del campo contraseña debe activarse');
        await pausa(800);
      }),
    );
  });

  // ===========================================================================
  // CP-004: Navegacion (dashboard) se monta correctamente
  // ===========================================================================
  group('CP-004: Vista principal Navegacion carga', () {
    testWidgets(
      'La Navegacion con barra lateral e IndexedStack se construye',
      lento((tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: Navegacion())),
        );
        await tester.pumpAndSettle(const Duration(seconds: 4));
        await pausa(1500);

        expect(find.byType(Navegacion), findsOneWidget,
            reason: 'CP-004: La vista principal debe cargarse sin errores');
        expect(find.byType(IndexedStack), findsOneWidget);
        await pausa(1000);
      }),
    );
  });
}
