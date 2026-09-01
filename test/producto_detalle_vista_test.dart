// Regresión de layout de la ficha de producto.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/inventario/modelo/movimiento_inventario.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';
import 'package:inventario_k1/backend/share/dominio/permiso.dart';
import 'package:inventario_k1/frontend/features/autenticacion/provider/auth_providers.dart';
import 'package:inventario_k1/frontend/features/inventario/provider/inventario_providers.dart';
import 'package:inventario_k1/backend/features/productos/modelo/compatibilidad.dart';
import 'package:inventario_k1/frontend/features/productos/provider/compatibilidades_provider.dart';
import 'package:inventario_k1/frontend/features/productos/vista/producto_detalle_vista.dart';

import 'package:inventario_k1/backend/features/compras/modelo/compra_item.dart';
import 'package:inventario_k1/frontend/features/compras/provider/compras_providers.dart';

import 'soporte/repositorio_inventario_falso.dart';

const _producto = Producto(
  id: 1,
  sku: 'FRE-001',
  nombre: 'Pastillas de freno delanteras',
  descripcion: 'Juego de pastillas para disco delantero.',
  categoriaId: 1,
  categoriaNombre: 'Frenos',
  unidadMedidaNombre: 'und',
  proveedorNombre: 'Repuestos del Valle',
  precioCompra: 18000,
  precioVenta: 28000,
  stockActual: 12,
  stockMinimo: 4,
  ubicacionBodega: 'Estante A-3',
  aplicaIva: true,
  activo: true,
);

/// La ficha observa el libro mayor del producto y esconde «Dar entrada» según
/// el permiso, así que necesita su `ProviderScope`. El repositorio es falso: lo
/// que se prueba aquí es el layout, no SQLite.
Future<void> _pumpFicha(
  WidgetTester tester,
  Size tamano, {
  List<MovimientoInventario> movimientos = const [],
  Set<Permiso> permisos = const {},
  UltimaCompra? ultimaCompra,
  List<Compatibilidad> compatibilidades = const [],
  /// La ficha solo pinta sus acciones cuando es la página completa. Dentro de
  /// `DialogoDetalleProductoWidget` no recibe callbacks y es de solo lectura.
  bool conAcciones = false,
}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositorioInventarioProvider.overrideWithValue(
          RepositorioInventarioFalso(movimientos: movimientos),
        ),
        permisosSesionProvider.overrideWith((ref) => Stream.value(permisos)),
        // Un stream síncrono en vez de la consulta real: los streams de Drift
        // no avanzan bajo el `fakeAsync` de `flutter_test` y dejan un timer
        // pendiente al cerrarse. Lo que se prueba aquí es el layout; que la
        // consulta traiga lo correcto lo cubre
        // `repositorio_marcas_compatibilidad_test.dart`.
        compatibilidadesProvider(_producto.id!)
            .overrideWith((ref) => Stream.value(compatibilidades)),
        // Lo mismo con la última compra: la ficha la muestra desde que las
        // remisiones existen, y su consulta la cubre
        // `repositorio_compras_test.dart`.
        ultimaCompraProvider(_producto.id!)
            .overrideWith((ref) => Stream.value(ultimaCompra)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ProductoDetalleVista(
            producto: _producto,
            alEditar: conAcciones ? () {} : null,
          ),
        ),
      ),
    ),
  );
  // Dos pases: `permisosSesionProvider` es un `StreamProvider` y su primer
  // valor llega en un microtask, después del primer frame.
  await tester.pump();
  await tester.pump();
}

