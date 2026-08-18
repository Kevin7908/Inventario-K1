// Al editar un producto, la categoría y el proveedor que ya tiene asignados
// deben quedar marcados en sus selectores.
//
// Es la parte más frágil de sacar Proveedores de `get_it`: antes el ViewModel
// era un singleton que llevaba escuchando desde el arranque y casi siempre
// tenía la lista lista. Con Riverpod los catálogos se suscriben al abrir el
// formulario, así que si la preselección lee su valor actual en vez de
// esperarlo, los campos quedan en "Sin …" aunque el producto los tenga.
//
// Los catálogos se sustituyen por streams síncronos en vez de usar Drift: bajo
// el `fakeAsync` de `flutter_test` los streams de Drift no avanzan y el test se
// cuelga. Lo que se prueba aquí es el widget, no la consulta —esa la cubre
// `repositorio_productos_paginacion_test.dart`—.
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/categorias/modelo/categoria.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';
import 'package:inventario_k1/backend/features/proveedores/modelo/proveedor.dart';
import 'package:inventario_k1/backend/share/database/app_db_provider.dart';
import 'package:inventario_k1/frontend/features/categorias/provider/categorias_provider.dart';
import 'package:inventario_k1/frontend/features/productos/widgets/formulario_producto.dart';
import 'package:inventario_k1/frontend/features/proveedores/provider/proveedores_provider.dart';
import 'soporte/base_en_memoria.dart';

final _frenos = Categoria(
  id: 7,
  nombre: 'Frenos',
  creadoEn: DateTime(2026),
  actualizadoEn: DateTime(2026),
);

Proveedor _prov(int id, String nombre, {bool activo = true}) => Proveedor(
      id: id,
      nombre: nombre,
      activo: activo,
      colorHex: '#3B82F6',
      icono: 'local_shipping',
    );

Producto _producto({int? categoriaId, int? proveedorId}) => Producto(
      id: 1,
      sku: 'FRN-001',
      nombre: 'Pastillas freno delantero',
      categoriaId: categoriaId,
      proveedorId: proveedorId,
      precioCompra: 1000,
      precioVenta: 2000,
      stockActual: 10,
      stockMinimo: 3,
      aplicaIva: true,
      activo: true,
    );

void main() {
  // Cada test abre su propia AppDb en memoria; el aviso de Drift sobre bases
  // duplicadas no aplica aquí porque no comparten ejecutor.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  Future<void> montar(
    WidgetTester tester, {
    Producto? producto,
    List<Proveedor> proveedores = const [],
  }) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Unidades de medida no se sustituye —es un AsyncNotifier— pero sí
          // necesita una base: la de memoria le basta para quedarse vacía.
          appDatabaseProvider.overrideWithValue(baseEnMemoria()),
          catalogoCategoriasProvider.overrideWith((ref) => Stream.value([_frenos])),
          catalogoProveedoresProvider.overrideWith((ref) => Stream.value(proveedores)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FormularioProducto(
                productoAEditar: producto,
                alTerminar: () {},
                alCancelar: () {},
              ),
            ),
          ),
        ),
      ),
    );

    // Primer pump: monta y suscribe. Los siguientes dejan llegar la emisión de
    // los catálogos y correr el `setState` de la preselección.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('editar un producto marca su categoría y su proveedor',
      (tester) async {
    await montar(
      tester,
      producto: _producto(categoriaId: 7, proveedorId: 3),
      proveedores: [_prov(3, 'Distrimotos S.A.'), _prov(4, 'MotoPartes JR')],
    );

    expect(
      find.text('Frenos'),
      findsWidgets,
      reason: 'la categoría del producto queda seleccionada',
    );
    expect(
      find.text('Distrimotos S.A.'),
      findsWidgets,
      reason: 'el proveedor del producto queda seleccionado',
    );
    expect(
      find.text('Sin proveedor'),
      findsNothing,
      reason: 'si aparece, la preselección leyó antes de que llegara la lista',
    );
    expect(find.text('Sin categoría'), findsNothing);
  });

  testWidgets('un catálogo vacío no rompe la preselección de los otros',
      (tester) async {
    // Sin proveedores en la lista: la categoría igual tiene que quedar puesta.
    await montar(tester, producto: _producto(categoriaId: 7, proveedorId: 3));

    expect(find.text('Frenos'), findsWidgets);
    expect(find.text('Sin proveedor'), findsOneWidget);
  });

  testWidgets('crear un producto nuevo no preselecciona nada', (tester) async {
    await montar(tester, proveedores: [_prov(3, 'Distrimotos S.A.')]);

    expect(find.text('Sin categoría'), findsOneWidget);
    expect(find.text('Sin proveedor'), findsOneWidget);
  });

  testWidgets('un proveedor inactivo no se ofrece al crear', (tester) async {
    await montar(
      tester,
      proveedores: [
        _prov(3, 'Distrimotos S.A.'),
        _prov(9, 'Casa cerrada', activo: false),
      ],
    );

    await tester.tap(find.text('Sin proveedor'));
    await tester.pumpAndSettle();

    expect(find.text('Distrimotos S.A.'), findsWidgets);
    expect(find.text('Casa cerrada'), findsNothing);
  });

  testWidgets('el proveedor inactivo ya asignado sí se conserva al editar',
      (tester) async {
    // Si se ocultara sin más, editar cualquier otro campo de un producto de un
    // proveedor dado de baja le borraría el proveedor sin avisar.
    await montar(
      tester,
      producto: _producto(proveedorId: 9),
      proveedores: [
        _prov(3, 'Distrimotos S.A.'),
        _prov(9, 'Casa cerrada', activo: false),
      ],
    );

    expect(find.text('Casa cerrada'), findsWidgets);
  });
}
