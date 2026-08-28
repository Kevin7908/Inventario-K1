// Las pantallas de entrar a la app.
//
// Lo que fijan estos tests son las decisiones que no se ven en el código de la
// vista y se pueden romper sin que el analizador diga nada:
//
// - el portal manda a crear la cuenta del administrador **solo** cuando la
//   base está vacía;
// - se entra con usuario **o** con correo;
// - una cuenta desactivada no dice lo mismo que una contraseña mala;
// - recuperar la contraseña de un usuario que no existe **no** delata que no
//   existe: avanza al paso del código igual que si existiera;
// - la tarjeta de entrada muestra la ilustración solo si la ventana da para
//   las dos mitades, y el formulario nunca se aprieta para dejarla entrar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/autenticacion/resultado/resultados_auth.dart';
import 'package:inventario_k1/backend/share/servicios/servicio_correo.dart';
import 'package:inventario_k1/frontend/features/autenticacion/provider/auth_providers.dart';
import 'package:inventario_k1/frontend/features/autenticacion/vista/login_vista.dart';
import 'package:inventario_k1/frontend/features/autenticacion/vista/portal_sesion.dart';
import 'package:inventario_k1/frontend/features/autenticacion/vista/primer_admin_vista.dart';
import 'package:inventario_k1/frontend/features/autenticacion/vista/recuperar_vista.dart';
import 'package:inventario_k1/frontend/features/autenticacion/widgets/campo_codigo.dart';
import 'package:inventario_k1/frontend/features/autenticacion/widgets/ilustracion/ilustracion_gatos.dart';

import 'soporte/repositorio_auth_falso.dart';

/// Un servicio de correo que no manda nada pero deja ver qué se le pidió.
class _CorreoFalso extends ServicioCorreo {
  _CorreoFalso({this.respuesta = const CorreoEnviado()}) : super(null);

  final ResultadoCorreo respuesta;
  int enviados = 0;

  @override
  Future<ResultadoCorreo> enviarCodigoRecuperacion({
    required String email,
    required String codigo,
    required String nombre,
    required int minutosVigencia,
  }) async {
    enviados++;
    return respuesta;
  }
}

