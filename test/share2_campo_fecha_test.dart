// CampoFecha: qué pinta y qué devuelve el calendario.
//
// Lo que importa comprobar es que **el widget no formatea por su cuenta**:
// share2 no puede depender de `intl`, así que el texto sale del [formatear]
// que le pasa quien lo usa. Si algún día alguien mete un `DateFormat` dentro
// del widget, el primer test lo delata.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/core/formato.dart';
import 'package:inventario_k1/frontend/share2/share2.dart';

Future<void> _pump(WidgetTester tester, Widget campo) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: campo)),
    );

void main() {
  testWidgets('el texto sale del formateador que se le pasa', (tester) async {
    await _pump(
      tester,
      CampoFecha(
        etiqueta: 'Vigente hasta',
        valor: DateTime(2026, 9, 12),
        formatear: formatearFecha,
        alCambiar: (_) {},
      ),
    );

    expect(find.text('Vigente hasta'), findsOneWidget);
    expect(find.text('12/09/2026'), findsOneWidget);
  });

  testWidgets('sin fecha muestra el placeholder', (tester) async {
    await _pump(
      tester,
      CampoFecha(
        etiqueta: 'Fecha límite',
        valor: null,
        formatear: formatearFecha,
        placeholder: 'Sin definir',
        alCambiar: (_) {},
      ),
    );

    expect(find.text('Sin definir'), findsOneWidget);
  });

  testWidgets('elegir una fecha en el calendario la devuelve por alCambiar',
      (tester) async {
    DateTime? elegida;
    final hoy = DateTime.now();

    await _pump(
      tester,
      CampoFecha(
        etiqueta: 'Vigente hasta',
        valor: hoy,
        formatear: formatearFecha,
        alCambiar: (fecha) => elegida = fecha,
      ),
    );

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(elegida, isNotNull);
    expect(formatearFecha(elegida!), formatearFecha(hoy));
  });

  testWidgets('con alCambiar en null el calendario no se abre', (tester) async {
    await _pump(
      tester,
      CampoFecha(
        etiqueta: 'Vigente hasta',
        valor: DateTime(2026, 9, 12),
        formatear: formatearFecha,
        alCambiar: null,
      ),
    );

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(find.text('OK'), findsNothing);
  });

  testWidgets('una fecha fuera del rango no revienta el calendario',
      (tester) async {
    // `initialDate` fuera de [firstDate, lastDate] lanza una aserción: pasa
    // con una cotización vencida, cuya vigencia quedó en el pasado.
    final hoy = DateTime.now();
    await _pump(
      tester,
      CampoFecha(
        etiqueta: 'Vigente hasta',
        valor: hoy.subtract(const Duration(days: 30)),
        formatear: formatearFecha,
        primeraFecha: hoy,
        alCambiar: (_) {},
      ),
    );

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(find.text('OK'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
