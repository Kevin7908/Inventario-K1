// TarjetaProducto: la tarjeta de las rejillas de venta.
//
// Es share2, así que lo que se comprueba es que **no decide ni formatea nada**:
// recibe textos ya resueltos, la foto como widget, y avisa por callbacks.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/frontend/share2/share2.dart';

Widget _envolver(Widget hijo) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 240,
            // El mismo alto que le reserva la rejilla: si la tarjeta crece y
            // no se actualiza `altoSugerido`, todos estos tests revientan.
            height: TarjetaProducto.altoSugerido,
            child: hijo,
          ),
        ),
      ),
    );

void main() {
  testWidgets('pinta nombre, código, detalle y precio tal cual llegan',
      (tester) async {
    await tester.pumpWidget(
      _envolver(
        const TarjetaProducto(
          nombre: 'Aceite Motul 20W50',
          codigo: 'SKU-1123',
          detalle: '12 en stock',
          precio: r'$32.000',
          etiquetaAgregar: 'Agregar',
        ),
      ),
    );

    expect(find.text('Aceite Motul 20W50'), findsOneWidget);
    expect(find.text('SKU-1123'), findsOneWidget);
    expect(find.text('12 en stock'), findsOneWidget);
    expect(find.text(r'$32.000'), findsOneWidget);
  });

  testWidgets('sin foto cae en el marcador', (tester) async {
    await tester.pumpWidget(
      _envolver(
        const TarjetaProducto(
          nombre: 'Filtro de aire',
          precio: r'$18.000',
          etiquetaAgregar: 'Agregar',
        ),
      ),
    );

    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
  });

  testWidgets('la foto llega de fuera: share2 no lee del disco',
      (tester) async {
    await tester.pumpWidget(
      _envolver(
        const TarjetaProducto(
          nombre: 'Filtro de aire',
          precio: r'$18.000',
          etiquetaAgregar: 'Agregar',
          imagen: ColoredBox(color: Color(0xFF01B763)),
        ),
      ),
    );

    expect(find.byType(ColoredBox), findsWidgets);
    expect(find.byIcon(Icons.image_outlined), findsNothing);
  });

  testWidgets('el botón verde y la tarjeta entera avisan por separado',
      (tester) async {
    var agregados = 0;
    var toques = 0;

    await tester.pumpWidget(
      _envolver(
        TarjetaProducto(
          nombre: 'Pastilla de freno',
          precio: r'$45.000',
          etiquetaAgregar: 'Agregar a la cotización',
          alAgregar: () => agregados++,
          alPresionar: () => toques++,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    expect(agregados, 1);
    expect(toques, 0, reason: 'el botón no debe disparar también la tarjeta');

    await tester.tap(find.text('Pastilla de freno'));
    await tester.pump();
    expect(toques, 1);
  });

  testWidgets('el botón de solo ícono lleva tooltip', (tester) async {
    await tester.pumpWidget(
      _envolver(
        TarjetaProducto(
          nombre: 'Pastilla de freno',
          precio: r'$45.000',
          etiquetaAgregar: 'Agregar a la cotización',
          alAgregar: () {},
        ),
      ),
    );

    expect(
      find.byTooltip('Agregar a la cotización'),
      findsOneWidget,
      reason: 'lo exige §8: todo botón de solo ícono lo lleva',
    );
  });

  testWidgets('sin alAgregar el botón queda deshabilitado', (tester) async {
    await tester.pumpWidget(
      _envolver(
        const TarjetaProducto(
          nombre: 'Descontinuado',
          precio: r'$0',
          etiquetaAgregar: 'Agregar',
        ),
      ),
    );

    // El InkWell más cercano al ícono es el del propio botón; el siguiente ya
    // es el de la tarjeta entera.
    final boton = tester.widget<InkWell>(
      find
          .ancestor(
            of: find.byIcon(Icons.add_rounded),
            matching: find.byType(InkWell),
          )
          .first,
    );
    expect(boton.onTap, isNull);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.add_rounded)).color,
      ColoresApp.textDisabled,
    );
  });

  testWidgets('la ubicación va en su propia línea, debajo del stock',
      (tester) async {
    await tester.pumpWidget(
      _envolver(
        const TarjetaProducto(
          nombre: 'Pastilla de freno',
          codigo: 'SKU-1123',
          detalle: '12 en stock',
          ubicacion: 'Estante A-3',
          precio: r'$45.000',
          etiquetaAgregar: 'Agregar',
        ),
      ),
    );

    expect(find.text('Estante A-3'), findsOneWidget);
    expect(find.byIcon(Icons.place_outlined), findsOneWidget);
    expect(find.text('SKU-1123'), findsOneWidget);

    // Estaba como etiqueta sobre la foto y se leía como parte de la imagen.
    // Ahora es un dato más del producto: va debajo del stock.
    final stock = tester.getTopLeft(find.text('12 en stock')).dy;
    final ubicacion = tester.getTopLeft(find.text('Estante A-3')).dy;
    expect(ubicacion, greaterThan(stock));
  });

  testWidgets('sin ubicación no queda ni el ícono suelto', (tester) async {
    // Un producto sin bodega asignada no debe pintar una etiqueta vacía.
    await tester.pumpWidget(
      _envolver(
        const TarjetaProducto(
          nombre: 'Pastilla de freno',
          precio: r'$45.000',
          etiquetaAgregar: 'Agregar',
          ubicacion: '',
        ),
      ),
    );

    expect(find.byIcon(Icons.place_outlined), findsNothing);
  });

  testWidgets('la tarjeta con ubicación no desborda el alto reservado',
      (tester) async {
    // La rejilla le reserva `altoSugerido` exacto, y la ubicación ocupa una
    // línea propia. Si el alto se queda corto, este test lo delata con la
    // franja amarilla y negra.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: TarjetaProducto.anchoMinimo,
              height: TarjetaProducto.altoSugerido,
              child: TarjetaProducto(
                nombre: 'Pastilla de freno delantera cerámica reforzada',
                codigo: 'SKU-1123',
                ubicacion: 'Estante A-3',
                detalle: '12 en stock',
                precio: r'$45.000',
                etiquetaAgregar: 'Agregar',
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
