// La pantalla de la bitácora.
//
// Lo que fijan estos tests son las decisiones que no se ven en el código de la
// vista y se pueden romper sin que el analizador diga nada:
//
// - la pantalla es del administrador: sin `bitacoraVer` el layout pinta el
//   aviso en su lugar, y lo hace también si el permiso se quita con la
//   pantalla ya abierta —el IndexedStack la mantiene viva—;
// - los renglones dicen quién, qué hizo y sobre qué;
// - filtrar «hasta» un día incluye ese día entero, no hasta su medianoche;
// - quitar los filtros vuelve a la primera página con todo.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/bitacora/modelo/entrada_bitacora.dart';
import 'package:inventario_k1/backend/features/bitacora/repositorio/repositorio_bitacora.dart';
import 'package:inventario_k1/backend/share/dominio/permiso.dart';
import 'package:inventario_k1/frontend/features/autenticacion/provider/auth_providers.dart';
import 'package:inventario_k1/frontend/features/bitacora/provider/bitacora_providers.dart';
import 'package:inventario_k1/frontend/features/bitacora/vista/bitacora_vista.dart';
import 'package:inventario_k1/frontend/layout/layout_principal.dart';

import 'soporte/repositorio_auth_falso.dart';

EntradaBitacora _entrada({
  int id = 1,
  String nombre = 'Marta Ríos',
  String usuario = 'marta',
  EntidadAuditada entidad = EntidadAuditada.producto,
  AccionAuditada accion = AccionAuditada.elimino,
  String descripcion = 'Aceite 20W50 (ACE-1)',
  DateTime? cuando,
}) =>
    EntradaBitacora(
      id: id,
      usuarioId: 2,
      nombreUsuario: nombre,
      usuario: usuario,
      entidad: entidad,
      entidadId: 7,
      accion: accion,
      descripcion: descripcion,
      creadoEn: cuando ?? DateTime(2026, 8, 25, 9, 30),
    );

/// Un repositorio de bitácora de mentira que además **recuerda con qué filtro
/// se le preguntó**: es lo que permite comprobar que el rango de fechas llega
/// bien a SQL sin montar una base.
class _BitacoraFalsa implements RepositorioBitacora {
  _BitacoraFalsa({this.entradas = const []});

  List<EntradaBitacora> entradas;
  FiltroBitacora? ultimoFiltro;

  @override
  Future<void> anotar(Anotacion anotacion) async {}

  @override
  Stream<PaginaBitacora> observarPagina({
    required FiltroBitacora filtro,
    required int pagina,
    required int tamano,
  }) {
    ultimoFiltro = filtro;
    return Stream.value(
      PaginaBitacora(items: entradas, total: entradas.length),
    );
  }

