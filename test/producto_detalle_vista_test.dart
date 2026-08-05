// Regresión de layout de la ficha de producto.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';
import 'package:inventario_k1/frontend/features/productos/vista/producto_detalle_vista.dart';

const _producto = Producto(
  id: 1,
  sku: 'FRE-001',
  nombre: 'Pastillas de freno delanteras',
  descripcion: 'Juego de pastillas para disco delantero.',
  categoriaId: 1,
  categoriaNombre: 'Frenos',
  unidadMedidaNombre: 'und',
  proveedorNombre: 'Repuestos del Valle',
  precioCompra: 18000,
  precioVenta: 28000,
  stockActual: 12,
  stockMinimo: 4,
  ubicacionBodega: 'Estante A-3',
  aplicaIva: true,
  activo: true,
);

Future<void> _pumpFicha(WidgetTester tester, Size tamano) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(body: ProductoDetalleVista(producto: _producto)),
    ),
  );
}

void main() {
  // La ficha vive dentro de un SingleChildScrollView, así que no tiene alto
  // acotado: un hijo que estire a lo alto sin límite tumba el layout con
  // "BoxConstraints forces an infinite height" y la pantalla queda en blanco.
  testWidgets('la ficha se compone en ventana ancha sin romper el layout',
      (tester) async {
    await _pumpFicha(tester, const Size(1400, 1000));

    expect(tester.takeException(), isNull);
    expect(find.text('Pastillas de freno delanteras'), findsOneWidget);
    expect(find.text('Stock disponible'), findsOneWidget);
    expect(find.text('Unidad de medida'), findsOneWidget);
  });

  testWidgets('la ficha se compone en ventana angosta sin romper el layout',
      (tester) async {
    // Por debajo de 900 la ficha pasa a una sola columna.
    await _pumpFicha(tester, const Size(760, 1000));

    expect(tester.takeException(), isNull);
    expect(find.text('Stock mínimo'), findsOneWidget);
    expect(find.text('Ubicación'), findsOneWidget);
  });
}
