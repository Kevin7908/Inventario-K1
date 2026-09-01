// El historial de **una fila**, en su ficha: «Modificó Ana, hace dos días».
//
// `historialDe` estaba escrito y probado en el repositorio desde la tanda de
// auditoría y no lo llamaba nadie: la bitácora solo se veía entera, en
// Administración, que responde otra pregunta —«¿qué pasó hoy en el taller?»—.
//
// Lo que fijan estos tests:
//
// - el panel solo aparece para quien tenga `bitacoraVer`, porque el
//   repositorio corta la consulta y un panel con un error dentro no le sirve
//   a un cajero;
// - cada renglón dice quién y hace cuánto, no la fecha completa;
// - «hace cuánto» pasa a fecha después de una semana, que es cuando el número
//   de días deja de decir nada.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/bitacora/modelo/entrada_bitacora.dart';
import 'package:inventario_k1/backend/features/bitacora/repositorio/repositorio_bitacora.dart';
import 'package:inventario_k1/backend/share/dominio/permiso.dart';
import 'package:inventario_k1/core/formato.dart';
import 'package:inventario_k1/frontend/features/autenticacion/provider/auth_providers.dart';
import 'package:inventario_k1/frontend/features/bitacora/provider/bitacora_providers.dart';
import 'package:inventario_k1/frontend/features/bitacora/widgets/panel_historial_fila.dart';

import 'soporte/repositorio_auth_falso.dart';

EntradaBitacora _entrada({
  int id = 1,
  String nombre = 'Ana Torres',
  AccionAuditada accion = AccionAuditada.modifico,
  String? detalle,
  DateTime? cuando,
}) =>
    EntradaBitacora(
      id: id,
      usuarioId: 2,
      nombreUsuario: nombre,
      usuario: 'ana',
      entidad: EntidadAuditada.producto,
      entidadId: 7,
      accion: accion,
      descripcion: 'Aceite 20W50 (ACE-1)',
      detalle: detalle,
      creadoEn: cuando ?? DateTime.now().subtract(const Duration(days: 2)),
    );

/// Una bitácora de mentira que además **recuerda qué fila le pidieron**: es lo
/// que permite comprobar que el panel pregunta por la suya y no por otra.
class _BitacoraFalsa implements RepositorioBitacora {
  _BitacoraFalsa({this.entradas = const []});

  List<EntradaBitacora> entradas;
  (EntidadAuditada, int)? ultimaConsulta;

  @override
  Future<void> anotar(Anotacion anotacion) async {}

  @override
  Stream<PaginaBitacora> observarPagina({
    required FiltroBitacora filtro,
    required int pagina,
    required int tamano,
  }) =>
      Stream.value(const PaginaBitacora(items: [], total: 0));

  @override
  Future<List<EntradaBitacora>> historialDe(
    EntidadAuditada entidad,
    int entidadId, {
    int limite = 20,
  }) async {
    ultimaConsulta = (entidad, entidadId);
    return entradas;
  }

  @override
  Future<int> cuantasPodaria({required int meses}) async => 0;

  @override
  Future<int> podar({required int meses}) async => 0;
}

Future<void> _montar(
  WidgetTester tester, {
  required _BitacoraFalsa bitacora,
  Set<Permiso> permisos = const {Permiso.bitacoraVer},
}) async {
  tester.view.physicalSize = const Size(900, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final auth = RepositorioAuthFalso(permisos: permisos);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositorioBitacoraProvider.overrideWithValue(bitacora),
        repositorioAuthProvider.overrideWithValue(auth),
        repositorioAuthAnonimoProvider.overrideWithValue(auth),
        usuarioEnSesionProvider.overrideWithValue(usuarioDePrueba()),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PanelHistorialFila(
              entidad: EntidadAuditada.producto,
              entidadId: 7,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('quién ve el panel', () {
    testWidgets('sin bitacoraVer no se pinta nada', (tester) async {
      final bitacora = _BitacoraFalsa(entradas: [_entrada()]);

      await _montar(
        tester,
        bitacora: bitacora,
        permisos: {Permiso.productosVer},
      );

      expect(find.text('Últimos cambios'), findsNothing);
      // Y no solo se esconde: ni siquiera se le pregunta al repositorio, que
      // habría cortado la consulta con un `PermisoDenegado`.
      expect(bitacora.ultimaConsulta, isNull);
    });

    testWidgets('con el permiso pregunta por su propia fila', (tester) async {
      final bitacora = _BitacoraFalsa(entradas: [_entrada()]);

      await _montar(tester, bitacora: bitacora);

      expect(find.text('Últimos cambios'), findsOneWidget);
      expect(bitacora.ultimaConsulta, (EntidadAuditada.producto, 7));
    });
  });

  group('el renglón', () {
    testWidgets('dice quién y hace cuánto, no la fecha completa',
        (tester) async {
      await _montar(
        tester,
        bitacora: _BitacoraFalsa(entradas: [_entrada()]),
      );

      expect(find.text('Modificó Ana Torres'), findsOneWidget);
      expect(find.textContaining('hace 2 días'), findsOneWidget);
    });

    testWidgets('el detalle anotado acompaña al tiempo', (tester) async {
      await _montar(
        tester,
        bitacora: _BitacoraFalsa(
          entradas: [_entrada(detalle: 'Precio: 40000 → 45000')],
        ),
      );

      expect(
        find.textContaining('Precio: 40000 → 45000'),
        findsOneWidget,
      );
    });

    testWidgets('sin nada anotado lo dice', (tester) async {
      await _montar(tester, bitacora: _BitacoraFalsa());

      expect(find.text('Nadie la ha modificado todavía'), findsOneWidget);
    });
  });

  group('formatearHaceCuanto', () {
    final ahora = DateTime(2026, 9, 1, 15, 30);

    test('lo de hace un momento no dice minutos', () {
      expect(
        formatearHaceCuanto(ahora.subtract(const Duration(minutes: 12)),
            ahora: ahora),
        'hace un rato',
      );
    });

    test('las horas se cuentan hasta el día', () {
      expect(
        formatearHaceCuanto(ahora.subtract(const Duration(hours: 1)),
            ahora: ahora),
        'hace una hora',
      );
      expect(
        formatearHaceCuanto(ahora.subtract(const Duration(hours: 5)),
            ahora: ahora),
        'hace 5 horas',
      );
    });

    test('ayer es ayer, aunque hayan pasado diez horas', () {
      // Por días de calendario y no por múltiplos de 24 horas: a las 15:30,
      // algo de anoche a las 23:00 pasó «ayer».
      expect(
        formatearHaceCuanto(DateTime(2026, 8, 31, 23), ahora: ahora),
        'ayer',
      );
    });

    test('hasta una semana cuenta días', () {
      expect(
        formatearHaceCuanto(DateTime(2026, 8, 27), ahora: ahora),
        'hace 5 días',
      );
    });

    test('pasada la semana dice la fecha, que sí significa algo', () {
      expect(
        formatearHaceCuanto(DateTime(2026, 8, 10), ahora: ahora),
        formatearFecha(DateTime(2026, 8, 10)),
      );
    });

    test('una fecha futura es un reloj mal puesto: se dice y ya', () {
      expect(
        formatearHaceCuanto(DateTime(2026, 9, 20), ahora: ahora),
        formatearFecha(DateTime(2026, 9, 20)),
      );
    });
  });
}
