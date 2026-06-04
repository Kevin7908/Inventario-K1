import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';

void main() {
  group('Pruebas Unitarias - Modelo Producto', () {
    test('Debe calcular correctamente el precio con IVA (19%)', () {
      const producto = Producto(
        sku: 'TEST-01',
        nombre: 'Teclado',
        precioCompra: 100,
        precioVenta: 200,
        stockActual: 10,
        stockMinimo: 5,
        aplicaIva: true,
        activo: true,
      );
      // 200 * 1.19 = 238
      expect(producto.precioVentaConIva, 238.0);
    });

    test('Debe retornar el precio original si no aplica IVA', () {
      const producto = Producto(
        sku: 'TEST-01',
        nombre: 'Teclado',
        precioCompra: 100,
        precioVenta: 200,
        stockActual: 10,
        stockMinimo: 5,
        aplicaIva: false,
        activo: true,
      );
      expect(producto.precioVentaConIva, 200.0);
    });

    test('Debe calcular el margen de ganancia correctamente', () {
      const producto = Producto(
        sku: 'TEST-01',
        nombre: 'Mouse',
        precioCompra: 50,
        precioVenta: 75,
        stockActual: 10,
        stockMinimo: 5,
        aplicaIva: false,
        activo: true,
      );
      // ((75-50)/50) * 100 = 50%
      expect(producto.margenGanancia, 50.0);
    });

    test(
      'Debe identificar correctamente el estado de stock (Bajo, Sin Stock, En Stock)',
      () {
        const base = Producto(
          sku: 'T',
          nombre: 'P',
          precioCompra: 1,
          precioVenta: 2,
          stockActual: 0,
          stockMinimo: 5,
          aplicaIva: false,
          activo: true,
        );

        final p1 = base.copyWith(stockActual: 0);
        final p2 = base.copyWith(stockActual: 3); // Menor al minimo (5)
        final p3 = base.copyWith(stockActual: 10);

        expect(p1.estadoStock, EstadoStock.sinStock);
        expect(p2.estadoStock, EstadoStock.stockBajo);
        expect(p3.estadoStock, EstadoStock.enStock);
      },
    );

    test('Debe verificar la igualdad de objetos con Equatable (Props)', () {
      const p1 = Producto(
        sku: 'A',
        nombre: 'Prod',
        precioCompra: 1,
        precioVenta: 1,
        stockActual: 1,
        stockMinimo: 1,
        aplicaIva: true,
        activo: true,
      );
      const p2 = Producto(
        sku: 'A',
        nombre: 'Prod',
        precioCompra: 1,
        precioVenta: 1,
        stockActual: 1,
        stockMinimo: 1,
        aplicaIva: true,
        activo: true,
      );

      expect(p1, equals(p2)); // Son idénticos en valores
    });
  });

  test('Debe fallar cuando el precio de venta es menor al de compra', () {
    const p = Producto(
      sku: 'A',
      nombre: 'Producto prueba',
      precioCompra: 100,
      precioVenta: 80,
      stockActual: 10,
      stockMinimo: 5,
      aplicaIva: false,
      activo: true,
    );

    expect(p.precioVenta >= p.precioCompra, isTrue);
  });

  // TEST 7: Copia de objeto (copyWith)
  test('copyWith debe crear una nueva instancia con valores actualizados', () {
    const p = Producto(
      sku: 'A',
      nombre: 'Original',
      precioCompra: 1,
      precioVenta: 1,
      stockActual: 1,
      stockMinimo: 1,
      aplicaIva: false,
      activo: true,
    );
    final actualizado = p.copyWith(nombre: 'Editado');
    expect(actualizado.nombre, 'Editado');
    expect(actualizado.sku, 'A'); // Mantiene el resto igual
  });
}
