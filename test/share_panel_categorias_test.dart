// PanelCategorias: el filtro lateral colapsable que reemplazó a los chips
// de categoría en Productos.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/frontend/share/share.dart';

const _categorias = [
  CategoriaPanelDato(id: 1, nombre: 'Frenos', color: Color(0xFF01B763)),
  CategoriaPanelDato(id: 2, nombre: 'Motor'),
  CategoriaPanelDato(
    id: 3,
    nombre: 'Transmisión',
    subcategorias: ['Kits', 'Cadenas'],
  ),
];

Widget _envolver(Widget panel) => MaterialApp(
      home: Scaffold(
        body: SizedBox(height: 420, child: Row(children: [panel])),
      ),
    );

void main() {
  testWidgets('expandido lista las categorías y avisa cuál se eligió',
      (tester) async {
    int? elegida = -1;

    await tester.pumpWidget(_envolver(
      PanelCategorias(
        categorias: _categorias,
        seleccionada: null,
        alSeleccionar: (id) => elegida = id,
        expandido: true,
        alAlternar: () {},
      ),
    ));

    expect(find.text('Categorías'), findsOneWidget);
    expect(find.text('Frenos'), findsOneWidget);
    expect(find.text('Motor'), findsOneWidget);

    await tester.tap(find.text('Motor'));
    expect(elegida, 2);
  });

  testWidgets('"Todas" limpia el filtro', (tester) async {
    int? elegida = 3;

    await tester.pumpWidget(_envolver(
      PanelCategorias(
        categorias: _categorias,
        seleccionada: 3,
        alSeleccionar: (id) => elegida = id,
        expandido: true,
        alAlternar: () {},
      ),
    ));

    await tester.tap(find.text('Todas'));
    expect(elegida, isNull);
  });

  testWidgets('contraído oculta los nombres pero deja seleccionar',
      (tester) async {
    int? elegida = -1;

    await tester.pumpWidget(_envolver(
      PanelCategorias(
        categorias: _categorias,
        seleccionada: null,
        alSeleccionar: (id) => elegida = id,
        expandido: false,
        alAlternar: () {},
      ),
    ));
    await tester.pumpAndSettle();

    // En la tira los nombres solo viven en el tooltip.
    expect(find.text('Frenos'), findsNothing);
    expect(find.text('Motor'), findsNothing);

    // La inicial es lo único que distingue una categoría de otra aquí.
    expect(find.text('F'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);

    await tester.tap(find.text('M'));
    expect(elegida, 2);
  });

  testWidgets('el control de la cabecera alterna el panel', (tester) async {
    var alternado = 0;

    await tester.pumpWidget(_envolver(
      PanelCategorias(
        categorias: _categorias,
        seleccionada: null,
        alSeleccionar: (_) {},
        expandido: true,
        alAlternar: () => alternado++,
      ),
    ));

    await tester.tap(find.byTooltip('Contraer categorías'));
    expect(alternado, 1);
  });

  testWidgets('el buscador solo se dibuja si hay controlador', (tester) async {
    await tester.pumpWidget(_envolver(
      PanelCategorias(
        categorias: _categorias,
        seleccionada: null,
        alSeleccionar: (_) {},
        expandido: true,
        alAlternar: () {},
      ),
    ));
    expect(find.byType(BarraBusqueda), findsNothing);

    final controlador = TextEditingController();
    addTearDown(controlador.dispose);
    var buscado = '';

    await tester.pumpWidget(_envolver(
      PanelCategorias(
        categorias: _categorias,
        seleccionada: null,
        alSeleccionar: (_) {},
        expandido: true,
        alAlternar: () {},
        controladorBusqueda: controlador,
        alBuscar: (texto) => buscado = texto,
      ),
    ));

    expect(find.byType(BarraBusqueda), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'fre');
    expect(buscado, 'fre');
  });

  testWidgets('las subcategorías se ven solo cuando su id está expandido',
      (tester) async {
    var desplegado = -1;

    await tester.pumpWidget(_envolver(
      PanelCategorias(
        categorias: _categorias,
        seleccionada: null,
        alSeleccionar: (_) {},
        expandido: true,
        alAlternar: () {},
        alAlternarSubcategorias: (id) => desplegado = id,
      ),
    ));

    expect(find.text('Kits'), findsNothing);

    // Frenos no tiene subcategorías: no debe ofrecer el control de despliegue.
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    expect(desplegado, 3);

    await tester.pumpWidget(_envolver(
      PanelCategorias(
        categorias: _categorias,
        seleccionada: null,
        alSeleccionar: (_) {},
        expandido: true,
        alAlternar: () {},
        expandidas: const {3},
        alAlternarSubcategorias: (_) {},
      ),
    ));

    expect(find.text('Kits'), findsOneWidget);
    expect(find.text('Cadenas'), findsOneWidget);
  });


  // El editor de cotizaciones y el de órdenes cambian entre productos,
  // servicios y línea libre. Antes el panel desaparecía en los dos últimos y
  // toda la rejilla saltaba de sitio; ahora se queda, apagado.
  testWidgets('deshabilitado no deja elegir ninguna categoría',
      (tester) async {
    var toques = 0;

    await tester.pumpWidget(_envolver(
      PanelCategorias(
        categorias: _categorias,
        seleccionada: 1,
        alSeleccionar: (_) => toques++,
        expandido: true,
        alAlternar: () {},
        habilitado: false,
      ),
    ));

    await tester.tap(find.text('Motor'));
    await tester.tap(find.text('Todas'));
    await tester.pump();

    expect(toques, 0);
    expect(find.text('Frenos'), findsOneWidget,
        reason: 'sigue a la vista, solo que apagado');
  });

  testWidgets('deshabilitado se sigue pudiendo contraer y expandir',
      (tester) async {
    var alternado = 0;

    await tester.pumpWidget(_envolver(
      PanelCategorias(
        categorias: _categorias,
        seleccionada: null,
        alSeleccionar: (_) {},
        expandido: true,
        alAlternar: () => alternado++,
        habilitado: false,
      ),
    ));

    await tester.tap(find.byTooltip('Contraer categorías'));
    expect(alternado, 1);
  });
}
