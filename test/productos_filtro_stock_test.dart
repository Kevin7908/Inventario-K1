// Cableado de los chips de stock: que el filtro llegue a la consulta y que el
// conteo de cada chip se calcule dentro del ámbito que la tabla está mostrando.
//
// Es un test de providers, no de widgets: `ProductosVista` arrastra
// `EncabezadoConCuenta`, que lee la sesión desde `get_it`, y montar todo eso
// no probaría nada que no cubra ya el widget test de share2.
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/categorias/modelo/categoria.dart';
import 'package:inventario_k1/backend/features/categorias/repositorio/repositorio_categorias_impl.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';
import 'package:inventario_k1/backend/features/productos/repositorio/repositorio_producto_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/backend/share/database/app_db_provider.dart';
import 'package:inventario_k1/frontend/features/productos/provider/productos_provider.dart';

late AppDb db;
late ProviderContainer container;

Producto _producto({
  required String nombre,
  required String sku,
  required double stock,
  int? categoriaId,
}) =>
    Producto(
      sku: sku,
      nombre: nombre,
      categoriaId: categoriaId,
      precioCompra: 1000,
      precioVenta: 2000,
      stockActual: stock,
      stockMinimo: 3,
      aplicaIva: true,
      activo: true,
    );

void main() {
  late int frenos;
  late int motor;

  setUp(() async {
    db = AppDb(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );

    final repoCategorias = RepositorioCategoriasImpl(db);
    frenos = (await repoCategorias.crear(Categoria(nombre: 'Frenos', creadoEn: DateTime.now(), actualizadoEn: DateTime.now()))).id!;
    motor = (await repoCategorias.crear(Categoria(nombre: 'Motor', creadoEn: DateTime.now(), actualizadoEn: DateTime.now()))).id!;

    final repo = RepositorioProductosImpl(db);
    // Frenos: 2 en stock, 1 bajo, 1 agotado. Motor: 1 agotado.
    await repo.crear(_producto(
        nombre: 'Pastillas', sku: 'F-1', stock: 40, categoriaId: frenos));
    await repo.crear(_producto(
        nombre: 'Disco', sku: 'F-2', stock: 12, categoriaId: frenos));
    await repo.crear(_producto(
        nombre: 'Guaya', sku: 'F-3', stock: 2, categoriaId: frenos));
    await repo.crear(_producto(
        nombre: 'Banda', sku: 'F-4', stock: 0, categoriaId: frenos));
    await repo.crear(_producto(
        nombre: 'Bujía', sku: 'M-1', stock: 0, categoriaId: motor));

    // Se suscribe **después** de sembrar, por dos razones: en Riverpod 3 un
    // provider sin oyentes se descarta apenas se lee y su `.future` no resuelve
    // nunca; y `.future` entrega la primera emisión, que si se escucha antes es
    // una foto a medio insertar.
    container.listen(productosProvider, (_, _) {});
    container.listen(conteoStockProvider, (_, _) {});
    container.listen(productosResumenProvider, (_, _) {});
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<List<String>> nombresVisibles() async {
    await container.read(productosProvider.future);
    // Un microtask para que la re-suscripción del notifier emita su página.
    await Future<void>.delayed(Duration.zero);
    return container
        .read(productosProvider)
        .value!
        .items
        .map((p) => p.nombre)
        .toList();
  }

  test('cada chip de stock recorta la tabla a su tramo', () async {
    final notifier = container.read(productosProvider.notifier);
    await container.read(productosProvider.future);

    notifier.filtrarPorStock(FiltroStock.sinStock);
    expect(await nombresVisibles(), ['Banda', 'Bujía']);

    notifier.filtrarPorStock(FiltroStock.stockBajo);
    expect(
      await nombresVisibles(),
      ['Guaya'],
      reason: 'stock bajo no incluye a los agotados',
    );

    notifier.filtrarPorStock(FiltroStock.enStock);
    expect(await nombresVisibles(), ['Disco', 'Pastillas']);

    notifier.filtrarPorStock(FiltroStock.todos);
    expect(await nombresVisibles(), hasLength(5));
  });

  test('el conteo de los chips respeta la categoría activa', () async {
    final notifier = container.read(productosProvider.notifier);
    await container.read(productosProvider.future);

    final global = await container.read(conteoStockProvider.future);
    expect(global.total, 5);
    expect(global.enStock, 2);
    expect(global.stockBajo, 1);
    expect(global.sinStock, 2);

    notifier.filtrarPorCategoria(motor);
    final soloMotor = await container.read(conteoStockProvider.future);

    expect(soloMotor.total, 1, reason: 'los frenos ya no cuentan');
    expect(soloMotor.enStock, 0);
    expect(soloMotor.stockBajo, 0);
    expect(soloMotor.sinStock, 1);
  });

  test('elegir un chip no vacía el conteo de los demás', () async {
    final notifier = container.read(productosProvider.notifier);
    await container.read(productosProvider.future);

    notifier.filtrarPorStock(FiltroStock.sinStock);
    final conteo = await container.read(conteoStockProvider.future);

    expect(conteo.total, 5);
    expect(conteo.enStock, 2, reason: 'el chip "En stock" sigue con su número');
    expect(conteo.stockBajo, 1);
    expect(conteo.sinStock, 2);
  });

  test('el encabezado sigue contando todo el catálogo aunque haya filtro',
      () async {
    final notifier = container.read(productosProvider.notifier);
    await container.read(productosProvider.future);

    notifier.filtrarPorCategoria(motor);
    final resumen = await container.read(productosResumenProvider.future);

    expect(resumen.total, 5, reason: 'productosResumenProvider va sin filtro');
    expect(resumen.stockBajo, 1);
    expect(resumen.sinStock, 2);
  });

  test('cambiar de filtro vuelve a la primera página', () async {
    final notifier = container.read(productosProvider.notifier);
    await container.read(productosProvider.future);

    notifier.irAPagina(0);
    notifier.filtrarPorStock(FiltroStock.sinStock);

    expect(container.read(productosProvider).value!.pagina, 0);
  });
}
