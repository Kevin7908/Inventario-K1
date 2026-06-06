// Pruebas Unitarias — Módulo Maestro (Productos)
//
// Cómo ejecutar desde la raíz del proyecto Flutter:
//   flutter test pruebas-quintero-barrera/02-pruebas-unitarias/src/test/dart/productos/productos_test.dart
//
// Dependencias necesarias (ya en pubspec.yaml):
//   - equatable: ^2.0.8
//   - flutter_test (dev_dependency del SDK de Flutter)

import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';

// Producto base reutilizable en varios tests
const _base = Producto(
  sku: 'TEST-01',
  nombre: 'Filtro de Aceite',
  precioCompra: 50.0,
  precioVenta: 75.0,
  stockActual: 10.0,
  stockMinimo: 5.0,
  aplicaIva: false,
  activo: true,
);

void main() {
  // =========================================================================
  // GROUP 1: Cálculo de precio con IVA
  // Valida el getter precioVentaConIva (kTasaIva = 0.19)
  // =========================================================================
  group('Cálculo de precio con IVA', () {
    test(
      'UT-PR-01: Precio con IVA = precioVenta × 1.19 cuando aplicaIva es true',
      () {
        const producto = Producto(
          sku: 'IVA-01',
          nombre: 'Aceite Mineral',
          precioCompra: 100.0,
          precioVenta: 200.0,
          stockActual: 10.0,
          stockMinimo: 5.0,
          aplicaIva: true,
          activo: true,
        );
        // 200 × 1.19 = 238.0
        expect(producto.precioVentaConIva, equals(238.0));
      },
    );

    test(
      'UT-PR-02: Precio con IVA = precioVenta original cuando aplicaIva es false',
      () {
        const producto = Producto(
          sku: 'NO-IVA-01',
          nombre: 'Llanta',
          precioCompra: 80.0,
          precioVenta: 120.0,
          stockActual: 5.0,
          stockMinimo: 2.0,
          aplicaIva: false,
          activo: true,
        );
        expect(producto.precioVentaConIva, equals(120.0));
      },
    );
  });

  // =========================================================================
  // GROUP 2: Margen de ganancia
  // Valida el getter margenGanancia = ((venta - compra) / compra) × 100
  // =========================================================================
  group('Margen de ganancia', () {
    test(
      'UT-PR-03: Margen del 50% cuando compra=50 y venta=75',
      () {
        // ((75 - 50) / 50) × 100 = 50.0
        expect(_base.margenGanancia, equals(50.0));
      },
    );

    test(
      'UT-PR-04: Margen es 0 cuando precioCompra es 0 (evita división por cero)',
      () {
        final producto = _base.copyWith(precioCompra: 0, precioVenta: 100);
        expect(producto.margenGanancia, equals(0.0));
      },
    );

    test(
      'UT-PR-05: El modelo acepta precioVenta < precioCompra (margen negativo) — FALLA: BUG-001',
      () {
        final producto = _base.copyWith(precioCompra: 100, precioVenta: 80);
        // El modelo NO tiene validación; precioVenta < precioCompra es posible.
        // Esta prueba documenta el BUG-001: no hay restricción en el modelo.
        // Resultado esperado según regla de negocio: precioVenta >= precioCompra
        // Resultado real: el modelo lo permite → el test FALLA
        expect(
          producto.precioVenta >= producto.precioCompra,
          isTrue,
          reason: 'BUG-001: El modelo Producto no valida que precioVenta >= precioCompra',
        );
      },
    );
  });

  // =========================================================================
  // GROUP 3: Estado de stock
  // Valida el getter estadoStock y sus alias booleanos
  // =========================================================================
  group('Estado de stock', () {
    test(
      'UT-PR-06: estadoStock es sinStock cuando stockActual <= 0',
      () {
        final p = _base.copyWith(stockActual: 0);
        expect(p.estadoStock, equals(EstadoStock.sinStock));
        expect(p.sinStock, isTrue);
      },
    );

    test(
      'UT-PR-07: estadoStock es stockBajo cuando 0 < stockActual <= stockMinimo',
      () {
        final p = _base.copyWith(stockActual: 3, stockMinimo: 5);
        expect(p.estadoStock, equals(EstadoStock.stockBajo));
        expect(p.tieneStockBajo, isTrue);
      },
    );

    test(
      'UT-PR-08: estadoStock es enStock cuando stockActual > stockMinimo',
      () {
        final p = _base.copyWith(stockActual: 10, stockMinimo: 5);
        expect(p.estadoStock, equals(EstadoStock.enStock));
        expect(p.sinStock, isFalse);
        expect(p.tieneStockBajo, isFalse);
      },
    );
  });

  // =========================================================================
  // GROUP 4: Identidad y copia (Equatable + copyWith)
  // =========================================================================
  group('Identidad de objeto y copyWith', () {
    test(
      'UT-PR-09: Dos instancias con los mismos valores son iguales (Equatable)',
      () {
        const p1 = Producto(
          sku: 'EQ-01',
          nombre: 'Bujía',
          precioCompra: 10.0,
          precioVenta: 20.0,
          stockActual: 5.0,
          stockMinimo: 2.0,
          aplicaIva: false,
          activo: true,
        );
        const p2 = Producto(
          sku: 'EQ-01',
          nombre: 'Bujía',
          precioCompra: 10.0,
          precioVenta: 20.0,
          stockActual: 5.0,
          stockMinimo: 2.0,
          aplicaIva: false,
          activo: true,
        );
        expect(p1, equals(p2));
      },
    );

    test(
      'UT-PR-10: copyWith crea nueva instancia con el campo actualizado',
      () {
        final actualizado = _base.copyWith(nombre: 'Filtro Premium', precioVenta: 90.0);

        expect(actualizado.nombre, equals('Filtro Premium'));
        expect(actualizado.precioVenta, equals(90.0));
        // Los campos no especificados se conservan
        expect(actualizado.sku, equals(_base.sku));
        expect(actualizado.precioCompra, equals(_base.precioCompra));
      },
    );
  });
}
