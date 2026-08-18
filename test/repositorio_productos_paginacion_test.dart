// Paginación, filtrado y conteos del repositorio de productos.
//
// Corre contra una base SQLite en memoria: es la única forma de comprobar que
// el WHERE, el COUNT y el LIMIT se resuelven de verdad en SQL y no en Dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/categorias/modelo/categoria.dart';
import 'package:inventario_k1/backend/features/categorias/repositorio/repositorio_categorias_impl.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';
import 'package:inventario_k1/backend/features/productos/repositorio/repositorio_producto.dart';
import 'package:inventario_k1/backend/features/productos/repositorio/repositorio_producto_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'soporte/base_en_memoria.dart';

late AppDb db;
late RepositorioProductosImpl repo;
late RepositorioCategoriasImpl repoCategorias;

Producto _producto({
  required String nombre,
  required String sku,
  int? categoriaId,
  double stock = 10,
  double stockMinimo = 3,
}) =>
    Producto(
      sku: sku,
      nombre: nombre,
      categoriaId: categoriaId,
      precioCompra: 1000,
      precioVenta: 2000,
      stockActual: stock,
      stockMinimo: stockMinimo,
      aplicaIva: true,
      activo: true,
    );

Producto _conProveedor({
  required String nombre,
  required String sku,
  required int proveedorId,
}) =>
    Producto(
      sku: sku,
      nombre: nombre,
      proveedorId: proveedorId,
      precioCompra: 1000,
      precioVenta: 2000,
      stockActual: 10,
      stockMinimo: 3,
      aplicaIva: true,
      activo: true,
    );

Future<int> _crearCategoria(String nombre) async {
  final creada = await repoCategorias.crear(
    Categoria(
      nombre: nombre,
      creadoEn: DateTime.now(),
      actualizadoEn: DateTime.now(),
    ),
  );
  return creada.id!;
}

