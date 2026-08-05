// PaginacionWidget: qué páginas se ven y a dónde saltan los controles.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/frontend/share2/share2.dart';

/// Representación legible de la barra, para comparar de un vistazo.
/// `null` (elipsis) se escribe como "…" y las páginas en base 1.
String _barra(int actual, int total, {int radio = 2}) =>
    PaginacionWidget.paginasVisibles(
      paginaActual: actual,
      totalPaginas: total,
      radio: radio,
    ).map((p) => p == null ? '…' : '${p + 1}').join(' ');

Widget _envolver(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  group('páginas visibles', () {
    test('con pocas páginas se muestran todas, sin saltos', () {
      expect(_barra(0, 1), '1');
      expect(_barra(2, 5), '1 2 3 4 5');
      expect(_barra(4, 9), '1 2 3 4 5 6 7 8 9');
    });

    test('al principio la ventana se apoya en el borde', () {
      // Seis números, los mismos que al final: la ventana se desplaza en vez
      // de encogerse, así la barra no cambia de ancho al navegar.
      expect(_barra(0, 20), '1 2 3 4 5 6 … 20');
    });

    test('en la mitad hay saltos a ambos lados', () {
      expect(_barra(10, 20), '1 … 9 10 11 12 13 … 20');
    });

    test('al final la ventana se desplaza en vez de encogerse', () {
      expect(_barra(19, 20), '1 … 15 16 17 18 19 20');
    });

    test('la primera y la última nunca desaparecen', () {
      for (var actual = 0; actual < 40; actual++) {
        final paginas = PaginacionWidget.paginasVisibles(
          paginaActual: actual,
          totalPaginas: 40,
        );
        expect(paginas.first, 0, reason: 'falta la primera en $actual');
        expect(paginas.last, 39, reason: 'falta la última en $actual');
        expect(paginas.contains(actual), isTrue,
            reason: 'la página actual $actual debe verse');
      }
    });

    test('el radio controla el ancho de la ventana', () {
      expect(_barra(10, 20, radio: 1), '1 … 10 11 12 … 20');
      expect(_barra(10, 20, radio: 3), '1 … 8 9 10 11 12 13 14 … 20');
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
}
