// GrupoRadio: el selector de opciones a la vista que reemplazó al dropdown
// de "Qué agregar" en el editor de cotizaciones.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/frontend/share2/share2.dart';

enum _Tipo {
  producto('Producto'),
  servicio('Servicio'),
  libre('Línea libre');

  const _Tipo(this.etiqueta);
  final String etiqueta;
}

Widget _envolver(Widget hijo) => MaterialApp(
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: hijo)),
    );

void main() {
  testWidgets('pinta todas las opciones y avisa cuál se eligió',
      (tester) async {
    _Tipo? elegido;

    await tester.pumpWidget(_envolver(
      GrupoRadio<_Tipo>(
        etiqueta: 'Qué agregar',
        valor: _Tipo.producto,
        opciones: _Tipo.values,
        constructorEtiqueta: (t) => t.etiqueta,
        alCambiar: (t) => elegido = t,
      ),
    ));

    // Que las tres se vean sin abrir nada es el punto del widget.
    expect(find.text('Qué agregar'), findsOneWidget);
    expect(find.text('Producto'), findsOneWidget);
    expect(find.text('Servicio'), findsOneWidget);
    expect(find.text('Línea libre'), findsOneWidget);

    await tester.tap(find.text('Servicio'));
    expect(elegido, _Tipo.servicio);
  });

  testWidgets('pulsar la opción activa no vuelve a avisar', (tester) async {
    var avisos = 0;

    await tester.pumpWidget(_envolver(
      GrupoRadio<_Tipo>(
        valor: _Tipo.producto,
        opciones: _Tipo.values,
        constructorEtiqueta: (t) => t.etiqueta,
        alCambiar: (_) => avisos++,
      ),
    ));

    // Sin esto, el editor marcaría un guardado pendiente por un cambio que no
    // ocurrió y volvería a vaciar el buscador.
    await tester.tap(find.text('Producto'));
    await tester.pump();

    expect(avisos, 0);
  });

  testWidgets('sin etiqueta no dibuja el título', (tester) async {
    await tester.pumpWidget(_envolver(
      GrupoRadio<_Tipo>(
        valor: _Tipo.producto,
        opciones: _Tipo.values,
        constructorEtiqueta: (t) => t.etiqueta,
        alCambiar: (_) {},
      ),
    ));

    expect(find.text('Qué agregar'), findsNothing);
    expect(find.text('Producto'), findsOneWidget);
  });

  testWidgets('deshabilitado no responde', (tester) async {
    var avisos = 0;

    await tester.pumpWidget(_envolver(
      GrupoRadio<_Tipo>(
        valor: _Tipo.producto,
        opciones: _Tipo.values,
        constructorEtiqueta: (t) => t.etiqueta,
        alCambiar: (_) => avisos++,
        habilitado: false,
      ),
    ));

    await tester.tap(find.text('Servicio'));
    await tester.pump();

    expect(avisos, 0);
  });

  testWidgets('el ícono de cada opción se dibuja cuando se pide',
      (tester) async {
    await tester.pumpWidget(_envolver(
      GrupoRadio<_Tipo>(
        valor: _Tipo.producto,
        opciones: _Tipo.values,
        constructorEtiqueta: (t) => t.etiqueta,
        constructorIcono: (t) => switch (t) {
          _Tipo.producto => Icons.inventory_2_outlined,
          _Tipo.servicio => Icons.build_outlined,
          _Tipo.libre => Icons.edit_outlined,
        },
        alCambiar: (_) {},
      ),
    ));

    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
    expect(find.byIcon(Icons.build_outlined), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });
}
