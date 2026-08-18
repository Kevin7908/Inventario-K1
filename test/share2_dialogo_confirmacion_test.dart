import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/frontend/share2/botones/boton_destructivo.dart';
import 'package:inventario_k1/frontend/share2/botones/boton_primario.dart';
import 'package:inventario_k1/frontend/share2/feedback/dialogo_confirmacion.dart';

Future<bool?> _mostrar(WidgetTester tester, {required bool destructivo}) async {
  bool? devuelto;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            devuelto = await DialogoConfirmacion.mostrar(
              context,
              titulo: '¿Seguir?',
              textoConfirmar: 'Sí',
              destructivo: destructivo,
            );
          },
          child: const Text('abrir'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return devuelto;
}

void main() {
  testWidgets('por defecto el botón de confirmar es destructivo',
      (tester) async {
    await _mostrar(tester, destructivo: true);

    expect(find.byType(BotonDestructivo), findsOneWidget);
    expect(find.byType(BotonPrimario), findsNothing);
  });

  testWidgets('con destructivo: false confirma con el botón primario',
      (tester) async {
    await _mostrar(tester, destructivo: false);

    expect(find.byType(BotonPrimario), findsOneWidget);
    expect(find.byType(BotonDestructivo), findsNothing);
  });

  testWidgets('confirmar devuelve true y cancelar false', (tester) async {
    await _mostrar(tester, destructivo: false);
    await tester.tap(find.text('Sí'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);

    await _mostrar(tester, destructivo: false);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });
}
