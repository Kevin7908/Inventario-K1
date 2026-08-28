// Widgets de share agregados para el rediseño de Productos.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/frontend/share/share.dart';

Widget _envolver(Widget child) => MaterialApp(
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(24), child: child),
      ),
    );

void main() {
  testWidgets('SelectorWidget propaga la opción nula de un tipo nulable',
      (tester) async {
    // Regresión: antes descartaba `null` en onChanged, así que no se podía
    // volver a "Sin categoría" una vez elegida una categoría.
    String? elegido = 'Frenos';

    await tester.pumpWidget(_envolver(
      StatefulBuilder(
        builder: (context, setState) => SelectorWidget<String?>(
          etiqueta: 'Categoría',
          valor: elegido,
          opciones: const <String?>[null, 'Frenos', 'Motor'],
          constructorEtiqueta: (v) => v ?? 'Sin categoría',
          alCambiar: (v) => setState(() => elegido = v),
        ),
      ),
    ));

    await tester.tap(find.byType(DropdownButton<String?>));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sin categoría').last);
    await tester.pumpAndSettle();

    expect(elegido, isNull);
  });

  testWidgets('SelectorWidget sigue ignorando null si el tipo no es nulable',
      (tester) async {
    var elegido = 'Frenos';

    await tester.pumpWidget(_envolver(
      StatefulBuilder(
        builder: (context, setState) => SelectorWidget<String>(
          etiqueta: 'Categoría',
          valor: elegido,
          opciones: const ['Frenos', 'Motor'],
          constructorEtiqueta: (v) => v,
          alCambiar: (v) => setState(() => elegido = v),
        ),
      ),
    ));

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Motor').last);
    await tester.pumpAndSettle();

    expect(elegido, 'Motor');
  });

  testWidgets('ChipFiltro distingue seleccionado de no seleccionado',
      (tester) async {
    int? activa;

    await tester.pumpWidget(_envolver(
      StatefulBuilder(
        builder: (context, setState) => Wrap(
          spacing: 9,
          children: [
            ChipFiltro(
              etiqueta: 'Todas',
              seleccionado: activa == null,
              alPresionar: () => setState(() => activa = null),
            ),
            ChipFiltro(
              etiqueta: 'Frenos',
              seleccionado: activa == 1,
              alPresionar: () => setState(() => activa = 1),
            ),
          ],
        ),
      ),
    ));

    await tester.tap(find.text('Frenos'));
    await tester.pumpAndSettle();

    expect(activa, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TarjetaInfo muestra etiqueta y valor', (tester) async {
    await tester.pumpWidget(_envolver(
      const Row(
        children: [
          Expanded(
            child: TarjetaInfo(etiqueta: 'Stock disponible', valor: '42 und'),
          ),
          SizedBox(width: 13),
          Expanded(
            child: TarjetaInfo(etiqueta: 'Stock mínimo', valor: '10 und'),
          ),
        ],
      ),
    ));

    expect(find.text('Stock disponible'), findsOneWidget);
    expect(find.text('42 und'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('BotonSecundario responde y se deshabilita', (tester) async {
    var pulsado = 0;

    await tester.pumpWidget(_envolver(
      Column(
        children: [
          BotonSecundario(
            etiqueta: 'Cancelar',
            alPresionar: () => pulsado++,
          ),
          const SizedBox(height: 12),
          const BotonSecundario(
            etiqueta: 'Editar producto',
            icono: Icons.edit_outlined,
            oscuro: true,
            expandido: true,
            alPresionar: null,
          ),
        ],
      ),
    ));

    await tester.tap(find.text('Cancelar'));
    await tester.pump();
    expect(pulsado, 1);

    // Deshabilitado: el tap no debe disparar nada ni romper el layout.
    await tester.tap(find.text('Editar producto'));
    await tester.pump();
    expect(pulsado, 1);
    expect(tester.takeException(), isNull);
  });
}
