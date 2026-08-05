// El IndexedStack del layout construía las doce vistas al arrancar, con sus
// providers y sus consultas a la base de datos. Ahora solo construye las que
// se visitaron.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/frontend/features/categorias/vista/categorias_vistas.dart';
import 'package:inventario_k1/frontend/features/productos/vista/producto_vista.dart';
import 'package:inventario_k1/frontend/features/ventas/principal/vista/venta_vista.dart';
import 'package:inventario_k1/frontend/layout/layout_principal.dart';
import 'package:inventario_k1/frontend/share2/nav/barra_lateral.dart';

void main() {
  testWidgets('al arrancar solo se construye la pantalla inicial',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LayoutPrincipal())),
    );

    // El sidebar sí se pinta entero: es la navegación.
    expect(find.byType(BarraLateral), findsOneWidget);
    expect(find.text('Productos'), findsOneWidget);

    // Pero ninguna de las vistas sin visitar entra al árbol. Si alguna se
    // construyera, además pediría base de datos y reventaría el test.
    expect(find.byType(ProductosVista), findsNothing);
    expect(find.byType(CategoriasVista), findsNothing);
    expect(find.byType(VentasVista), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el sidebar tiene su propia capa de repintado', (tester) async {
    // Sin RepaintBoundary, el hover de un ItemNav ensucia la capa que comparte
    // con todo el contenido; en Linux eso hace parpadear la barra de título.
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LayoutPrincipal())),
    );

    // Se comprueba sobre el render object, no con un finder de ancestros:
    // Scaffold y ListView ya insertan RepaintBoundary por su cuenta, así que
    // buscarlos por tipo daría verde aunque el sidebar no tuviera el suyo.
    expect(
      tester.renderObject(find.byType(BarraLateral)),
      isA<RenderRepaintBoundary>(),
    );
  });
}
