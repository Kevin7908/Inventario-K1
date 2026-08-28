// `AvisoEnLinea`, el aviso que se queda en pantalla.
//
// Es la contraparte de `MensajeApp`: aquel se va solo a los tres segundos y
// sirve para confirmar; este se queda mientras el usuario decide qué hacer.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/frontend/share2/share2.dart';

Future<void> _pump(WidgetTester tester, Widget hijo) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SizedBox(width: 380, child: hijo))),
    );

void main() {
  testWidgets('sin título muestra solo el mensaje', (tester) async {
    await _pump(
      tester,
      const AvisoEnLinea(mensaje: 'Usuario o contraseña incorrectos.'),
    );

    expect(find.text('Usuario o contraseña incorrectos.'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });

  testWidgets('con título pinta las dos líneas', (tester) async {
    await _pump(
      tester,
      const AvisoEnLinea(
        tono: TonoAviso.alerta,
        titulo: 'El correo no está configurado',
        mensaje: 'Pídele al administrador que llene el archivo .env.',
      ),
    );

    expect(find.text('El correo no está configurado'), findsOneWidget);
    expect(
      find.text('Pídele al administrador que llene el archivo .env.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('cada tono trae su ícono', (tester) async {
    await _pump(
      tester,
      const Column(
        children: [
          AvisoEnLinea(tono: TonoAviso.exito, mensaje: 'Listo'),
          AvisoEnLinea(tono: TonoAviso.informacion, mensaje: 'Ojo'),
        ],
      ),
    );

    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
  });
}
