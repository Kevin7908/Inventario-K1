// Las piezas que salieron de unificar las líneas del POS, de cotizaciones y
// de órdenes. Lo que se comprueba aquí es el contrato de cada una: qué pinta
// y qué deja decidir a quien la usa.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/frontend/share2/share2.dart';

Future<void> _pump(WidgetTester tester, Widget hijo) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SizedBox(width: 360, child: hijo)),
      ),
    );

void main() {
  group('FilaDocumento', () {
    testWidgets('pinta principal, título, precio y acciones', (tester) async {
      await _pump(
        tester,
        const FilaDocumento(
          principal: Icon(Icons.inventory_2_outlined),
          titulo: 'Pastilla de freno',
          precio: Text(r'$32.000'),
          acciones: [Icon(Icons.delete_outline_rounded)],
        ),
      );

      expect(find.text('Pastilla de freno'), findsOneWidget);
      expect(find.text(r'$32.000'), findsOneWidget);
      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });

    testWidgets('sin subtítulo no deja hueco', (tester) async {
      await _pump(
        tester,
        const FilaDocumento(
          principal: SizedBox(width: 48, height: 48),
          titulo: 'Cambio de aceite',
          precio: Text(r'$50.000'),
        ),
      );

      // Dos textos y no tres: el subtítulo no existe, no está vacío.
      expect(find.byType(Text), findsNWidgets(2));
    });

    testWidgets('el subtítulo va entre el título y el precio', (tester) async {
      await _pump(
        tester,
        const FilaDocumento(
          principal: SizedBox(width: 48, height: 48),
          titulo: 'Sincronización',
          subtitulo: 'Ana Torres',
          precio: Text(r'$50.000'),
        ),
      );

      final titulo = tester.getCenter(find.text('Sincronización'));
      final subtitulo = tester.getCenter(find.text('Ana Torres'));
      final precio = tester.getCenter(find.text(r'$50.000'));
      expect(titulo.dy, lessThan(subtitulo.dy));
      expect(subtitulo.dy, lessThan(precio.dy));
    });

    testWidgets('tachado cruza el título', (tester) async {
      await _pump(
        tester,
        const FilaDocumento(
          principal: SizedBox(width: 48, height: 48),
          titulo: 'Sincronización',
          precio: Text(r'$50.000'),
          tachado: true,
        ),
      );

      final texto = tester.widget<Text>(find.text('Sincronización'));
      expect(texto.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('un título largo se recorta en vez de desbordar',
        (tester) async {
      await _pump(
        tester,
        const FilaDocumento(
          principal: SizedBox(width: 48, height: 48),
          titulo: 'Kit de arrastre completo con corona, piñón y cadena '
              'reforzada para trabajo pesado',
          precio: Text(r'$120.000'),
        ),
      );

      expect(tester.takeException(), isNull);
      final texto = tester.widget<Text>(find.textContaining('Kit de arrastre'));
      expect(texto.maxLines, 1);
      expect(texto.overflow, TextOverflow.ellipsis);
    });
  });

  group('CampoPrecioLinea', () {
    testWidgets('avisa el número tecleado', (tester) async {
      final controlador = TextEditingController();
      addTearDown(controlador.dispose);
      var avisado = -1;

      await _pump(
        tester,
        CampoPrecioLinea(
          controlador: controlador,
          alCambiar: (v) => avisado = v,
        ),
      );
      await tester.enterText(find.byType(TextField), '45000');

      expect(avisado, 45000);
    });

    testWidgets('no deja teclear letras ni puntos', (tester) async {
      final controlador = TextEditingController();
      addTearDown(controlador.dispose);

      await _pump(
        tester,
        CampoPrecioLinea(controlador: controlador, alCambiar: (_) {}),
      );
      await tester.enterText(find.byType(TextField), r'45.000$abc');

      expect(controlador.text, '45000');
    });

    testWidgets('vacío avisa cero, no null', (tester) async {
      final controlador = TextEditingController(text: '900');
      addTearDown(controlador.dispose);
      var avisado = -1;

      await _pump(
        tester,
        CampoPrecioLinea(
          controlador: controlador,
          alCambiar: (v) => avisado = v,
        ),
      );
      await tester.enterText(find.byType(TextField), '');

      expect(avisado, 0);
    });

    testWidgets('deshabilitado no deja escribir', (tester) async {
      final controlador = TextEditingController(text: '900');
      addTearDown(controlador.dispose);

      await _pump(
        tester,
        CampoPrecioLinea(
          controlador: controlador,
          alCambiar: (_) {},
          habilitado: false,
        ),
      );

      final campo = tester.widget<TextField>(find.byType(TextField));
      expect(campo.enabled, isFalse);
    });
  });

  group('EstadoVacio', () {
    testWidgets('muestra ícono, título y pista', (tester) async {
      await _pump(
        tester,
        const EstadoVacio(
          icono: Icons.shopping_cart_outlined,
          titulo: 'El carrito está vacío',
          pista: 'Toca un producto de la izquierda.',
        ),
      );

      expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
      expect(find.text('El carrito está vacío'), findsOneWidget);
      expect(find.text('Toca un producto de la izquierda.'), findsOneWidget);
    });

    testWidgets('sin pista solo va el título', (tester) async {
      await _pump(
        tester,
        const EstadoVacio(
          icono: Icons.search_off_rounded,
          titulo: 'Sin resultados',
        ),
      );

      expect(find.byType(Text), findsOneWidget);
    });
  });

  group('EncabezadoGrupoLineas', () {
    testWidgets('pinta el título y el subtotal formateado', (tester) async {
      await _pump(
        tester,
        const EncabezadoGrupoLineas(
          icono: Icons.build_outlined,
          titulo: 'Servicios',
          subtotal: 150000,
        ),
      );

      expect(find.text('Servicios'), findsOneWidget);
      expect(find.text(r'$150.000'), findsOneWidget);
      expect(find.byIcon(Icons.build_outlined), findsOneWidget);
    });

    testWidgets('un subtotal en cero se muestra, no se oculta', (tester) async {
      await _pump(
        tester,
        const EncabezadoGrupoLineas(
          icono: Icons.edit_outlined,
          titulo: 'Otros cargos',
          subtotal: 0,
        ),
      );

      expect(find.text(r'$0'), findsOneWidget);
    });
  });
}
