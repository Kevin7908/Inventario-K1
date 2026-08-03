// Regresión del rediseño de Configuración: encabezado fijo de TablaGenerica y
// render de los widgets de share2 creados/ajustados para esa pantalla.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/frontend/share2/share2.dart';

class _Item {
  const _Item(this.nombre, this.abrev, this.uso);
  final String nombre;
  final String abrev;
  final String uso;
}

Widget _envolver(Widget child) => MaterialApp(
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(32), child: child)),
    );

void main() {
  testWidgets('TablaGenerica: encabezado fijo, filas scrollean', (tester) async {
    final items = List.generate(60, (i) => _Item('Unidad $i', 'U$i', 'Uso $i'));

    await tester.pumpWidget(_envolver(
      Column(
        children: [
          Expanded(
            child: TablaGenerica<_Item>(
              items: items,
              mensajeVacio: 'vacío',
              columnas: [
                ColumnaTabla(titulo: 'Unidad', flex: 2, constructor: (i) => Text(i.nombre)),
                ColumnaTabla(titulo: 'Abreviatura', flex: 2, constructor: (i) => Text(i.abrev)),
                ColumnaTabla(titulo: 'Uso típico', flex: 4, constructor: (i) => Text(i.uso)),
              ],
            ),
          ),
        ],
      ),
    ));

    // Encabezado visible antes de scrollear.
    expect(find.text('UNIDAD'), findsOneWidget);
    expect(find.text('Unidad 0'), findsOneWidget);

    // Scrollea las filas hasta el fondo.
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    // El encabezado SIGUE visible; la primera fila ya no.
    expect(find.text('UNIDAD'), findsOneWidget);
    expect(find.text('ABREVIATURA'), findsOneWidget);
    expect(find.text('Unidad 0'), findsNothing);
  });

  testWidgets('TablaGenerica: estado vacío', (tester) async {
    await tester.pumpWidget(_envolver(
      TablaGenerica<_Item>(
        items: const [],
        mensajeVacio: 'Aún no hay unidades',
        columnas: [
          ColumnaTabla(titulo: 'Unidad', constructor: (i) => Text(i.nombre)),
        ],
      ),
    ));

    expect(find.text('Aún no hay unidades'), findsOneWidget);
    expect(find.text('UNIDAD'), findsOneWidget);
  });

  testWidgets('TarjetaCatalogo: nombre largo baja de línea sin desbordar',
      (tester) async {
    const largo = 'Latonería, pintura y enderezado de chasis';

    await tester.pumpWidget(_envolver(
      GridView.builder(
        // Mismas medidas que usa la grilla de Especializaciones.
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 420,
          mainAxisExtent: 104,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 4,
        itemBuilder: (_, i) => TarjetaCatalogo(
          icono: Icons.build_outlined,
          titulo: i == 0 ? largo : 'Motor $i',
          subtitulo: '$i técnicos',
          acciones: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BotonIcono(icono: Icons.edit_outlined, alPresionar: () {}),
              BotonIcono(icono: Icons.delete_outline_rounded, alPresionar: () {}),
            ],
          ),
        ),
      ),
    ));

    // Un overflow de layout lanzaría excepción y haría fallar el test.
    expect(tester.takeException(), isNull);
    expect(find.text(largo), findsOneWidget);

    // El título se reparte en dos líneas en lugar de recortarse en una.
    final titulo = tester.widget<Text>(find.text(largo));
    expect(titulo.maxLines, 2);
    expect(tester.getSize(find.text(largo)).height,
        greaterThan(20)); // más alto que una sola línea
  });

  testWidgets('IndicadorEstado renderiza con y sin punto', (tester) async {
    await tester.pumpWidget(_envolver(
      const Row(
        children: [
          IndicadorEstado(
            etiqueta: 'Activo',
            color: ColoresApp.statusSuccess,
            colorFondo: ColoresApp.statusSuccessBg,
            conPunto: true,
          ),
          SizedBox(width: 8),
          IndicadorEstado(
            etiqueta: 'Inactivo',
            color: ColoresApp.statusNeutral,
            colorFondo: ColoresApp.statusNeutralBg,
          ),
        ],
      ),
    ));

    expect(find.text('Activo'), findsOneWidget);
    expect(find.text('Inactivo'), findsOneWidget);
  });

  testWidgets('BarraTabsSecundaria marca la pestaña activa', (tester) async {
    await tester.pumpWidget(_envolver(
      Align(
        alignment: Alignment.topLeft,
        child: BarraTabsSecundaria(
          indiceActivo: 2,
          tabs: [
            TabSecundariaDato(etiqueta: 'General', alPresionar: () {}),
            TabSecundariaDato(etiqueta: 'Unidades de medida', alPresionar: () {}),
            TabSecundariaDato(etiqueta: 'Especializaciones', alPresionar: () {}),
            TabSecundariaDato(etiqueta: 'Servicios', alPresionar: () {}),
          ],
        ),
      ),
    ));

    expect(find.text('Especializaciones'), findsOneWidget);
    expect(find.text('Servicios'), findsOneWidget);
  });
}
