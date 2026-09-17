// Un repuesto se le compra a varios proveedores.
//
// Antes era `productos.proveedor_id`, una sola columna: cada remisión pisaba
// el costo de la anterior y «¿quién me lo vende más barato?» no estaba en
// ninguna parte. Ahora la relación vive en `producto_proveedores` con el
// último costo de cada uno.
//
// Lo que se fija aquí:
//
// - que la lista sea la lista, con el principal de primero;
// - que **no pueda haber dos principales**, y que eso lo garantice la base y
//   no la disciplina del repositorio;
// - que una remisión anote a cómo lo dejó ese proveedor, y vincule si es la
//   primera vez, sin ascenderlo a principal por comprarle una vez.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/compras/repositorio/repositorio_compras_impl.dart';
import 'package:inventario_k1/backend/features/compras/resultado/resultado_compra.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';
import 'package:inventario_k1/backend/features/productos/repositorio/repositorio_producto_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/backend/share/dominio/sesion_actual.dart';
import 'package:inventario_k1/core/resultado.dart';

import 'soporte/base_en_memoria.dart';
import 'soporte/sesion_de_prueba.dart';

late AppDb db;
late SesionActual sesion;
late RepositorioProductosImpl productos;
late RepositorioComprasImpl compras;

/// Un proveedor con su persona detrás: el nombre vive en `personas`.
Future<int> _proveedor(String nombre) async {
  final personaId = await db
      .into(db.tablaPersona)
      .insert(TablaPersonaCompanion.insert(nombres: nombre));
  return db
      .into(db.tablaProveedor)
      .insert(TablaProveedorCompanion.insert(personaId: personaId));
}

Future<Producto> _producto({int? proveedorId}) => productos.crear(
      Producto(
        nombre: 'Pastilla de freno',
        sku: 'FRE-0012',
        proveedorId: proveedorId,
        precioCompra: 15000,
        precioVenta: 28000,
        stockActual: 0,
        stockMinimo: 2,
        activo: true,
      ),
    );

