// El chip de estado, cuando no cabe.
//
// Un chip que exige su ancho natural revienta la celda que lo contiene: la
// tabla de cuentas pintaba la franja de overflow con «Administrador» en
// cualquier ventana por debajo de ~1350 px.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/frontend/share2/feedback/feedback.dart';
import 'package:inventario_k1/frontend/share2/temas/colores_app.dart';

Widget _enAnchoDe(double ancho) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: ancho,
            child: const Row(
              children: [
                Flexible(
                  child: IndicadorEstado(
                    etiqueta: 'Administrador',
                    color: ColoresApp.statusInfo,
                    colorFondo: ColoresApp.statusInfoBg,
                  ),
                ),
                Icon(Icons.expand_more_rounded, size: 16),
              ],
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('con sitio de sobra se ve entero', (tester) async {
    await tester.pumpWidget(_enAnchoDe(300));
    expect(tester.takeException(), isNull);
    expect(find.text('Administrador'), findsOneWidget);
  });

  testWidgets('sin sitio recorta en vez de desbordar', (tester) async {
    await tester.pumpWidget(_enAnchoDe(90));

    // Un overflow se reporta como excepción de layout: si la hubiera, este
    // `takeException` la devolvería.
    expect(tester.takeException(), isNull);

    final texto = tester.widget<Text>(find.text('Administrador'));
    expect(texto.overflow, TextOverflow.ellipsis);
    expect(texto.maxLines, 1);
  });
}
