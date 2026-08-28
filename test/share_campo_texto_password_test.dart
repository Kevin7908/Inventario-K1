// El ojo de `CampoTexto`.
//
// Lo que fija este test es el contrato de share: el campo **no guarda** si la
// contraseña se ve o no. Recibe `oculto` y avisa por `alAlternarOculto`; el
// estado vive en la vista. Si algún día el widget se vuelve `StatefulWidget`
// para llevarlo por dentro, esto falla.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/frontend/share/share.dart';

void main() {
  testWidgets('sin alAlternarOculto no hay ojo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampoTexto(
            etiqueta: 'Contraseña',
            controlador: TextEditingController(),
            oculto: true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
  });

  testWidgets('el ojo avisa hacia afuera y no cambia nada por su cuenta',
      (tester) async {
    var alternado = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampoTexto(
            etiqueta: 'Contraseña',
            controlador: TextEditingController(),
            oculto: true,
            alAlternarOculto: () => alternado++,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();

    expect(alternado, 1);
    // Sigue oculto: `oculto` no cambió porque quien lo lleva es la vista.
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, true);
  });

  testWidgets('con oculto en false el texto se ve', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampoTexto(
            etiqueta: 'Contraseña',
            controlador: TextEditingController(),
            alAlternarOculto: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, false);
  });
}
