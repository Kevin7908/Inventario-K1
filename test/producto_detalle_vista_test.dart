// Regresión de layout de la ficha de producto.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/inventario/modelo/movimiento_inventario.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';
import 'package:inventario_k1/backend/share/dominio/permiso.dart';
import 'package:inventario_k1/frontend/features/autenticacion/provider/auth_providers.dart';
import 'package:inventario_k1/frontend/features/inventario/provider/inventario_providers.dart';
import 'package:inventario_k1/frontend/features/productos/vista/producto_detalle_vista.dart';

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

  testWidgets('sin INVENTARIO_ENTRADA no se ofrece dar entrada',
      (tester) async {
    await _pumpFicha(tester, const Size(1400, 1200), conAcciones: true);

    expect(find.text('Editar producto'), findsOneWidget);
    expect(find.text('Dar entrada'), findsNothing);
  });

  testWidgets('con INVENTARIO_ENTRADA aparece el botón', (tester) async {
    await _pumpFicha(
      tester,
      const Size(1400, 1200),
      conAcciones: true,
      permisos: {Permiso.inventarioEntrada},
    );

    expect(find.text('Dar entrada'), findsOneWidget);
  });
}
