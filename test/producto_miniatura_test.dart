// MiniaturaProducto: se pinta en cada fila de la tabla y en cada tarjeta, así
// que no puede tocar el disco de forma síncrona dentro de build().
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/frontend/features/productos/vista/producto_vista.dart';

Widget _envolver(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('sin ruta muestra el marcador', (tester) async {
    await tester.pumpWidget(_envolver(const MiniaturaProducto(rutaImagen: null)));

    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('con ruta vacía muestra el marcador', (tester) async {
    await tester.pumpWidget(_envolver(const MiniaturaProducto(rutaImagen: '')));

    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('una ruta inexistente cae en el marcador sin reventar',
      (tester) async {
    // Antes esto se resolvía con File().existsSync() dentro de build(); ahora
    // lo cubre el errorBuilder de Image.file, sin I/O síncrono por fila.
    //
    // `runAsync` es necesario: cargar el archivo es I/O real y con el reloj
    // falso de los tests el error nunca llega a propagarse.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        _envolver(
          const MiniaturaProducto(rutaImagen: '/ruta/que/no/existe.png'),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
  });

  testWidgets('decodifica al tamaño en que se pinta, no al original',
      (tester) async {
    await tester.pumpWidget(
      _envolver(
        const MiniaturaProducto(rutaImagen: '/ruta/que/no/existe.png', lado: 44),
      ),
    );

    final imagen = tester.widget<Image>(find.byType(Image));
    // 44 lógicos × devicePixelRatio del test (3.0) = 132.
    expect((imagen.image as ResizeImage).width, 132);
  });
}