void main() {
  setUp(() async {
    db = baseEnMemoria();
    repo = RepositorioProductosImpl(db);
    repoCategorias = RepositorioCategoriasImpl(db);
  });

  tearDown(() async => db.close());

  test('la página trae solo su tramo pero informa el total real', () async {
    for (var i = 1; i <= 7; i++) {
      await repo.crear(
        _producto(nombre: 'Producto ${i.toString().padLeft(2, '0')}', sku: 'P-$i'),
      );
    }

    final primera = await repo
        .observarPagina(
          filtro: const FiltroProductos(),
          pagina: 0,
          tamano: 3,
        )
        .first;

    expect(primera.items.length, 3);
    expect(primera.total, 7, reason: 'el total ignora el LIMIT');
    expect(primera.items.first.nombre, 'Producto 01');

    final ultima = await repo
        .observarPagina(
          filtro: const FiltroProductos(),
          pagina: 2,
          tamano: 3,
        )
        .first;

    expect(ultima.items.length, 1, reason: 'la última página va incompleta');
    expect(ultima.items.single.nombre, 'Producto 07');
    expect(ultima.total, 7);
  });

  test('la búsqueda filtra en SQL por nombre, SKU y categoría', () async {
    final frenos = await _crearCategoria('Frenos');
    final motor = await _crearCategoria('Motor');

    await repo.crear(
      _producto(nombre: 'Pastillas', sku: 'FRE-001', categoriaId: frenos),
    );
    await repo.crear(
      _producto(nombre: 'Bujía', sku: 'MOT-001', categoriaId: motor),
    );

    Future<List<String>> buscar(String q) async {
      final pagina = await repo
          .observarPagina(
            filtro: FiltroProductos(busqueda: q),
            pagina: 0,
            tamano: 50,
          )
          .first;
      return pagina.items.map((p) => p.nombre).toList();
    }

    expect(await buscar('pastil'), ['Pastillas']);
    expect(await buscar('MOT-'), ['Bujía']);
    // El nombre de la categoría también cuenta, como en el buscador anterior.
    expect(await buscar('frenos'), ['Pastillas']);
    expect(await buscar('nada'), isEmpty);
  });

  test('soloActivos deja fuera lo dado de baja, y el total lo refleja',
      () async {
    await repo.crear(_producto(nombre: 'Vigente', sku: 'ACT-1'));
    final baja = await repo.crear(_producto(nombre: 'Descontinuado', sku: 'BAJ-1'));
    await repo.actualizar(baja.copyWith(activo: false));

    final todos = await repo
        .observarPagina(filtro: const FiltroProductos(), pagina: 0, tamano: 10)
        .first;
    expect(todos.total, 2, reason: 'el catálogo sí muestra los inactivos');

    final vendibles = await repo
        .observarPagina(
          filtro: const FiltroProductos(soloActivos: true),
          pagina: 0,
          tamano: 10,
        )
        .first;

    expect(vendibles.items.map((p) => p.nombre), ['Vigente']);
    expect(
      vendibles.total,
      1,
      reason: 'el COUNT tiene que aplicar el mismo WHERE que la página',
    );
  });

  test('los filtros de stock no se solapan', () async {
    await repo.crear(_producto(nombre: 'Ok', sku: 'A-1', stock: 10, stockMinimo: 3));
    await repo.crear(_producto(nombre: 'Bajo', sku: 'A-2', stock: 2, stockMinimo: 3));
    await repo.crear(_producto(nombre: 'Agotado', sku: 'A-3', stock: 0, stockMinimo: 3));

    Future<List<String>> conFiltro(FiltroProductos f) async {
      final pagina =
          await repo.observarPagina(filtro: f, pagina: 0, tamano: 50).first;
      return pagina.items.map((p) => p.nombre).toList();
    }

    expect(await conFiltro(const FiltroProductos(soloEnStock: true)), ['Ok']);
    expect(
      await conFiltro(const FiltroProductos(soloStockBajo: true)),
      ['Bajo'],
      reason: 'stock bajo excluye a los agotados',
    );
    expect(
      await conFiltro(const FiltroProductos(soloSinStock: true)),
      ['Agotado'],
    );
  });

  test('el conteo por categoría se resuelve con GROUP BY', () async {
    final frenos = await _crearCategoria('Frenos');
    final motor = await _crearCategoria('Motor');

    await repo.crear(_producto(nombre: 'A', sku: 'A-1', categoriaId: frenos));
    await repo.crear(_producto(nombre: 'B', sku: 'B-1', categoriaId: frenos));
    await repo.crear(_producto(nombre: 'C', sku: 'C-1', categoriaId: motor));
    await repo.crear(_producto(nombre: 'D', sku: 'D-1'));

    final conteo = await repo.observarConteoPorCategoria().first;

    expect(conteo[frenos], 2);
    expect(conteo[motor], 1);
    expect(conteo.length, 2, reason: 'los productos sin categoría no cuentan');
  });

  test('el resumen parte el catálogo en tres tramos que suman el total',
      () async {
    await repo.crear(_producto(nombre: 'Ok', sku: 'A-1', stock: 10, stockMinimo: 3));
    await repo.crear(_producto(nombre: 'Ok2', sku: 'A-4', stock: 8, stockMinimo: 3));
    await repo.crear(_producto(nombre: 'Bajo', sku: 'A-2', stock: 2, stockMinimo: 3));
    await repo.crear(_producto(nombre: 'Agotado', sku: 'A-3', stock: 0, stockMinimo: 3));

    final resumen = await repo.observarResumen().first;

    expect(resumen.total, 4);
    expect(resumen.enStock, 2);
    expect(resumen.stockBajo, 1, reason: 'el agotado ya no cuenta como bajo');
    expect(resumen.sinStock, 1);
    expect(
      resumen.enStock + resumen.stockBajo + resumen.sinStock,
      resumen.total,
      reason: 'los tramos son excluyentes: es lo que hace sumables los chips',
    );
  });

  test('el resumen respeta la categoría y la búsqueda del filtro', () async {
    final frenos = await _crearCategoria('Frenos');
    final motor = await _crearCategoria('Motor');

    await repo.crear(
      _producto(nombre: 'Pastillas', sku: 'F-1', categoriaId: frenos, stock: 9),
    );
    await repo.crear(
      _producto(nombre: 'Disco', sku: 'F-2', categoriaId: frenos, stock: 1),
    );
    await repo.crear(
      _producto(nombre: 'Bujía', sku: 'M-1', categoriaId: motor, stock: 0),
    );

    final soloFrenos =
        await repo.observarResumen(filtro: FiltroProductos(categoriaId: frenos)).first;

    expect(soloFrenos.total, 2, reason: 'la bujía de Motor queda fuera');
    expect(soloFrenos.enStock, 1);
    expect(soloFrenos.stockBajo, 1);
    expect(soloFrenos.sinStock, 0, reason: 'el agotado es de otra categoría');

    final porBusqueda =
        await repo.observarResumen(filtro: const FiltroProductos(busqueda: 'buj')).first;
    expect(porBusqueda.total, 1);
    expect(porBusqueda.sinStock, 1);
  });

  test('el tramo de stock activo no recorta los conteos del resumen', () async {
    await repo.crear(_producto(nombre: 'Ok', sku: 'A-1', stock: 10, stockMinimo: 3));
    await repo.crear(_producto(nombre: 'Bajo', sku: 'A-2', stock: 2, stockMinimo: 3));

    // Con "Stock bajo" seleccionado, los demás chips tienen que seguir
    // mostrando su número: si no, seleccionar uno vaciaría a los otros.
    final resumen = await repo
        .observarResumen(filtro: const FiltroProductos(soloStockBajo: true))
        .first;

    expect(resumen.total, 2);
    expect(resumen.enStock, 1);
    expect(resumen.stockBajo, 1);
  });

  test('el conteo por proveedor se resuelve con GROUP BY', () async {
    // Un proveedor son dos filas: la identidad en `personas` y el rol en
    // `proveedores`.
    for (final razonSocial in ['Distrimotos', 'MotoPartes']) {
      final personaId = await db.into(db.tablaPersona).insert(
            TablaPersonaCompanion.insert(nombres: razonSocial),
          );
      await db.into(db.tablaProveedor).insert(
            TablaProveedorCompanion.insert(personaId: personaId),
          );
    }

    await repo.crear(_conProveedor(nombre: 'A', sku: 'A-1', proveedorId: 1));
    await repo.crear(_conProveedor(nombre: 'B', sku: 'B-1', proveedorId: 1));
    await repo.crear(_conProveedor(nombre: 'C', sku: 'C-1', proveedorId: 2));
    await repo.crear(_producto(nombre: 'D', sku: 'D-1'));

    final conteo = await repo.observarConteoPorProveedor().first;

    expect(conteo[1], 2);
    expect(conteo[2], 1);
    expect(conteo.length, 2, reason: 'los productos sin proveedor no cuentan');
  });

  test('las categorías también se paginan y buscan en SQL', () async {
    for (final nombre in ['Frenos', 'Motor', 'Suspensión', 'Transmisión']) {
      await _crearCategoria(nombre);
    }

    final primera = await repoCategorias
        .observarPagina(pagina: 0, tamano: 3)
        .first;

    expect(primera.items.length, 3);
    expect(primera.total, 4, reason: 'el total ignora el LIMIT');
    expect(primera.items.first.nombre, 'Frenos', reason: 'ordenadas por nombre');

    final segunda = await repoCategorias
        .observarPagina(pagina: 1, tamano: 3)
        .first;
    expect(segunda.items.single.nombre, 'Transmisión');

    final buscadas = await repoCategorias
        .observarPagina(busqueda: 'mot', pagina: 0, tamano: 10)
        .first;
    expect(buscadas.items.map((c) => c.nombre), ['Motor']);
    expect(buscadas.total, 1, reason: 'el total respeta la búsqueda');
  });
}
