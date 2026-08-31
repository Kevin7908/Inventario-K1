// PaginacionWidget: qué páginas se ven y a dónde saltan los controles.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/frontend/share/share.dart';

/// Representación legible de la barra, para comparar de un vistazo.
/// Las páginas se escriben en base 1.
String _barra(int actual, int total, {int maximo = 5}) =>
    PaginacionWidget.paginasVisibles(
      paginaActual: actual,
      totalPaginas: total,
      maximo: maximo,
    ).map((p) => '${p + 1}').join(' ');

Widget _envolver(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  group('páginas visibles', () {
    test('con pocas páginas se muestran todas', () {
      expect(_barra(0, 1), '1');
      expect(_barra(2, 5), '1 2 3 4 5');
      expect(_barra(4, 9, maximo: 9), '1 2 3 4 5 6 7 8 9');
    });

    test('la ventana es contigua: ni elipsis ni huecos', () {
      final paginas = PaginacionWidget.paginasVisibles(
        paginaActual: 10,
        totalPaginas: 20,
      );
      for (var i = 1; i < paginas.length; i++) {
        expect(paginas[i], paginas[i - 1] + 1,
            reason: 'la ventana no puede saltarse números');
      }
    });

    test('al principio se apoya en el borde izquierdo', () {
      expect(_barra(0, 20), '1 2 3 4 5');
    });

    test('en la mitad se centra en la actual', () {
      expect(_barra(10, 20), '9 10 11 12 13');
    });

    test('al final se desplaza en vez de encogerse', () {
      expect(_barra(19, 20), '16 17 18 19 20');
    });

    test('la página actual siempre se ve, esté donde esté', () {
      for (var actual = 0; actual < 40; actual++) {
        final paginas = PaginacionWidget.paginasVisibles(
          paginaActual: actual,
          totalPaginas: 40,
        );
        expect(paginas.contains(actual), isTrue,
            reason: 'la página actual $actual debe verse');
        expect(paginas, hasLength(5));
      }
    });

    test('el máximo controla el ancho de la ventana', () {
      expect(_barra(10, 20, maximo: 1), '11');
      expect(_barra(10, 20, maximo: 3), '10 11 12');
      expect(_barra(10, 20, maximo: 7), '8 9 10 11 12 13 14');
    });

    test('sin sitio para ningún número, no devuelve ninguno', () {
      // Es lo que deja a la barra con solo las flechas y el «4 / 12».
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

      // "9" en pantalla es el índice 8: tres páginas hacia atrás.
      await tester.tap(find.text('9'));
      expect(saltos, [8]);
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