void main() {
  setUp(() async {
    db = baseEnMemoria();
    sesion = await sesionDePrueba(db);
    productos = RepositorioProductosImpl(db, sesion);
    compras = RepositorioComprasImpl(db, sesion);
  });

  tearDown(() => db.close());

  group('la lista de proveedores', () {
    test('un repuesto admite varios y el principal va primero', () async {
      final jr = await _proveedor('Repuestos JR');
      final ana = await _proveedor('Almacén Ana');
      final producto = await _producto(proveedorId: jr);

      await productos.vincularProveedor(
        productoId: producto.id!,
        proveedorId: ana,
        referenciaProveedor: 'A-778',
      );

      final lista =
          await productos.observarProveedoresDe(producto.id!).first;

      expect(lista.map((p) => p.proveedorNombre),
          ['Repuestos JR', 'Almacén Ana']);
      expect(lista.first.esPrincipal, isTrue);
      expect(lista.last.esPrincipal, isFalse);
      expect(lista.last.referenciaProveedor, 'A-778');
    });

    test('el proveedor del formulario queda como principal', () async {
      // El formulario sigue teniendo un solo selector: lo que elija es el
      // principal, y el repositorio lo traduce al vínculo.
      final jr = await _proveedor('Repuestos JR');
      final producto = await _producto(proveedorId: jr);

      final lista =
          await productos.observarProveedoresDe(producto.id!).first;
      expect(lista.single.proveedorId, jr);
      expect(lista.single.esPrincipal, isTrue);
    });

    test('la rejilla sigue viendo el principal del producto', () async {
      final jr = await _proveedor('Repuestos JR');
      final producto = await _producto(proveedorId: jr);

      final leido = await productos.obtenerPorId(producto.id!);
      expect(leido!.proveedorId, jr);
      expect(leido.proveedorNombre, 'Repuestos JR');
    });

    test('un producto sin proveedor sigue apareciendo en el catálogo',
        () async {
      // El JOIN del principal es `LEFT` y su condición va en el ON, no en un
      // WHERE: en un WHERE dejaría fuera justo a estos.
      await _producto();
      final todos = await productos.obtenerTodos();
      expect(todos, hasLength(1));
      expect(todos.single.proveedorId, isNull);
    });

    test('quitar un proveedor no borra las compras que trajo', () async {
      final jr = await _proveedor('Repuestos JR');
      final producto = await _producto(proveedorId: jr);

      await productos.desvincularProveedor(
        productoId: producto.id!,
        proveedorId: jr,
      );

      expect(await productos.observarProveedoresDe(producto.id!).first,
          isEmpty);
    });
  });

  group('el principal es uno solo', () {
    test('marcar uno apaga al anterior', () async {
      final jr = await _proveedor('Repuestos JR');
      final ana = await _proveedor('Almacén Ana');
      final producto = await _producto(proveedorId: jr);
      await productos.vincularProveedor(
        productoId: producto.id!,
        proveedorId: ana,
      );

      await productos.fijarProveedorPrincipal(
        productoId: producto.id!,
        proveedorId: ana,
      );

      final lista =
          await productos.observarProveedoresDe(producto.id!).first;
      expect(lista.where((p) => p.esPrincipal).map((p) => p.proveedorId),
          [ana]);
    });

    test('la base rechaza dos principales, no solo el repositorio', () async {
      // La guarda es la garantía: un método nuevo que se olvide de apagar el
      // anterior tiene que reventar, no dejar dos marcados.
      final jr = await _proveedor('Repuestos JR');
      final ana = await _proveedor('Almacén Ana');
      final producto = await _producto(proveedorId: jr);

      await expectLater(
        db.into(db.tablaProductoProveedor).insert(
              TablaProductoProveedorCompanion.insert(
                productoId: producto.id!,
                proveedorId: ana,
                esPrincipal: const Value(true),
              ),
            ),
        throwsA(anything),
      );
    });

    test('un repuesto puede quedarse sin principal', () async {
      // Hay piezas que se le compran a quien las tenga.
      final jr = await _proveedor('Repuestos JR');
      final producto = await _producto(proveedorId: jr);

      await productos.fijarProveedorPrincipal(
        productoId: producto.id!,
        proveedorId: null,
      );

      final lista =
          await productos.observarProveedoresDe(producto.id!).first;
      expect(lista.single.esPrincipal, isFalse,
          reason: 'el vínculo se queda; lo que se quita es la corona');
    });

    test('marcar a alguien que no está entre los suyos se rechaza', () async {
      final jr = await _proveedor('Repuestos JR');
      final ajeno = await _proveedor('Otro almacén');
      final producto = await _producto(proveedorId: jr);

      final resultado = await productos.fijarProveedorPrincipal(
        productoId: producto.id!,
        proveedorId: ajeno,
      );

      expect(resultado, isA<Fallo>());
    });
  });

  group('la remisión anota a cómo lo dejó cada uno', () {
    test('la compra guarda el costo de ese proveedor y lo vincula', () async {
      final jr = await _proveedor('Repuestos JR');
      final producto = await _producto();

      final compra = await compras.crear(proveedorId: jr) as CompraAbierta;
      await compras.agregarLinea(
        compraId: compra.compraId,
        productoId: producto.id!,
        cantidad: 10,
        costoUnitario: 17500,
      );

      final lista =
          await productos.observarProveedoresDe(producto.id!).first;

      expect(lista.single.proveedorId, jr);
      expect(lista.single.ultimoCosto, 17500);
      expect(lista.single.tieneCompras, isTrue);
      expect(lista.single.esPrincipal, isFalse,
          reason: 'comprarle una vez no lo hace el proveedor de cabecera');
    });

    test('dos proveedores conservan cada uno su costo', () async {
      // Es la razón de ser de la tabla: con la columna única, la segunda
      // remisión borraba el precio de la primera y no quedaba con qué
      // comparar.
      final jr = await _proveedor('Repuestos JR');
      final ana = await _proveedor('Almacén Ana');
      final producto = await _producto();

      final unaCompra =
          await compras.crear(proveedorId: jr) as CompraAbierta;
      await compras.agregarLinea(
        compraId: unaCompra.compraId,
        productoId: producto.id!,
        cantidad: 10,
        costoUnitario: 17500,
      );

      final otraCompra =
          await compras.crear(proveedorId: ana) as CompraAbierta;
      await compras.agregarLinea(
        compraId: otraCompra.compraId,
        productoId: producto.id!,
        cantidad: 10,
        costoUnitario: 15900,
      );

      final costos = {
        for (final p in await productos.observarProveedoresDe(producto.id!).first)
          p.proveedorNombre: p.ultimoCosto,
      };

      expect(costos, {'Repuestos JR': 17500, 'Almacén Ana': 15900});
    });
  });
}
