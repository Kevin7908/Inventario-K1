// El SKU se autogenera y no se teclea.
//
// Lo que fijan estos tests es lo que la vista no puede garantizar:
//
// - el prefijo sale del nombre de la categoría, y dos categorías que empiezan
//   igual se separan alargando la segunda;
// - dos altas seguidas de la misma categoría **no** comparten código;
// - la previsualización no consume número, así que abrir el formulario y
//   arrepentirse no deja un hueco en la estantería;
// - un alta que falla devuelve el número a la serie.
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';
import 'package:inventario_k1/backend/features/productos/repositorio/repositorio_producto_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/backend/share/dominio/sesion_actual.dart';

import 'soporte/base_en_memoria.dart';
import 'soporte/sesion_de_prueba.dart';

late AppDb db;
late SesionActual sesion;
late RepositorioProductosImpl productos;

Producto _producto({String nombre = 'Aceite 20W50', int? categoriaId}) =>
    Producto(
      sku: '',
      nombre: nombre,
      categoriaId: categoriaId,
      precioCompra: 25000,
      precioVenta: 40000,
      stockActual: 0,
      stockMinimo: 0,
      aplicaIva: true,
      activo: true,
    );

Future<int> _categoria(String nombre) => db
    .into(db.tablaCategoria)
    .insert(TablaCategoriaCompanion.insert(nombre: nombre));

void main() {
  setUp(() async {
    db = baseEnMemoria();
    sesion = await sesionDePrueba(db);
    productos = RepositorioProductosImpl(db, sesion);
  });

  tearDown(() => db.close());

  test('el prefijo sale del nombre de la categoría', () async {
    final aceites = await _categoria('Aceites');

    final creado = await productos.crear(_producto(categoriaId: aceites));

    expect(creado.sku, 'ACE-001');
  });

  test('sin categoría cae en la serie general', () async {
    final creado = await productos.crear(_producto());

    expect(creado.sku, 'PRD-001');
  });

  test('dos altas seguidas no comparten código', () async {
    final aceites = await _categoria('Aceites');

    final uno = await productos.crear(
      _producto(nombre: 'Aceite 20W50', categoriaId: aceites),
    );
    final dos = await productos.crear(
      _producto(nombre: 'Aceite 10W30', categoriaId: aceites),
    );

    expect(uno.sku, 'ACE-001');
    expect(dos.sku, 'ACE-002');
  });

  test('dos categorías con las mismas tres letras no chocan', () async {
    // ACEites y ACEro: el prefijo de tres coincide, así que la segunda se
    // alarga. «Accesorios» no valdría de ejemplo —da ACC, que ya es distinto—.
    final aceites = await _categoria('Aceites');
    final acero = await _categoria('Acero');

    final uno = await productos.crear(
      _producto(nombre: 'Aceite', categoriaId: aceites),
    );
    final dos = await productos.crear(
      _producto(nombre: 'Varilla', categoriaId: acero),
    );

    // La que llegó primero se queda con el prefijo corto.
    expect(uno.sku, 'ACE-001');
    expect(dos.sku, 'ACER-001');
  });

  test('previsualizar no consume el número', () async {
    final aceites = await _categoria('Aceites');

    expect(await productos.previsualizarSku(aceites), 'ACE-001');
    expect(await productos.previsualizarSku(aceites), 'ACE-001');

    final creado = await productos.crear(_producto(categoriaId: aceites));
    expect(creado.sku, 'ACE-001');
  });

  test('un alta que falla devuelve el número a la serie', () async {
    final aceites = await _categoria('Aceites');
    await productos.crear(_producto(nombre: 'Aceite', categoriaId: aceites));

    // Nombre en blanco: lo rechaza el `CHECK` de la tabla, ya dentro de la
    // transacción que había tomado el número.
    await expectLater(
      productos.crear(_producto(nombre: '   ', categoriaId: aceites)),
      throwsA(anything),
    );

    final siguiente = await productos.crear(
      _producto(nombre: 'Otro aceite', categoriaId: aceites),
    );
    expect(siguiente.sku, 'ACE-002');
  });

  test('el SKU que llega puesto se respeta: editar no lo regenera', () async {
    final aceites = await _categoria('Aceites');
    final creado = await productos.crear(_producto(categoriaId: aceites));

    final editado = await productos.actualizar(
      creado.copyWith(nombre: 'Aceite 20W50 sintético'),
    );

    expect(editado.sku, 'ACE-001');
  });
}