  @override
  Future<List<EntradaBitacora>> historialDe(
    EntidadAuditada entidad,
    int entidadId, {
    int limite = 20,
  }) async =>
      entradas;
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
  tester.view.physicalSize = const Size(1400, 900);
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
      child: const MaterialApp(home: Scaffold(body: BitacoraVista())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('quién puede verla', () {
    testWidgets('con el permiso se ve el historial', (tester) async {
      await _montar(tester, bitacora: _BitacoraFalsa(entradas: [_entrada()]));

      expect(find.text('Bitácora'), findsOneWidget);
      expect(find.text('Aceite 20W50 (ACE-1)'), findsOneWidget);
    });

    testWidgets('quitarle el permiso cierra la pantalla que ya tenía abierta',
        (tester) async {
      // El caso que el sidebar solo no cubre: el ítem desaparece, pero el
      // IndexedStack conserva viva la vista construida y el usuario se queda
      // mirándola. Se monta el layout entero porque la compuerta de pantalla
      // vive ahí, en un solo sitio para las catorce.
      // Alto de sobra: el ítem de Bitácora es el último del sidebar y con
      // 900 px se queda fuera de la parte visible del ListView.
      tester.view.physicalSize = const Size(1400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final permisos = StreamController<Set<Permiso>>();
      addTearDown(permisos.close);

      final auth = RepositorioAuthFalso();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositorioBitacoraProvider
                .overrideWithValue(_BitacoraFalsa(entradas: [_entrada()])),
            repositorioAuthProvider.overrideWithValue(auth),
            repositorioAuthAnonimoProvider.overrideWithValue(auth),
            usuarioEnSesionProvider.overrideWithValue(usuarioDePrueba()),
            permisosSesionProvider.overrideWith((ref) => permisos.stream),
          ],
          child: const MaterialApp(home: LayoutPrincipal()),
        ),
      );

      permisos.add(Permiso.values.toSet());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bitácora'));
      await tester.pumpAndSettle();
      expect(find.text('Aceite 20W50 (ACE-1)'), findsOneWidget);

      // El administrador se lo quita mientras la tiene delante.
      permisos.add({Permiso.posVer});
      await tester.pumpAndSettle();

      expect(find.byType(BitacoraVista), findsNothing);
      expect(find.text('Aceite 20W50 (ACE-1)'), findsNothing);
      // El aviso sale de `PermisoDenegado`, el mismo texto que devuelve el
      // repositorio al cortar la consulta.
      expect(
        find.textContaining('no tiene permiso para ver la bitácora'),
        findsOneWidget,
      );
    });
  });

  group('el renglón cuenta el hecho completo', () {
    testWidgets('quién, qué hizo y sobre qué', (tester) async {
      await _montar(tester, bitacora: _BitacoraFalsa(entradas: [_entrada()]));

      expect(find.text('Marta Ríos'), findsOneWidget);
      expect(find.text('marta'), findsOneWidget);
      // Dos veces: el chip del filtro y la celda de la fila.
      expect(find.text('Eliminó'), findsNWidgets(2));
      expect(find.text('PRODUCTO'), findsOneWidget);
      // El nombre que tenía cuando pasó: es lo único que sobrevive al borrado.
      expect(find.text('Aceite 20W50 (ACE-1)'), findsOneWidget);
      expect(find.text('25/08/2026'), findsOneWidget);
      expect(find.text('09:30'), findsOneWidget);
    });

    testWidgets('sin nada anotado lo dice, y no ofrece quitar filtros',
        (tester) async {
      await _montar(tester, bitacora: _BitacoraFalsa());

      expect(find.textContaining('Todavía no hay nada anotado'), findsOneWidget);
      expect(find.text('Quitar los filtros'), findsNothing);
    });
  });

  group('los filtros', () {
    testWidgets('«hasta» incluye el día entero, no su medianoche',
        (tester) async {
      final bitacora = _BitacoraFalsa(entradas: [_entrada()]);
      await _montar(tester, bitacora: bitacora);

      final notifier =
          ProviderScope.containerOf(
            tester.element(find.byType(BitacoraVista)),
          ).read(bitacoraListaProvider.notifier);

      notifier.filtrarPorFechas(hasta: DateTime(2026, 8, 25));
      await tester.pumpAndSettle();

      final hasta = bitacora.ultimoFiltro!.hasta!;
      // Con la medianoche, pedir «hasta hoy» dejaría fuera todo lo de hoy.
      expect(hasta.hour, 23);
      expect(hasta.minute, 59);
      expect(hasta.day, 25);
    });

    testWidgets('la acción llega al filtro y se quita al volver a tocarla',
        (tester) async {
      final bitacora = _BitacoraFalsa(entradas: [_entrada()]);
      await _montar(tester, bitacora: bitacora);

      // `.first` es el chip: la celda de la tabla no se toca, y por eso el
      // orden importa aquí.
      await tester.tap(find.text('Eliminó').first);
      await tester.pumpAndSettle();
      expect(bitacora.ultimoFiltro!.accion, AccionAuditada.elimino);

      await tester.tap(find.text('Eliminó').first);
      await tester.pumpAndSettle();
      expect(bitacora.ultimoFiltro!.accion, isNull);
    });

    testWidgets('con filtro puesto, el vacío ofrece quitarlo', (tester) async {
      final bitacora = _BitacoraFalsa(entradas: [_entrada()]);
      await _montar(tester, bitacora: bitacora);

      bitacora.entradas = const [];
      final contenedor = ProviderScope.containerOf(
        tester.element(find.byType(BitacoraVista)),
      );
      contenedor
          .read(bitacoraListaProvider.notifier)
          .filtrarPorAccion(AccionAuditada.creo);
      await tester.pumpAndSettle();

      expect(find.textContaining('Nada con esos filtros'), findsOneWidget);
      expect(find.text('Quitar los filtros'), findsWidgets);
    });
  });
}
