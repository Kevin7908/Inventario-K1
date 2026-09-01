// La ficha de una remisión: qué se puede tocar y qué no.
//
// Una compra anulada se lee pero no se edita —su mercancía ya salió del
// inventario—, y la línea es la del editor de órdenes con el signo cambiado:
// aquí el precio que se teclea es el **costo**, que es el dato que el módulo
// existe para guardar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/compras/enum/enum_compras.dart';
import 'package:inventario_k1/backend/features/compras/modelo/compra_item.dart';
import 'package:inventario_k1/frontend/features/compras/compra_detalle/modelo/compra_editor_state.dart';
import 'package:inventario_k1/frontend/features/compras/compra_detalle/widgets/linea_compra.dart';
import 'package:inventario_k1/frontend/share/share.dart';

CompraItem _item({
  int id = 1,
  double cantidad = 12,
  int costo = 6500,
}) =>
    CompraItem(
      id: id,
      compraId: 7,
      productoId: 3,
      descripcion: 'Pastilla de freno',
      sku: 'FRE-1123',
      cantidad: cantidad,
      costoUnitario: costo,
    );

CompraEditorState _estado({
  EstadoCompra estado = EstadoCompra.registrada,
  List<CompraItem> lineas = const [],
}) =>
    CompraEditorState(
      compraId: 7,
      numero: 'COM-2026-0007',
      proveedorId: 2,
      proveedorNombre: 'Repuestos JR',
      fecha: DateTime(2026, 8, 31),
      estado: estado,
      total: 78000,
      lineas: lineas,
    );

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(width: 360, child: child),
          ),
        ),
      ),
    );

void main() {
  group('CompraEditorState', () {
    test('una remisión registrada se puede seguir anotando', () {
      expect(_estado().editable, isTrue);
    });

    test('una anulada se lee pero no se toca', () {
      // Su mercancía ya salió del inventario: cambiarle una línea movería
      // stock por una entrada que se deshizo.
      expect(_estado(estado: EstadoCompra.anulada).editable, isFalse);
    });

    test('cuenta las unidades recibidas, no las líneas', () {
      final estado = _estado(
        lineas: [_item(cantidad: 12), _item(id: 2, cantidad: 3)],
      );

      expect(estado.unidades, 15);
      expect(estado.lineas, hasLength(2));
    });

    test('el catálogo del panel no esconde los productos inactivos', () {
      // Al revés que en ventas y fiados: el proveedor manda lo que manda, y
      // un producto dado de baja hay que poder recibirlo para cuadrar.
      expect(_estado().filtroProductos.soloActivos, isFalse);
    });

    test('conLinea reemplaza conservando el orden', () {
      final estado = _estado(lineas: [_item(), _item(id: 2, cantidad: 3)]);

      final cambiado = estado.conLinea(_item(cantidad: 20));

      expect(cambiado.lineas.first.cantidad, 20);
      expect(cambiado.lineas.last.id, 2);
    });
  });

  group('LineaCompra', () {
    testWidgets('muestra el producto, su SKU y lo que suma', (tester) async {
      await _pump(
        tester,
        LineaCompra(
          descripcion: 'Pastilla de freno',
          sku: 'FRE-1123',
          cantidad: 12,
          costoUnitario: 6500,
          alCambiarCantidad: (_) {},
          alCambiarCosto: (_) {},
          alEliminar: () {},
        ),
      );

      expect(find.text('Pastilla de freno'), findsOneWidget);
      // El parcial va al lado del SKU: al teclear costos uno por uno, verlo
      // evita tener que sumar de cabeza.
      expect(find.text(r'FRE-1123 · $78.000'), findsOneWidget);
    });

    testWidgets('el − con cantidad 1 quita la línea', (tester) async {
      var quitada = false;
      final cantidades = <double>[];
      await _pump(
        tester,
        LineaCompra(
          descripcion: 'Pastilla de freno',
          sku: 'FRE-1123',
          cantidad: 1,
          costoUnitario: 6500,
          alCambiarCantidad: cantidades.add,
          alCambiarCosto: (_) {},
          alEliminar: () => quitada = true,
        ),
      );

      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();

      expect(quitada, isTrue);
      expect(cantidades, isEmpty);
    });

    testWidgets('en una compra anulada el costo se ve pero no se teclea',
        (tester) async {
      await _pump(
        tester,
        LineaCompra(
          descripcion: 'Pastilla de freno',
          sku: 'FRE-1123',
          cantidad: 12,
          costoUnitario: 6500,
          editable: false,
          alCambiarCantidad: (_) {},
          alCambiarCosto: (_) {},
          alEliminar: () {},
        ),
      );

      // El costo pasa a ser texto: el campo tecleable desaparece. (El de la
      // cantidad sigue en pantalla, apagado por `ControlCantidad`.)
      expect(find.text(r'$6.500'), findsOneWidget);
      expect(find.byType(CampoPrecioLinea), findsNothing);
    });
  });
}
