// `FichaResumen`: la ficha compacta que reemplazó a los campos de cliente y
// moto apilados en los paneles de 360 px.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/frontend/share/share.dart';

Widget _envolver(Widget child) => MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(width: 320, child: child),
        ),
      ),
    );

/// Los textos de la ficha propiamente dicha: título y subtítulo. Deja fuera
/// el del marcador, que vive en su propio cuadro.
final _textosDeLaColumna = find.descendant(
  of: find.byType(Column),
  matching: find.byType(Text),
);

TextStyle _estiloDe(WidgetTester tester, String texto) =>
    tester.widget<Text>(find.text(texto)).style!;

void main() {
  testWidgets('muestra el título y el subtítulo que recibe', (tester) async {
    await tester.pumpWidget(
      _envolver(
        FichaResumen(
          titulo: 'Kevin Ramírez',
          subtitulo: 'KMN12C · Vence 25/08/2026',
          inicial: 'K',
          etiquetaAccion: 'Cambiar el cliente',
          alPresionar: () {},
        ),
      ),
    );

    expect(find.text('Kevin Ramírez'), findsOneWidget);
    expect(find.text('KMN12C · Vence 25/08/2026'), findsOneWidget);
    expect(find.text('K'), findsOneWidget);
  });

  testWidgets('sin subtítulo no deja el hueco de la segunda línea',
      (tester) async {
    await tester.pumpWidget(
      _envolver(
        FichaResumen(
          titulo: 'Mostrador',
          etiquetaAccion: 'Elegir el cliente',
          alPresionar: () {},
        ),
      ),
    );

    // Solo el título dentro de la columna de textos: si el subtítulo se
    // pintara vacío habría dos. (El marcador tiene el suyo, fuera de ella.)
    expect(_textosDeLaColumna, findsOneWidget);
  });

  testWidgets('un subtítulo vacío tampoco se pinta', (tester) async {
    await tester.pumpWidget(
      _envolver(
        FichaResumen(
          titulo: 'Mostrador',
          subtitulo: '',
          etiquetaAccion: 'Elegir el cliente',
          alPresionar: () {},
        ),
      ),
    );

    expect(_textosDeLaColumna, findsOneWidget);
  });

  testWidgets('tocar la ficha avisa al padre', (tester) async {
    var toques = 0;
    await tester.pumpWidget(
      _envolver(
        FichaResumen(
          titulo: 'Mostrador',
          etiquetaAccion: 'Elegir el cliente',
          alPresionar: () => toques++,
        ),
      ),
    );

    await tester.tap(find.byType(FichaResumen));
    await tester.pump();

    expect(toques, 1);
  });

  testWidgets('sin acción no responde al toque', (tester) async {
    await tester.pumpWidget(
      _envolver(
        const FichaResumen(
          titulo: 'Mostrador',
          etiquetaAccion: 'Elegir el cliente',
          alPresionar: null,
        ),
      ),
    );

    // No hay nada que verificar más allá de que el toque no revienta: el
    // `InkWell` sin `onTap` queda inerte.
    await tester.tap(find.byType(FichaResumen));
    await tester.pump();

    expect(find.text('Mostrador'), findsOneWidget);
  });

  testWidgets('en modo tenue el título va con el gris de placeholder',
      (tester) async {
    await tester.pumpWidget(
      _envolver(
        FichaResumen(
          titulo: 'Mostrador',
          tenue: true,
          etiquetaAccion: 'Elegir el cliente',
          alPresionar: () {},
        ),
      ),
    );

    expect(_estiloDe(tester, 'Mostrador').color, ColoresApp.textDisabled);
  });

  testWidgets('con algo elegido el título va con el color normal',
      (tester) async {
    await tester.pumpWidget(
      _envolver(
        FichaResumen(
          titulo: 'Kevin Ramírez',
          inicial: 'K',
          etiquetaAccion: 'Cambiar el cliente',
          alPresionar: () {},
        ),
      ),
    );

    expect(
      _estiloDe(tester, 'Kevin Ramírez').color,
      isNot(ColoresApp.textDisabled),
    );
  });

  testWidgets('lleva el tooltip de su acción, que es lo que se pulsa',
      (tester) async {
    await tester.pumpWidget(
      _envolver(
        FichaResumen(
          titulo: 'Mostrador',
          etiquetaAccion: 'Elegir el cliente de la venta',
          alPresionar: () {},
        ),
      ),
    );

    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, 'Elegir el cliente de la venta');
  });
}
