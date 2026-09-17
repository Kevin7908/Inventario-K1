// El cajón que rellena un panel de ficha mientras no hay nada que pintar.
//
// Existe porque la ficha del producto y la del cliente tenían cada una su
// copia del mismo `Container` con el mismo borde: dos sitios donde decidir por
// separado qué alto tiene un panel vacío.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/frontend/share/feedback/panel_sin_datos.dart';

Future<void> _montar(WidgetTester tester, Widget hijo) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: hijo))),
    );

void main() {
  testWidgets('dice qué falta, con su ícono', (tester) async {
    await _montar(
      tester,
      const PanelSinDatos(
        icono: Icons.history_rounded,
        texto: 'Nadie la ha modificado todavía',
      ),
    );

    expect(find.text('Nadie la ha modificado todavía'), findsOneWidget);
    expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('cargando pinta el indicador y ningún texto', (tester) async {
    await _montar(tester, const PanelSinDatos.cargando());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('ocupa todo el ancho que le den', (tester) async {
    // Es lo que hace que la ficha no cambie de forma al llegar los datos: el
    // hueco mide lo mismo que medirá la lista.
    await _montar(
      tester,
      const SizedBox(
        width: 400,
        child: PanelSinDatos(icono: Icons.inbox_outlined, texto: 'Nada'),
      ),
    );

    expect(tester.getSize(find.byType(PanelSinDatos)).width, 400);
  });
}
