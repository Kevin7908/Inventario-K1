// Aritmética del carrito del punto de venta: stock como tope, descuento
// recortado y base gravable ya rebajada.
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';
import 'package:inventario_k1/core/iva_app.dart';
import 'package:inventario_k1/frontend/features/pos/modelo/pos_state.dart';

Producto _producto({
  int id = 1,
  String nombre = 'Pastilla de freno',
  int precioVenta = 32000,
  double stockActual = 10,
}) =>
    Producto(
      id: id,
      sku: 'SKU-$id',
      nombre: nombre,
      precioCompra: 20000,
      precioVenta: precioVenta,
      stockActual: stockActual,
      stockMinimo: 2,
      aplicaIva: false,
      activo: true,
    );

void main() {
  group('carrito', () {
    test('agregar dos veces el mismo producto suma cantidad, no duplica', () {
      final producto = _producto();
      final estado =
          const PosState().conProducto(producto).conProducto(producto);

      expect(estado.items, hasLength(1));
      expect(estado.items.single.cantidad, 2);
      expect(estado.unidades, 2);
    });

    test('un producto agotado no entra al carrito', () {
      final estado = const PosState().conProducto(_producto(stockActual: 0));

      expect(estado.items, isEmpty);
    });

    test('la cantidad se recorta al stock disponible', () {
      final estado = const PosState()
          .conProducto(_producto(stockActual: 8))
          .conCantidad(0, 50);

      expect(estado.items.single.cantidad, 8);
    });

    test('cantidad 0 quita la línea', () {
      final estado =
          const PosState().conProducto(_producto()).conCantidad(0, 0);

      expect(estado.items, isEmpty);
    });

    test('el precio se congela al agregar, aunque cambie el del catálogo', () {
      final estado = const PosState().conProducto(_producto(precioVenta: 32000));
      // El mismo producto, ya con otro precio en el catálogo.
      final conNuevoPrecio =
          estado.conProducto(_producto(precioVenta: 99000));

      expect(conNuevoPrecio.items.single.precioUnitario, 32000);
      expect(conNuevoPrecio.subtotal, 64000);
    });
  });

  group('descuento', () {
    test('no puede superar el subtotal', () {
      final estado = const PosState()
          .conProducto(_producto(precioVenta: 10000))
          .conDescuento(50000);

      expect(estado.descuento, 10000);
      expect(estado.total, 0);
    });

    test('un descuento negativo queda en cero', () {
      final estado =
          const PosState().conProducto(_producto()).conDescuento(-500);

      expect(estado.descuento, 0);
    });

    test('se recorta al vaciarse el carrito por debajo del descuento', () {
      final estado = const PosState()
          .conProducto(_producto(id: 1, precioVenta: 30000))
          .conProducto(_producto(id: 2, precioVenta: 20000))
          .conDescuento(45000);

      expect(estado.descuento, 45000);

      // Al quitar la línea de 30.000 quedan 20.000 por cobrar: un descuento de
      // 45.000 dejaría el total en negativo.
      final conUnaLinea = estado.sinLinea(0);

      expect(conUnaLinea.subtotal, 20000);
      expect(conUnaLinea.descuento, 20000);
      expect(conUnaLinea.total, 0);
    });

    test('el descuento sale del precio con IVA: el total no le suma nada', () {
      final estado = const PosState()
          .conProducto(_producto(precioVenta: 100000))
          .conDescuento(20000);

      // Los precios ya traen el IVA dentro, así que rebajar 20.000 rebaja
      // exactamente eso de lo que paga el cliente. Antes el descuento salía de
      // una base imponible y con IVA al 19% le quitaba 23.800.
      expect(estado.total, 80000);
      expect(estado.iva, ivaIncluidoEn(80000),
          reason: 'el IVA se extrae del total, no se suma');
    });
  });
}
