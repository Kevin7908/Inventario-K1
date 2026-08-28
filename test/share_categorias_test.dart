// Widgets de share agregados al migrar Categorías.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/frontend/share/share.dart';

Widget _envolver(Widget child) => MaterialApp(
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(24), child: child),
      ),
    );

void main() {
  group('MarcadorIdentidad', () {
    testWidgets('con ícono muestra el ícono y no la inicial', (tester) async {
      await tester.pumpWidget(_envolver(
        const MarcadorIdentidad(icono: Icons.layers_outlined, inicial: 'F'),
      ));

      expect(find.byIcon(Icons.layers_outlined), findsOneWidget);
      expect(find.text('F'), findsNothing);
    });

    testWidgets('sin ícono cae en la inicial', (tester) async {
      await tester.pumpWidget(_envolver(
        const MarcadorIdentidad(inicial: 'F'),
      ));

      expect(find.text('F'), findsOneWidget);
    });

    testWidgets('tamanoContenido manda sobre la proporción del lado',
        (tester) async {
      // En cuadros chicos la proporción dejaría la letra ilegible.
      await tester.pumpWidget(_envolver(
        const MarcadorIdentidad(inicial: 'F', lado: 18, tamanoContenido: 10),
      ));

      final texto = tester.widget<Text>(find.text('F'));
      expect(texto.style?.fontSize, 10);
    });
  });

  group('TarjetaCatalogo', () {
    testWidgets('horizontal pone el marcador al lado del título',
        (tester) async {
      await tester.pumpWidget(_envolver(
        const TarjetaCatalogo(
          icono: Icons.build_outlined,
          titulo: 'Frenos',
          subtitulo: '12 productos',
        ),
      ));

      final marcador = tester.getCenter(find.byIcon(Icons.build_outlined));
      final titulo = tester.getCenter(find.text('Frenos'));

      expect(marcador.dx, lessThan(titulo.dx));
      expect((marcador.dy - titulo.dy).abs(), lessThan(24));
      expect(find.text('12 productos'), findsOneWidget);
    });

    testWidgets('vertical pone el marcador encima del título', (tester) async {
      await tester.pumpWidget(_envolver(
        const TarjetaCatalogo(
          orientacion: OrientacionTarjeta.vertical,
          icono: Icons.build_outlined,
          titulo: 'Frenos',
        ),
      ));

      final marcador = tester.getCenter(find.byIcon(Icons.build_outlined));
      final titulo = tester.getCenter(find.text('Frenos'));

      expect(marcador.dy, lessThan(titulo.dy));
    });

    testWidgets('el marcador propio reemplaza al cuadro de ícono',
        (tester) async {
      await tester.pumpWidget(_envolver(
        const TarjetaCatalogo(
          orientacion: OrientacionTarjeta.vertical,
          marcador: MarcadorIdentidad(inicial: 'F', lado: 50),
          titulo: 'Frenos',
        ),
      ));

      expect(find.text('F'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('avisa del toque y muestra las acciones', (tester) async {
      var toques = 0;

      await tester.pumpWidget(_envolver(
        TarjetaCatalogo(
          orientacion: OrientacionTarjeta.vertical,
          icono: Icons.build_outlined,
          titulo: 'Frenos',
          alPresionar: () => toques++,
          acciones: BotonIcono(
            icono: Icons.delete_outline_rounded,
            tooltip: 'Eliminar',
            alPresionar: () {},
          ),
        ),
      ));

      expect(find.byTooltip('Eliminar'), findsOneWidget);

      await tester.tap(find.text('Frenos'));
      expect(toques, 1);
    });
  });

  testWidgets('BotonVolver muestra el destino y avisa', (tester) async {
    var vuelto = 0;

    await tester.pumpWidget(_envolver(
      BotonVolver(
        etiqueta: 'Volver a categorías',
        alPresionar: () => vuelto++,
      ),
    ));

    expect(find.text('Volver a categorías'), findsOneWidget);
    await tester.tap(find.text('Volver a categorías'));
    expect(vuelto, 1);
  });

  group('AtajosFormulario', () {
    Future<void> pulsar(WidgetTester tester, LogicalKeyboardKey tecla,
        {bool conControl = false}) async {
      if (conControl) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      }
      await tester.sendKeyEvent(tecla);
      if (conControl) {
        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      }
      await tester.pump();
    }

    testWidgets('Esc cancela y Ctrl+Enter guarda', (tester) async {
      var guardados = 0;
      var cancelados = 0;

      await tester.pumpWidget(_envolver(
        AtajosFormulario(
          alGuardar: () => guardados++,
          alCancelar: () => cancelados++,
          child: const Text('formulario'),
        ),
      ));

      await pulsar(tester, LogicalKeyboardKey.escape);
      expect(cancelados, 1);

      await pulsar(tester, LogicalKeyboardKey.enter, conControl: true);
      expect(guardados, 1);
    });

    testWidgets('Enter solo no guarda: en descripciones hace salto de línea',
        (tester) async {
      var guardados = 0;

      await tester.pumpWidget(_envolver(
        AtajosFormulario(
          alGuardar: () => guardados++,
          child: const Text('formulario'),
        ),
      ));

      await pulsar(tester, LogicalKeyboardKey.enter);
      expect(guardados, 0);
    });
  });
}
