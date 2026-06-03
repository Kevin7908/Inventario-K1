// Pruebas de Repositorio — Módulo Maestro (RepositorioProductosImpl)
// Equivalente a colección Postman: prueba la CAPA DE DATOS real con BD en memoria
//
// Cómo ejecutar desde la raíz del proyecto Flutter:
//   flutter test pruebas-quintero-barrera/04-pruebas-repositorio/repositorio_productos_test.dart
//
// Dependencias necesarias (ya en pubspec.yaml):
//   - drift: ^2.32.1
//   - flutter_test

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';
import 'package:inventario_k1/backend/features/productos/repositorio/repositorio_producto_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

// Producto base para reutilizar en varios tests
const _productoBase = Producto(
  sku: 'REPO-001',
  nombre: 'Aceite Mineral 20W50',
  descripcion: 'Aceite para motor de moto',
  precioCompra: 35.0,
  precioVenta: 55.0,
  stockActual: 20.0,
  stockMinimo: 5.0,
  aplicaIva: false,
  activo: true,
);

void main() {
  late AppDb db;
  late RepositorioProductosImpl repo;

  setUp(() {
    db = AppDb(NativeDatabase.memory());
    repo = RepositorioProductosImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ===========================================================================
  // GROUP 1: crear
  // Equivalente a: POST /api/productos en Postman
  // ===========================================================================
  group('REP-PROD — crear', () {
    test(
      'RP-PR-01: Crear producto válido retorna el producto con id asignado',
      () async {
        final creado = await repo.crear(_productoBase);

        expect(creado.id, isNotNull);
        expect(creado.sku, equals('REPO-001'));
        expect(creado.nombre, equals('Aceite Mineral 20W50'));
        expect(creado.precioVenta, equals(55.0));
        expect(creado.stockActual, equals(20.0));
      },
    );

    test(
      'RP-PR-02: Crear dos productos con distinto SKU es exitoso',
      () async {
        await repo.crear(_productoBase);
        final segundo = await repo.crear(
          _productoBase.copyWith(
            sku: 'REPO-002',
            nombre: 'Filtro de Aire',
            precioCompra: 12.0,
            precioVenta: 25.0,
          ),
        );

        expect(segundo.id, isNotNull);
        expect(segundo.sku, equals('REPO-002'));
      },
    );
  });

  // ===========================================================================
  // GROUP 2: obtenerTodos / obtenerPorId / obtenerPorSku
  // Equivalente a: GET /api/productos y GET /api/productos/{id} en Postman
  // ===========================================================================
  group('REP-PROD — consultas', () {
    test(
      'RP-PR-03: obtenerTodos retorna lista vacía cuando no hay productos',
      () async {
        final lista = await repo.obtenerTodos();
        expect(lista, isEmpty);
      },
    );

    test(
      'RP-PR-04: obtenerTodos retorna todos los productos creados',
      () async {
        await repo.crear(_productoBase);
        await repo.crear(_productoBase.copyWith(sku: 'REPO-002', nombre: 'Bujía NGK'));

        final lista = await repo.obtenerTodos();
        expect(lista.length, equals(2));
      },
    );

    test(
      'RP-PR-05: obtenerPorId retorna el producto correcto',
      () async {
        final creado = await repo.crear(_productoBase);
        final encontrado = await repo.obtenerPorId(creado.id!);

        expect(encontrado, isNotNull);
        expect(encontrado!.sku, equals('REPO-001'));
      },
    );

    test(
      'RP-PR-06: obtenerPorId retorna null para id inexistente',
      () async {
        final resultado = await repo.obtenerPorId(9999);
        expect(resultado, isNull);
      },
    );

    test(
      'RP-PR-07: existeSku retorna true para SKU ya registrado',
      () async {
        await repo.crear(_productoBase);
        final existe = await repo.existeSku('REPO-001');
        expect(existe, isTrue);
      },
    );

    test(
      'RP-PR-08: existeSku retorna false para SKU no registrado',
      () async {
        final existe = await repo.existeSku('NO-EXISTE-SKU');
        expect(existe, isFalse);
      },
    );
  });

  // ===========================================================================
  // GROUP 3: actualizar
  // Equivalente a: PUT /api/productos/{id} en Postman
  // ===========================================================================
  group('REP-PROD — actualizar', () {
    test(
      'RP-PR-09: Actualizar precio de venta se refleja en la BD',
      () async {
        final creado = await repo.crear(_productoBase);
        final modificado = creado.copyWith(precioVenta: 70.0, descripcion: 'Actualizado');

        final actualizado = await repo.actualizar(modificado);

        expect(actualizado.precioVenta, equals(70.0));
        expect(actualizado.descripcion, equals('Actualizado'));
        // El SKU no debe cambiar
        expect(actualizado.sku, equals('REPO-001'));
      },
    );
  });

  // ===========================================================================
  // GROUP 4: ajustarStock
  // Equivalente a: PATCH /api/productos/{id}/stock en Postman
  // ===========================================================================
  group('REP-PROD — ajustarStock', () {
    test(
      'RP-PR-10: Agregar stock incrementa stockActual correctamente',
      () async {
        final creado = await repo.crear(_productoBase); // stock = 20
        final conMasStock = await repo.ajustarStock(creado.id!, 10.0);

        expect(conMasStock.stockActual, equals(30.0));
      },
    );

    test(
      'RP-PR-11: Restar stock reduce stockActual correctamente',
      () async {
        final creado = await repo.crear(_productoBase); // stock = 20
        final conMenosStock = await repo.ajustarStock(creado.id!, -5.0);

        expect(conMenosStock.stockActual, equals(15.0));
      },
    );

    test(
      'RP-PR-12: Restar más del stock disponible resulta en stock negativo — BUG-003',
      () async {
        final creado = await repo.crear(_productoBase); // stock = 20
        // El repositorio no bloquea stock negativo (BUG-003)
        final resultado = await repo.ajustarStock(creado.id!, -25.0); // stock > disponible

        // Resultado real: stock = -5.0 (no hay validación)
        // Resultado esperado según negocio: error o stock = 0
        expect(
          resultado.stockActual,
          isNegative,
          reason: 'BUG-003: ajustarStock permite stock negativo sin validación',
        );
      },
    );
  });

  // ===========================================================================
  // GROUP 5: eliminar
  // Equivalente a: DELETE /api/productos/{id} en Postman
  // ===========================================================================
  group('REP-PROD — eliminar', () {
    test(
      'RP-PR-13: Eliminar producto existente lo remueve de la BD',
      () async {
        final creado = await repo.crear(_productoBase);
        await repo.eliminar(creado.id!);

        final buscado = await repo.obtenerPorId(creado.id!);
        expect(buscado, isNull);
      },
    );

    test(
      'RP-PR-14: contarActivos refleja el total correcto después de crear y eliminar',
      () async {
        final p1 = await repo.crear(_productoBase);
        await repo.crear(_productoBase.copyWith(sku: 'REPO-002', nombre: 'Segundo'));

        expect(await repo.contarActivos(), equals(2));

        await repo.eliminar(p1.id!);
        expect(await repo.contarActivos(), equals(1));
      },
    );
  });

  // ===========================================================================
  // GROUP 6: obtenerConStockBajo
  // ===========================================================================
  group('REP-PROD — stock bajo', () {
    test(
      'RP-PR-15: obtenerConStockBajo retorna solo productos bajo el mínimo',
      () async {
        await repo.crear(_productoBase.copyWith(
          sku: 'BAJO-001',
          nombre: 'Producto Stock Bajo',
          stockActual: 2.0, // < stockMinimo (5)
        ));
        await repo.crear(_productoBase.copyWith(
          sku: 'NORMAL-001',
          nombre: 'Producto Stock Normal',
          stockActual: 20.0, // > stockMinimo (5)
        ));

        final bajos = await repo.obtenerConStockBajo();

        expect(bajos.length, equals(1));
        expect(bajos.first.sku, equals('BAJO-001'));
      },
    );
  });
}
