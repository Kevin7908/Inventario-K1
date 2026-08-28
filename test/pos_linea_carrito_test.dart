// La línea del carrito no tenía ni un test, y es la del módulo que más se usa.
//
// Se escriben **antes** de unificarla con las de cotizaciones y órdenes: son
// la red que dice que la versión compartida se comporta igual que ésta. Por
// eso describen lo que se ve y lo que se avisa, no cómo está construida por
// dentro.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';
import 'package:inventario_k1/frontend/features/pos/modelo/item_carrito.dart';
import 'package:inventario_k1/frontend/features/pos/widgets/linea_carrito.dart';
import 'package:inventario_k1/frontend/share2/share2.dart';

Producto _producto({double stock = 12}) => Producto(
      id: 7,
      sku: 'SKU-1123',
      nombre: 'Aceite Motul 20W50',
      precioCompra: 20000,
      precioVenta: 32000,
      stockActual: stock,
      stockMinimo: 2,
      aplicaIva: false,
      activo: true,
    );

ItemCarrito _item({int cantidad = 1, double stock = 12}) => ItemCarrito(
      producto: _producto(stock: stock),
      cantidad: cantidad,
      precioUnitario: 32000,
    );

Future<void> _pump(
  WidgetTester tester,
  ItemCarrito item, {
  ValueChanged<int>? alCambiarCantidad,
  VoidCallback? alEliminar,
}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: LineaCarrito(
              item: item,
              alCambiarCantidad: alCambiarCantidad ?? (_) {},
              alEliminar: alEliminar ?? () {},
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('muestra el nombre y el precio unitario, no el subtotal',
      (tester) async {
    await _pump(tester, _item(cantidad: 3));

    expect(find.text('Aceite Motul 20W50'), findsOneWidget);
    // 3 x 32.000 = 96.000, que es lo que **no** va aquí: el subtotal se lee
    // en el pie del panel.
    expect(find.text(r'$32.000'), findsOneWidget);
    expect(find.text(r'$96.000'), findsNothing);
  });

  testWidgets('lleva control de cantidad y no papelera', (tester) async {
    await _pump(tester, _item());

    expect(find.byType(ControlCantidad), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
  });

  testWidgets('el − con cantidad 1 quita la línea en vez de dejarla en cero',
      (tester) async {
    var eliminada = false;
    var cantidadAvisada = -1;
    await _pump(
      tester,
      _item(),
      alCambiarCantidad: (c) => cantidadAvisada = c,
      alEliminar: () => eliminada = true,
    );

    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.pump();

    expect(eliminada, isTrue);
    expect(cantidadAvisada, -1, reason: 'no se avisa una cantidad 0');
  });

  testWidgets('el + suma una unidad', (tester) async {
    var cantidadAvisada = 0;
    await _pump(
      tester,
      _item(cantidad: 2),
      alCambiarCantidad: (c) => cantidadAvisada = c,
    );

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();

    expect(cantidadAvisada, 3);
  });

  testWidgets('el stock de bodega es el tope: el + se apaga al llegar',
      (tester) async {
    // El mostrador no puede vender lo que no está.
    await _pump(tester, _item(cantidad: 3, stock: 3));

    final mas = tester.widget<InkWell>(
      find.ancestor(
        of: find.byIcon(Icons.add_rounded),
        matching: find.byType(InkWell),
      ),
    );
    expect(mas.onTap, isNull);
  });

  testWidgets('escribir más que el stock recorta al disponible', (tester) async {
    var cantidadAvisada = 0;
    await _pump(
      tester,
      _item(cantidad: 1, stock: 8),
      alCambiarCantidad: (c) => cantidadAvisada = c,
    );

    await tester.enterText(find.byType(TextField), '50');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(cantidadAvisada, 8, reason: 'hay 8, se venden 8');
  });

  testWidgets('la cantidad no admite decimales', (tester) async {
    // Decisión de negocio: en el mostrador se venden unidades enteras.
    var cantidadAvisada = 0;
    await _pump(
      tester,
      // Stock alto a propósito: con el tope por debajo, el recorte al
      // disponible taparía lo que este test quiere ver.
      _item(stock: 100),
      alCambiarCantidad: (c) => cantidadAvisada = c,
    );

    await tester.enterText(find.byType(TextField), '2.5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(cantidadAvisada, 25, reason: 'el punto ni se puede teclear');
  });
}
