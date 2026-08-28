// La rejilla con la que se eligen productos para un documento.
//
// Existe una sola —`GrillaProductosCatalogo`— y la usan el punto de venta, el
// editor de cotizaciones y el de órdenes. Antes había tres copias con tres
// nombres distintos, y por ahí se coló que la ubicación en bodega apareciera
// en dos de las tres pantallas. Lo que se prueba aquí vale, por construcción,
// para las tres.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';
import 'package:inventario_k1/frontend/features/productos/widgets/grilla_productos_catalogo.dart';

const _productos = [
  Producto(
    id: 7,
    sku: 'SKU-1123',
    nombre: 'Aceite Motul 20W50',
    precioCompra: 20000,
    precioVenta: 32000,
    stockActual: 12,
    stockMinimo: 2,
    ubicacionBodega: 'Estante A-3',
    aplicaIva: false,
    activo: true,
  ),
  Producto(
    id: 8,
    sku: 'SKU-1201',
    nombre: 'Pastilla de freno',
    precioCompra: 30000,
    precioVenta: 45000,
    stockActual: 0,
    stockMinimo: 2,
    aplicaIva: false,
    activo: true,
  ),
];

Widget _envolver(Widget hijo) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 900, height: 700, child: hijo)),
    );

void main() {
  testWidgets('la ubicación en bodega aparece debajo del stock', (tester) async {
    await tester.pumpWidget(
      _envolver(
        GrillaProductosCatalogo(
          productos: _productos,
          etiquetaAgregar: 'Agregar',
          alAgregar: (_) {},
        ),
      ),
    );

    expect(find.text('Estante A-3'), findsOneWidget);

    final stock = tester.getTopLeft(find.text('12 en stock')).dy;
    final ubicacion = tester.getTopLeft(find.text('Estante A-3')).dy;
    expect(ubicacion, greaterThan(stock));
  });

  testWidgets('en el mostrador el agotado se ve pero no se agrega',
      (tester) async {
    final agregados = <String>[];

    await tester.pumpWidget(
      _envolver(
        GrillaProductosCatalogo(
          productos: _productos,
          etiquetaAgregar: 'Agregar a la venta',
          bloquearSinStock: true,
          alAgregar: (p) => agregados.add(p.sku),
        ),
      ),
    );

    expect(find.text('Agotado'), findsOneWidget);

    await tester.tap(find.text('Pastilla de freno'));
    await tester.pump();
    expect(agregados, isEmpty, reason: 'lo que no está en bodega no se vende');

    await tester.tap(find.text('Aceite Motul 20W50'));
    await tester.pump();
    expect(agregados, ['SKU-1123']);
  });

  testWidgets('en una cotización o una orden el agotado sí se agrega',
      (tester) async {
    final agregados = <String>[];

    await tester.pumpWidget(
      _envolver(
        GrillaProductosCatalogo(
          productos: _productos,
          etiquetaAgregar: 'Agregar a la orden',
          alAgregar: (p) => agregados.add(p.sku),
        ),
      ),
    );

    // Cotizar o anotar en una orden lo que hay que pedirle al proveedor es
    // parte del trabajo: el color avisa, pero no bloquea.
    expect(find.text('Sin stock · hay que pedirlo'), findsOneWidget);

    await tester.tap(find.text('Pastilla de freno'));
    await tester.pump();
    expect(agregados, ['SKU-1201']);
  });

  testWidgets('con la orden cerrada ninguna tarjeta agrega', (tester) async {
    final agregados = <String>[];

    await tester.pumpWidget(
      _envolver(
        GrillaProductosCatalogo(
          productos: _productos,
          etiquetaAgregar: 'Agregar a la orden',
          habilitado: false,
          alAgregar: (p) => agregados.add(p.sku),
        ),
      ),
    );

    await tester.tap(find.text('Aceite Motul 20W50'));
    await tester.pump();
    expect(agregados, isEmpty);
  });
}
