// «¿Quién movió esto?», en el kardex.
//
// `FiltroMovimientos.usuarioId` estaba resuelto en SQL y con su índice desde
// la tanda de auditoría, y no lo pedía nadie: faltaba el desplegable de
// cuentas. Ahora es el mismo que el de la bitácora —`SelectorCuenta`, en el
// módulo dueño del dato—, porque es la misma pregunta sobre dos tablas.
//
// Lo que fijan estos tests:
//
// - el estado del kardex lleva el usuario **hasta el filtro**, que es lo que
//   viaja a SQL: sin eso el desplegable se movería y la tabla no;
// - elegir una cuenta vuelve a la primera página, porque el conjunto que se
//   está paginando pasó a ser otro;
// - el selector pinta «Cualquiera» y las cuentas, y una cuenta dada de baja
//   que ya no está en la lista no rompe la pantalla.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/frontend/features/autenticacion/provider/usuarios_provider.dart';
import 'package:inventario_k1/frontend/features/autenticacion/widgets/selector_cuenta.dart';
import 'package:inventario_k1/frontend/features/inventario/provider/inventario_providers.dart';

import 'soporte/repositorio_auth_falso.dart';

Future<void> _montar(
  WidgetTester tester, {
  int? usuarioId,
  required void Function(int?) alCambiar,
  List<int> cuentas = const [1, 2],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        usuariosProvider.overrideWith(
          (ref) => Stream.value([
            for (final id in cuentas)
              usuarioDePrueba(
                id: id,
                nombre: id == 1 ? 'Juan García' : 'Marta Ríos',
                usuario: id == 1 ? 'juan' : 'marta',
              ),
          ]),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SelectorCuenta(usuarioId: usuarioId, alCambiar: alCambiar),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('el estado del kardex lleva el usuario hasta SQL', () {
    test('sin elegir nadie, el filtro no lo menciona', () {
      const estado = MovimientosState();

      expect(estado.filtro.usuarioId, isNull);
      expect(estado.hayFiltro, isFalse);
    });

    test('elegir una cuenta viaja al filtro y cuenta como filtro puesto', () {
      const estado = MovimientosState(usuarioId: 4);

      expect(estado.filtro.usuarioId, 4);
      expect(estado.hayFiltro, isTrue);
    });

    test('quitarlo lo borra de verdad, no lo deja como estaba', () {
      // El `bool` aparte es lo que distingue «no lo cambies» de «bórralo»:
      // sin él, volver a «Cualquiera» dejaría el filtro anterior puesto.
      const estado = MovimientosState(usuarioId: 4, pagina: 3);

      final limpio = estado.copyWith(limpiarUsuario: true);

      expect(limpio.filtro.usuarioId, isNull);
      expect(limpio.hayFiltro, isFalse);
    });
  });

  group('el selector de cuentas', () {
    testWidgets('ofrece «Cualquiera» y las cuentas del taller',
        (tester) async {
      await _montar(tester, alCambiar: (_) {});

      expect(find.text('Cualquiera'), findsOneWidget);

      await tester.tap(find.byType(SelectorCuenta));
      await tester.pumpAndSettle();

      expect(find.text('Juan García'), findsWidgets);
      expect(find.text('Marta Ríos'), findsWidgets);
    });

    testWidgets('devuelve el id elegido', (tester) async {
      int? elegido;
      await _montar(tester, alCambiar: (id) => elegido = id);

      await tester.tap(find.byType(SelectorCuenta));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marta Ríos').last);
      await tester.pumpAndSettle();

      expect(elegido, 2);
    });

    testWidgets('una cuenta dada de baja no rompe la pantalla',
        (tester) async {
      // Sus renglones viejos siguen ahí y siguen siendo suyos, así que el id
      // puede no estar en la lista. Antes que un desplegable vacío, el número.
      await _montar(tester, usuarioId: 99, alCambiar: (_) {}, cuentas: [1]);

      expect(find.text('Cuenta #99'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
