// TarjetaMetrica: el contador grande que encabeza el listado de órdenes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/frontend/share/share.dart';

Widget _envolver(Widget hijo) => MaterialApp(
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: hijo),
      ),
    );

void main() {
  testWidgets('pinta el valor y su etiqueta', (tester) async {
    await tester.pumpWidget(_envolver(
      const TarjetaMetrica(valor: '12', etiqueta: 'Órdenes totales'),
    ));

    expect(find.text('12'), findsOneWidget);
    expect(find.text('Órdenes totales'), findsOneWidget);
  });

  testWidgets('sin alPresionar no responde al toque', (tester) async {
    await tester.pumpWidget(_envolver(
      const TarjetaMetrica(valor: '3', etiqueta: 'En proceso'),
    ));

    // Informativa: no hay InkWell que capture el gesto.
    expect(find.byType(InkWell), findsNothing);
    await tester.tap(find.text('3'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('con alPresionar avisa al tocarla', (tester) async {
    var toques = 0;

    await tester.pumpWidget(_envolver(
      TarjetaMetrica(
        valor: '3',
        etiqueta: 'En proceso',
        alPresionar: () => toques++,
      ),
    ));

    await tester.tap(find.text('En proceso'));
    await tester.pump();
    expect(toques, 1);
  });

  testWidgets('activa no cambia el grosor del borde', (tester) async {
    // Un borde que engorda al activarse mueve el contenido y desalinea la fila
    // entera de tarjetas.
    Future<double> anchoDelBorde({required bool activa}) async {
      await tester.pumpWidget(_envolver(
        TarjetaMetrica(
          valor: '7',
          etiqueta: 'Pendientes',
          activa: activa,
          alPresionar: () {},
        ),
      ));
      final caja = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(TarjetaMetrica),
          matching: find.byType(DecoratedBox),
        ).last,
      );
      final decoracion = caja.decoration as BoxDecoration;
      return decoracion.border!.top.width;
    }

    expect(await anchoDelBorde(activa: false),
        await anchoDelBorde(activa: true));
  });

  testWidgets('el color del valor se puede teñir', (tester) async {
    await tester.pumpWidget(_envolver(
      const TarjetaMetrica(
        valor: '5',
        etiqueta: 'Completadas',
        colorValor: ColoresApp.statusSuccess,
      ),
    ));

    final texto = tester.widget<Text>(find.text('5'));
    expect(texto.style?.color, ColoresApp.statusSuccess);
  });
}