/// [sinMovimiento] apaga la ilustración animada de la pantalla de entrada.
/// Hace falta en cuanto la ventana es lo bastante ancha para que aparezca: con
/// una animación en bucle, `pumpAndSettle` no converge nunca.
Future<void> _montar(
  WidgetTester tester,
  Widget vista, {
  required RepositorioAuthFalso auth,
  ServicioCorreo? correo,
  bool sinMovimiento = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositorioAuthProvider.overrideWithValue(auth),
        repositorioAuthAnonimoProvider.overrideWithValue(auth),
        if (correo != null) servicioCorreoProvider.overrideWithValue(correo),
      ],
      child: MaterialApp(
        home: sinMovimiento
            ? MediaQuery(
                data: const MediaQueryData(disableAnimations: true),
                child: vista,
              )
            : vista,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('el portal decide qué se ve antes de la sesión', () {
    testWidgets('sin ninguna cuenta manda a crear la del administrador',
        (tester) async {
      await _montar(
        tester,
        const PortalSesion(),
        auth: RepositorioAuthFalso(hay: false),
      );

      expect(find.byType(PrimerAdminVista), findsOneWidget);
      expect(find.text('Crea la cuenta del administrador'), findsOneWidget);
    });

    testWidgets('con cuentas creadas abre el login', (tester) async {
      await _montar(tester, const PortalSesion(), auth: RepositorioAuthFalso());

      expect(find.byType(LoginVista), findsOneWidget);
      // El login no ofrece registrarse: las cuentas las crea el admin.
      expect(find.textContaining('Regístrate'), findsNothing);
    });
  });

  group('login', () {
    testWidgets('no llama al repositorio con los campos vacíos',
        (tester) async {
      final auth = RepositorioAuthFalso();
      await _montar(tester, const LoginVista(), auth: auth);

      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(auth.identificadorPedido, isNull);
      expect(find.text('Escribe tu usuario o tu correo.'), findsOneWidget);
    });

    testWidgets('manda el correo tal cual se escribió', (tester) async {
      final auth = RepositorioAuthFalso();
      await _montar(tester, const LoginVista(), auth: auth);

      await tester.enterText(
        find.byType(TextFormField).first,
        'juan@taller.com',
      );
      await tester.enterText(find.byType(TextFormField).last, 'clave-larga-1');
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(auth.identificadorPedido, 'juan@taller.com');
    });

    testWidgets('una cuenta desactivada no se confunde con una clave mala',
        (tester) async {
      final auth = RepositorioAuthFalso(acceso: const CuentaDesactivada());
      await _montar(tester, const LoginVista(), auth: auth);

      await tester.enterText(find.byType(TextFormField).first, 'juan');
      await tester.enterText(find.byType(TextFormField).last, 'clave-larga-1');
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(find.textContaining('desactivada'), findsOneWidget);
      expect(find.textContaining('incorrectos'), findsNothing);
    });

    testWidgets('el acceso concedido abre la sesión', (tester) async {
      final auth = RepositorioAuthFalso(acceso: AccesoConcedido(usuarioDePrueba()));
      late WidgetRef refDeLaVista;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositorioAuthProvider.overrideWithValue(auth),
            repositorioAuthAnonimoProvider.overrideWithValue(auth),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                refDeLaVista = ref;
                return const LoginVista();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'juan');
      await tester.enterText(find.byType(TextFormField).last, 'clave-larga-1');
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(refDeLaVista.read(usuarioEnSesionProvider)?.usuario, 'juan');
    });
  });

  group('recuperar la contraseña', () {
    testWidgets('un usuario que no existe avanza igual al paso del código',
        (tester) async {
      // Decir «esa cuenta no existe» le confirma a cualquiera qué usuarios
      // hay. La pantalla no lo dice, y no se manda ningún correo.
      final correo = _CorreoFalso();
      await _montar(
        tester,
        const RecuperarVista(),
        auth: RepositorioAuthFalso(porIdentificador: null),
        correo: correo,
      );

      await tester.enterText(find.byType(TextFormField).first, 'fantasma');
      await tester.tap(find.text('Enviar código'));
      await tester.pumpAndSettle();

      expect(find.text('Escribe el código'), findsOneWidget);
      expect(correo.enviados, 0);
    });

    testWidgets('una cuenta sin correo lo dice en vez de callar',
        (tester) async {
      await _montar(
        tester,
        const RecuperarVista(),
        auth: RepositorioAuthFalso(porIdentificador: usuarioDePrueba(email: '')),
        correo: _CorreoFalso(),
      );

      await tester.enterText(find.byType(TextFormField).first, 'juan');
      await tester.tap(find.text('Enviar código'));
      await tester.pumpAndSettle();

      expect(find.textContaining('no tiene un correo registrado'),
          findsOneWidget);
      expect(find.text('Escribe el código'), findsNothing);
    });

    testWidgets('sin correo configurado avisa y no avanza', (tester) async {
      await _montar(
        tester,
        const RecuperarVista(),
        auth: RepositorioAuthFalso(porIdentificador: usuarioDePrueba()),
        correo: _CorreoFalso(respuesta: const CorreoNoConfigurado()),
      );

      await tester.enterText(find.byType(TextFormField).first, 'juan');
      await tester.tap(find.text('Enviar código'));
      await tester.pumpAndSettle();

      expect(find.textContaining('.env'), findsOneWidget);
      expect(find.text('Escribe el código'), findsNothing);
    });

    testWidgets('con correo, avanza y enmascara la dirección', (tester) async {
      final correo = _CorreoFalso();
      await _montar(
        tester,
        const RecuperarVista(),
        auth: RepositorioAuthFalso(porIdentificador: usuarioDePrueba()),
        correo: correo,
      );

      await tester.enterText(find.byType(TextFormField).first, 'juan');
      await tester.tap(find.text('Enviar código'));
      await tester.pumpAndSettle();

      expect(correo.enviados, 1);
      expect(find.textContaining('ju***n@taller.com'), findsOneWidget);
      expect(find.textContaining('juan@taller.com'), findsNothing);
    });
  });

  group('el marco de las pantallas de entrada', () {
    // El tamaño de ventana de un test es 800x600: la ilustración no cabe y la
    // tarjeta se queda con el formulario solo. Estos dos tests fijan las dos
    // caras de esa decisión, que es puro layout y no la ve el analizador.
    Future<void> conVentana(
      WidgetTester tester,
      Size tamano,
      Future<void> Function() cuerpo,
    ) async {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await cuerpo();
    }

    testWidgets('en una ventana ancha la tarjeta trae la ilustración',
        (tester) async {
      await conVentana(tester, const Size(1280, 800), () async {
        await _montar(
          tester,
          const LoginVista(),
          auth: RepositorioAuthFalso(),
          sinMovimiento: true,
        );

        expect(find.text('Todo el taller en un solo sitio.'), findsOneWidget);
        expect(find.text('Bienvenido de nuevo'), findsOneWidget);
      });
    });

    testWidgets('en una ventana angosta se va la ilustración, no el formulario',
        (tester) async {
      await conVentana(tester, const Size(700, 800), () async {
        await _montar(tester, const LoginVista(), auth: RepositorioAuthFalso());

        expect(find.text('Todo el taller en un solo sitio.'), findsNothing);
        expect(find.text('Iniciar sesión'), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(2));
      });
    });
  });

  group('la ilustración de la entrada', () {
    // El SVG traía su animación en SMIL y `flutter_svg` la ignora. Ahora son
    // capas quietas que mueve Flutter, y lo que hay que fijar es que el reloj
    // arranque… y que se detenga cuando el sistema pide no mover nada.
    testWidgets('se mueve sola', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: IlustracionGatos())),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('con «reducir movimiento» se queda quieta', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(body: IlustracionGatos()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('el campo del código', () {
    testWidgets('pegar seis dígitos los reparte y avisa que está completo',
        (tester) async {
      String? completo;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CampoCodigo(
              alCambiar: (_) {},
              alCompletar: (v) => completo = v,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).first, '481902');
      await tester.pumpAndSettle();

      expect(completo, '481902');
      expect(find.text('9'), findsOneWidget);
    });

    testWidgets('teclear un segundo dígito lo pasa a la casilla siguiente',
        (tester) async {
      String ultimo = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CampoCodigo(alCambiar: (v) => ultimo = v),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).first, '4');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '48');
      await tester.pumpAndSettle();

      expect(ultimo, '48');
    });
  });
}