void main() {
  // La ficha vive dentro de un SingleChildScrollView, así que no tiene alto
  // acotado: un hijo que estire a lo alto sin límite tumba el layout con
  // "BoxConstraints forces an infinite height" y la pantalla queda en blanco.
  testWidgets('la ficha se compone en ventana ancha sin romper el layout',
      (tester) async {
    await _pumpFicha(tester, const Size(1400, 1000));

    expect(tester.takeException(), isNull);
    expect(find.text('Pastillas de freno delanteras'), findsOneWidget);
    expect(find.text('Stock disponible'), findsOneWidget);
    expect(find.text('Unidad de medida'), findsOneWidget);
  });

  testWidgets('la ficha se compone en ventana angosta sin romper el layout',
      (tester) async {
    // Por debajo de 900 la ficha pasa a una sola columna.
    await _pumpFicha(tester, const Size(760, 1000));

    expect(tester.takeException(), isNull);
    expect(find.text('Stock mínimo'), findsOneWidget);
    expect(find.text('Ubicación'), findsOneWidget);
  });

  // El bloque «Movimientos recientes» era un marcador que decía «Aún no se
  // registran movimientos» pasara lo que pasara, con un comentario diciendo
  // que la tabla no existía. Existe desde hace tiempo.
  testWidgets('los movimientos recientes salen del libro mayor',
      (tester) async {
    await _pumpFicha(
      tester,
      const Size(1400, 1000),
      movimientos: [
        movimientoDePrueba(cantidad: -2),
        movimientoDePrueba(
          id: 2,
          tipo: TipoMovimiento.entradaCompra,
          cantidad: 6,
        ),
      ],
    );

    expect(find.text('Aún no se registran movimientos'), findsNothing);
    expect(find.text('Venta'), findsOneWidget);
    expect(find.text('−2'), findsOneWidget);
    expect(find.text('Compra a proveedor'), findsOneWidget);
    expect(find.text('+6'), findsOneWidget);
  });

  testWidgets('sin movimientos se ve el hueco, no una lista vacía',
      (tester) async {
    await _pumpFicha(tester, const Size(1400, 1000));

    expect(find.text('Aún no se registran movimientos'), findsOneWidget);
  });

  testWidgets('sin permisos no se ofrece ni comprar ni dar entrada',
      (tester) async {
    await _pumpFicha(tester, const Size(1400, 1200), conAcciones: true);

    expect(find.text('Editar producto'), findsOneWidget);
    expect(find.text('Registrar compra'), findsNothing);
    expect(find.text('Entrada sin factura'), findsNothing);
  });

  testWidgets('con INVENTARIO_ENTRADA aparece la entrada sin factura',
      (tester) async {
    // Son dos gestos distintos y cada uno tiene su permiso: la remisión con
    // proveedor y costo es una compra; esto es lo que llega sin papel.
    await _pumpFicha(
      tester,
      const Size(1400, 1200),
      conAcciones: true,
      permisos: {Permiso.inventarioEntrada},
    );

    expect(find.text('Entrada sin factura'), findsOneWidget);
    expect(find.text('Registrar compra'), findsNothing);
  });

  testWidgets('con COMPRAS_CREAR aparece registrar la compra', (tester) async {
    await _pumpFicha(
      tester,
      const Size(1400, 1200),
      conAcciones: true,
      permisos: {Permiso.comprasCrear},
    );

    expect(find.text('Registrar compra'), findsOneWidget);
  });

  group('la última compra', () {
    testWidgets('sin remisiones registradas lo dice', (tester) async {
      await _pumpFicha(tester, const Size(1400, 1200));

      expect(
        find.text('Todavía no se ha comprado con una remisión registrada.'),
        findsOneWidget,
      );
    });

    testWidgets('con remisión muestra el costo real y el proveedor',
        (tester) async {
      // Es lo que el diseño pedía y el backend no tenía: hasta que existieron
      // las compras, la ficha solo podía enseñar `precio_compra`.
      await _pumpFicha(
        tester,
        const Size(1400, 1200),
        ultimaCompra: UltimaCompra(
          compraId: 7,
          numero: 'COM-2026-0007',
          fecha: DateTime.now().subtract(const Duration(days: 12)),
          costoUnitario: 6500,
          cantidad: 12,
          proveedorNombre: 'Repuestos JR',
        ),
      );

      expect(find.text(r'$6.500'), findsOneWidget);
      expect(find.textContaining('hace 12 días'), findsOneWidget);
      expect(find.textContaining('Repuestos JR'), findsOneWidget);
      expect(find.text('Ver la remisión COM-2026-0007'), findsOneWidget);
    });
  });

  group('compatibilidad', () {
    testWidgets('sin compatibilidades declaradas se ve el hueco',
        (tester) async {
      await _pumpFicha(tester, const Size(1400, 1000));

      expect(find.text('Sin información de compatibilidad'), findsOneWidget);
    });

    testWidgets('la de marca se lee distinta de la de modelo', (tester) async {
      // Es la diferencia que el panel existe para mostrar: una línea de marca
      // vale por todas las motos de esa marca, la de modelo solo por una.
      await _pumpFicha(
        tester,
        const Size(1400, 1000),
        compatibilidades: const [
          Compatibilidad(id: 1, productoId: 1, marcaId: 3, marca: 'Yamaha'),
          Compatibilidad(
            id: 2,
            productoId: 1,
            modeloId: 7,
            marca: 'Bajaj',
            modelo: 'Pulsar NS200',
            cilindraje: 200,
          ),
        ],
      );

      expect(find.text('Yamaha (toda la marca)'), findsOneWidget);
      expect(find.text('Bajaj Pulsar NS200 · 200 cc'), findsOneWidget);
      expect(find.text('Sin información de compatibilidad'), findsNothing);
    });

    testWidgets('sin PRODUCTOS_EDITAR no se ofrece quitar ni agregar',
        (tester) async {
      // Esconder el botón es orden, no control: la compuerta que vale está en
      // el repositorio (`CLAUDE.md` §7 bis) y la cubre su propio test.
      await _pumpFicha(
        tester,
        const Size(1400, 1000),
        compatibilidades: const [
          Compatibilidad(id: 1, productoId: 1, marcaId: 3, marca: 'Yamaha'),
        ],
      );

      expect(find.byTooltip('Quitar'), findsNothing);
      expect(find.byTooltip('Agregar moto compatible'), findsNothing);
    });

    testWidgets('con PRODUCTOS_EDITAR aparecen los dos gestos',
        (tester) async {
      await _pumpFicha(
        tester,
        const Size(1400, 1000),
        permisos: {Permiso.productosEditar},
        compatibilidades: const [
          Compatibilidad(id: 1, productoId: 1, marcaId: 3, marca: 'Yamaha'),
        ],
      );

      expect(find.byTooltip('Quitar'), findsOneWidget);
      expect(find.byTooltip('Agregar moto compatible'), findsOneWidget);
    });
  });
}
