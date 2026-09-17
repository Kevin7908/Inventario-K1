// PaginacionWidget: qué páginas se ven y a dónde saltan los controles.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/frontend/share/share.dart';

/// Representación legible de la barra, para comparar de un vistazo.
/// Las páginas se escriben en base 1 y un `null` —el salto— como «…».
String _barra(int actual, int total, {int maximo = 7}) =>
    PaginacionWidget.paginasVisibles(
      paginaActual: actual,
      totalPaginas: total,
      maximo: maximo,
    ).map((p) => p == null ? '…' : '${p + 1}').join(' ');

Widget _envolver(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  group('páginas visibles', () {
    test('con pocas páginas se muestran todas, sin saltos', () {
      expect(_barra(0, 1), '1');
      expect(_barra(2, 5), '1 2 3 4 5');
      expect(_barra(4, 7), '1 2 3 4 5 6 7');
      expect(_barra(4, 9, maximo: 9), '1 2 3 4 5 6 7 8 9');
    });

    test('la primera y la última se ven siempre', () {
      // Es lo que la versión de la ventana contigua no daba: desde la mitad de
      // una lista larga no había forma de saber cuántas páginas hay.
      for (var actual = 0; actual < 40; actual++) {
        final barra = _barra(actual, 40);
        expect(barra, startsWith('1 '), reason: 'falta la primera en «$barra»');
        expect(barra, endsWith(' 40'), reason: 'falta la última en «$barra»');
      }
    });

    test('al principio, el salto va a la derecha', () {
      expect(_barra(0, 20), '1 2 3 4 5 … 20');
      expect(_barra(2, 20), '1 2 3 4 5 … 20');
    });

    test('en la mitad, salto a los dos lados', () {
      expect(_barra(10, 20), '1 … 10 11 12 … 20');
    });

    test('al final, el salto va a la izquierda', () {
      expect(_barra(19, 20), '1 … 16 17 18 19 20');
      expect(_barra(17, 20), '1 … 16 17 18 19 20');
    });

    test('la barra mide siempre lo mismo: el «…» gasta una casilla', () {
      // Sin esto la barra cambiaría de ancho al pasar de página, que es un
      // salto visual en una pantalla que se usa con el mouse.
      for (var actual = 0; actual < 40; actual++) {
        expect(
          PaginacionWidget.paginasVisibles(paginaActual: actual, totalPaginas: 40),
          hasLength(7),
          reason: 'la página $actual cambia el ancho de la barra',
        );
      }
    });

    test('la página actual siempre se ve, esté donde esté', () {
      for (var actual = 0; actual < 40; actual++) {
        expect(
          PaginacionWidget.paginasVisibles(
            paginaActual: actual,
            totalPaginas: 40,
          ),
          contains(actual),
          reason: 'la página actual $actual debe verse',
        );
      }
    });

    test('con menos de cinco casillas se cae a la ventana contigua', () {
      // Los dos extremos y sus dos elipsis no caben junto a la actual, así que
      // se prefiere poder navegar a poder contar. Es el panel angosto del POS.
      expect(_barra(10, 20, maximo: 1), '11');
      expect(_barra(10, 20, maximo: 3), '10 11 12');
      expect(_barra(10, 20, maximo: 4), '10 11 12 13');
    });

    test('con cinco casillas justas se aprietan los dos extremos', () {
      expect(_barra(10, 20, maximo: 5), '1 … 11 … 20');
      expect(_barra(0, 20, maximo: 5), '1 2 3 … 20');
      expect(_barra(19, 20, maximo: 5), '1 … 18 19 20');
    });

    test('sin sitio para ningún número, no devuelve ninguno', () {
      // Es lo que deja a la barra con solo las flechas y el «4/12».
      expect(
        PaginacionWidget.paginasVisibles(
            paginaActual: 3, totalPaginas: 12, maximo: 0),
        isEmpty,
      );
    });
  });

  group('controles', () {
    testWidgets('las flechas dobles van a la primera y a la última',
        (tester) async {
      final saltos = <int>[];

      await tester.pumpWidget(_envolver(
        PaginacionWidget(
          paginaActual: 10,
          totalPaginas: 20,
          alCambiarPagina: saltos.add,
        ),
      ));

      await tester.tap(find.byTooltip('Primera página'));
      await tester.tap(find.byTooltip('Última página'));
      expect(saltos, [0, 19]);
    });

    testWidgets('tocar un número salta directo a esa página', (tester) async {
      final saltos = <int>[];

      await tester.pumpWidget(_envolver(
        PaginacionWidget(
          paginaActual: 10,
          totalPaginas: 20,
          alCambiarPagina: saltos.add,
        ),
      ));

      // En la 11 de 20 la barra dice «1 … 10 11 12 … 20»: el «10» de
      // pantalla es el índice 9, una página hacia atrás.
      await tester.tap(find.text('10'));
      expect(saltos, [9]);
    });

    testWidgets('en la primera página no se puede retroceder', (tester) async {
      var saltos = 0;

      await tester.pumpWidget(_envolver(
        PaginacionWidget(
          paginaActual: 0,
          totalPaginas: 20,
          alCambiarPagina: (_) => saltos++,
        ),
      ));

      // Deshabilitados: sin tooltip y sin acción.
      expect(find.byTooltip('Primera página'), findsNothing);
      expect(find.byTooltip('Anterior'), findsNothing);
      expect(find.byTooltip('Siguiente'), findsOneWidget);

      await tester.tap(find.text('1'));
      expect(saltos, 0, reason: 'la página actual no dispara cambio');
    });

    testWidgets('muestra el rango cuando se le dan los totales',
        (tester) async {
      await tester.pumpWidget(_envolver(
        PaginacionWidget(
          paginaActual: 1,
          totalPaginas: 5,
          totalItems: 97,
          itemsPorPagina: 25,
          alCambiarPagina: (_) {},
        ),
      ));

      expect(find.text('Mostrando 26–50 de 97'), findsOneWidget);
    });
  });

  group('se adapta al ancho, que es lo que la rompía', () {
    // El panel del punto de venta se estrecha al achicar la ventana, y la
    // barra desbordaba: era un `Row` fijo con rango, cuatro flechas y cinco
    // números. Estos anchos cubren desde la pantalla completa hasta el panel
    // más angosto en que se usa.
    for (final ancho in [1200.0, 700.0, 520.0, 420.0, 340.0, 260.0, 180.0]) {
      testWidgets('no desborda con $ancho px', (tester) async {
        await tester.pumpWidget(_envolver(
          Center(
            child: SizedBox(
              width: ancho,
              child: PaginacionWidget(
                paginaActual: 5,
                totalPaginas: 20,
                totalItems: 400,
                itemsPorPagina: 20,
                alCambiarPagina: (_) {},
              ),
            ),
          ),
        ));

        expect(tester.takeException(), isNull,
            reason: 'la barra desbordó con $ancho px de ancho');
      });
    }

    testWidgets('en lo más angosto se queda con las flechas y el contador',
        (tester) async {
      await tester.pumpWidget(_envolver(
        Center(
          child: SizedBox(
            width: 160,
            child: PaginacionWidget(
              paginaActual: 3,
              totalPaginas: 12,
              alCambiarPagina: (_) {},
            ),
          ),
        ),
      ));

      expect(find.text('4/12'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('con ancho de sobra muestra el rango y los extremos',
        (tester) async {
      await tester.pumpWidget(_envolver(
        SizedBox(
          width: 1000,
          child: PaginacionWidget(
            paginaActual: 5,
            totalPaginas: 20,
            totalItems: 400,
            itemsPorPagina: 20,
            alCambiarPagina: (_) {},
          ),
        ),
      ));

      expect(find.text('Mostrando 101–120 de 400'), findsOneWidget);
      expect(find.byTooltip('Primera página'), findsOneWidget);
      expect(find.byTooltip('Última página'), findsOneWidget);
    });
  });
}
