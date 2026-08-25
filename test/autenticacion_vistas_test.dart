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
//   existe: avanza al paso del código igual que si existiera.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/autenticacion/modelo/usuario.dart';
import 'package:inventario_k1/backend/features/autenticacion/repositorio/repositorio_auth.dart';
import 'package:inventario_k1/backend/features/autenticacion/resultado/resultados_auth.dart';
import 'package:inventario_k1/backend/share/dominio/permiso.dart';
import 'package:inventario_k1/backend/share/dominio/rol_usuario.dart';
import 'package:inventario_k1/backend/share/servicios/servicio_correo.dart';
import 'package:inventario_k1/core/resultado.dart';
import 'package:inventario_k1/frontend/features/autenticacion/provider/auth_providers.dart';
import 'package:inventario_k1/frontend/features/autenticacion/vista/login_vista.dart';
import 'package:inventario_k1/frontend/features/autenticacion/vista/portal_sesion.dart';
import 'package:inventario_k1/frontend/features/autenticacion/vista/primer_admin_vista.dart';
import 'package:inventario_k1/frontend/features/autenticacion/vista/recuperar_vista.dart';
import 'package:inventario_k1/frontend/features/autenticacion/widgets/campo_codigo.dart';

Usuario _usuario({
  int id = 1,
  String usuario = 'juan',
  String email = 'juan@taller.com',
  RolUsuario rol = RolUsuario.admin,
}) =>
    Usuario(
      id: id,
      personaId: id,
      nombre: 'Juan García',
      usuario: usuario,
      email: email,
      rol: rol,
      estaActivo: true,
      creadoEn: DateTime(2026, 8, 1),
    );

/// Un repositorio de mentira: responde lo que le digan sin tocar SQLite.
///
/// Hace falta porque estos tests miran la vista, no la base. Lo del backend ya
/// está cubierto en `repositorio_auth_test.dart` contra Drift en memoria.
class _AuthFalso implements RepositorioAuth {
  _AuthFalso({
    this.hay = true,
    this.acceso = const CredencialesIncorrectas(),
    this.porIdentificador,
  });

  bool hay;
  ResultadoAcceso acceso;
  Usuario? porIdentificador;

  String? identificadorPedido;

  @override
  Future<bool> hayUsuarios() async => hay;

  @override
  Future<ResultadoAcceso> autenticar({
    required String identificador,
    required String password,
  }) async {
    identificadorPedido = identificador;
    return acceso;
  }

  @override
  Future<Usuario?> obtenerPorIdentificador(String identificador) async {
    identificadorPedido = identificador;
    return porIdentificador;
  }

  @override
  Future<ResultadoCuenta> crearCuenta({
    required String nombre,
    required String usuario,
    required String email,
    required String password,
    required RolUsuario rol,
    String? documento,
  }) async =>
      CuentaCreada(_usuario(usuario: usuario, email: email, rol: rol));

  @override
  Future<Resultado> cambiarPassword({
    required int usuarioId,
    required String passwordNueva,
  }) async =>
      const Exito();

  @override
  Future<Resultado> cambiarEstado({
    required int adminId,
    required int usuarioId,
    required bool activo,
  }) async =>
      const Exito();

  @override
  Future<Resultado> cambiarRol({
    required int adminId,
    required int usuarioId,
    required RolUsuario rol,
  }) async =>
      const Exito();

  @override
  Future<Usuario?> obtenerPorId(int id) async => porIdentificador;

  @override
  Stream<List<Usuario>> observarUsuarios() => Stream.value(const []);

  @override
  Future<Set<Permiso>> permisosDe(int usuarioId) async =>
      Permiso.values.toSet();

  @override
  Stream<Set<Permiso>> observarPermisos(int usuarioId) =>
      Stream.value(Permiso.values.toSet());

  @override
  Future<Resultado> fijarPermisos({
    required int adminId,
    required int usuarioId,
    required Set<Permiso> permisos,
  }) async =>
      const Exito();
}

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

Future<void> _montar(
  WidgetTester tester,
  Widget vista, {
  required _AuthFalso auth,
  ServicioCorreo? correo,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositorioAuthProvider.overrideWithValue(auth),
        repositorioAuthAnonimoProvider.overrideWithValue(auth),
        if (correo != null) servicioCorreoProvider.overrideWithValue(correo),
      ],
      child: MaterialApp(home: vista),
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
        auth: _AuthFalso(hay: false),
      );

      expect(find.byType(PrimerAdminVista), findsOneWidget);
      expect(find.text('Crea la cuenta del administrador'), findsOneWidget);
    });

    testWidgets('con cuentas creadas abre el login', (tester) async {
      await _montar(tester, const PortalSesion(), auth: _AuthFalso());

      expect(find.byType(LoginVista), findsOneWidget);
      // El login no ofrece registrarse: las cuentas las crea el admin.
      expect(find.textContaining('Regístrate'), findsNothing);
    });
  });

  group('login', () {
    testWidgets('no llama al repositorio con los campos vacíos',
        (tester) async {
      final auth = _AuthFalso();
      await _montar(tester, const LoginVista(), auth: auth);

      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(auth.identificadorPedido, isNull);
      expect(find.text('Escribe tu usuario o tu correo.'), findsOneWidget);
    });

    testWidgets('manda el correo tal cual se escribió', (tester) async {
      final auth = _AuthFalso();
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
      final auth = _AuthFalso(acceso: const CuentaDesactivada());
      await _montar(tester, const LoginVista(), auth: auth);

      await tester.enterText(find.byType(TextFormField).first, 'juan');
      await tester.enterText(find.byType(TextFormField).last, 'clave-larga-1');
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(find.textContaining('desactivada'), findsOneWidget);
      expect(find.textContaining('incorrectos'), findsNothing);
    });

    testWidgets('el acceso concedido abre la sesión', (tester) async {
      final auth = _AuthFalso(acceso: AccesoConcedido(_usuario()));
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
        auth: _AuthFalso(porIdentificador: null),
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
        auth: _AuthFalso(porIdentificador: _usuario(email: '')),
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
        auth: _AuthFalso(porIdentificador: _usuario()),
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
        auth: _AuthFalso(porIdentificador: _usuario()),
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
