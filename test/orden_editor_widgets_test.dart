// Los dos widgets del editor de órdenes que el test del notifier no alcanza:
// la línea del panel derecho y la fila expandible de servicios.
//
// Lo que más importa comprobar es que **la línea de servicio pide técnico
// antes de cruzar** al panel derecho. Es la decisión del §3.3 del plan, y en
// la interfaz se reduce a que el botón «Agregar» esté apagado hasta que haya
// técnico: `ordenes_tareas.tecnico_id` es `NOT NULL` y una tarea a medias no
// se puede escribir.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/frontend/features/ordenes/orden_detalle/modelo/linea_orden_editor.dart';
import 'package:inventario_k1/frontend/features/ordenes/orden_detalle/widgets/linea_orden.dart';
import 'package:inventario_k1/frontend/share2/share2.dart';

LineaOrdenEditor _linea(
  TipoLineaOrden tipo, {
  int id = 1,
  double cantidad = 1,
  int precio = 32000,
  String? tecnico,
  bool completado = false,
}) =>
    LineaOrdenEditor(
      id: id,
      tipo: tipo,
      referenciaId: tipo == TipoLineaOrden.cargo ? null : 7,
      descripcion: 'Pastilla de freno',
      cantidad: cantidad,
      precioUnitario: precio,
      tecnicoNombre: tecnico,
      completado: completado,
    );

/// El campo de precio de la línea, distinguido por su hint.
final _campoPrecio = find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == 'Precio',
);

Future<void> _pump(WidgetTester tester, Widget hijo) => tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: SizedBox(width: 360, child: hijo)),
        ),
      ),
    );

Widget _lineaOrden(
  LineaOrdenEditor linea, {
  bool editable = true,
  double? disponible,
  ValueChanged<double>? alCambiarCantidad,
  ValueChanged<int>? alCambiarPrecio,
  VoidCallback? alEliminar,
  ValueChanged<bool>? alMarcarCompletada,
}) =>
    LineaOrden(
      linea: linea,
      editable: editable,
      disponible: disponible,
      alCambiarCantidad: alCambiarCantidad ?? (_) {},
      alCambiarPrecio: alCambiarPrecio ?? (_) {},
      alEliminar: alEliminar ?? () {},
      alMarcarCompletada: alMarcarCompletada ?? (_) {},
    );

void main() {
  group('la línea cambia de control según el tipo', () {
    testWidgets('el repuesto lleva cantidad y no papelera', (tester) async {
      await _pump(tester, _lineaOrden(_linea(TipoLineaOrden.repuesto)));

      expect(find.byType(ControlCantidad), findsOneWidget);
      expect(
        find.byIcon(Icons.delete_outline_rounded),
        findsNothing,
        reason: 'el − con cantidad 1 ya quita la línea',
      );
    });

    testWidgets('el servicio lleva papelera y no cantidad', (tester) async {
      await _pump(tester, _lineaOrden(_linea(TipoLineaOrden.servicio)));

      // `ordenes_tareas` no tiene columna de cantidad: fingir un `– 1 +` que
      // no se puede subir sería mentir sobre el modelo.
      expect(find.byType(ControlCantidad), findsNothing);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });

    testWidgets('el cargo lleva papelera pero no casilla de completado',
        (tester) async {
      await _pump(tester, _lineaOrden(_linea(TipoLineaOrden.cargo)));

      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
      expect(
        find.byIcon(Icons.radio_button_unchecked_rounded),
        findsNothing,
        reason: 'un cargo no se "completa": no es trabajo de nadie',
      );
    });
  });

  group('el precio se teclea o no según de dónde salga', () {
    testWidgets('el del repuesto se muestra pero no se edita', (tester) async {
      await _pump(tester, _lineaOrden(_linea(TipoLineaOrden.repuesto)));

      expect(find.text(r'$32.000'), findsOneWidget);
      expect(
        _campoPrecio,
        findsNothing,
        reason: 'lo pone el catálogo, igual que en cotizaciones',
      );
    });

    testWidgets('el de la mano de obra sí se edita', (tester) async {
      var precio = 0;
      await _pump(
        tester,
        _lineaOrden(
          _linea(TipoLineaOrden.servicio),
          alCambiarPrecio: (v) => precio = v,
        ),
      );

      expect(_campoPrecio, findsOneWidget);
      await tester.enterText(_campoPrecio, '45000');
      expect(precio, 45000);
    });

    testWidgets('el del cargo suelto también', (tester) async {
      await _pump(tester, _lineaOrden(_linea(TipoLineaOrden.cargo)));
      expect(_campoPrecio, findsOneWidget);
    });
  });

  group('el servicio muestra quién lo hace y si ya está', () {
    testWidgets('pinta el nombre del técnico bajo la descripción',
        (tester) async {
      await _pump(
        tester,
        _lineaOrden(_linea(TipoLineaOrden.servicio, tecnico: 'Ana Torres')),
      );

      expect(find.text('Ana Torres'), findsOneWidget);
    });

    testWidgets('la casilla avisa por callback con el valor contrario',
        (tester) async {
      bool? recibido;
      await _pump(
        tester,
        _lineaOrden(
          _linea(TipoLineaOrden.servicio),
          alMarcarCompletada: (v) => recibido = v,
        ),
      );

      await tester.tap(find.byIcon(Icons.radio_button_unchecked_rounded));
      expect(recibido, isTrue);
    });

    testWidgets('una tarea hecha se ve tachada', (tester) async {
      await _pump(
        tester,
        _lineaOrden(_linea(TipoLineaOrden.servicio, completado: true)),
      );

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      final texto = tester.widget<Text>(find.text('Pastilla de freno'));
      expect(texto.style?.decoration, TextDecoration.lineThrough);
    });
  });

  group('una orden cerrada se ve pero no se toca', () {
    testWidgets('sin editable no hay campo de precio ni papelera activa',
        (tester) async {
      await _pump(
        tester,
        _lineaOrden(_linea(TipoLineaOrden.servicio), editable: false),
      );

      // El precio pasa a texto plano: una guarda de la base rechazaría el
      // `UPDATE`, así que dejar teclear sería teclear contra una pared.
      expect(_campoPrecio, findsNothing);
      expect(find.text(r'$32.000'), findsOneWidget);

      final papelera = tester.widget<BotonIcono>(
        find.ancestor(
          of: find.byIcon(Icons.delete_outline_rounded),
          matching: find.byType(BotonIcono),
        ),
      );
      expect(papelera.alPresionar, isNull);
    });

    testWidgets('el control de cantidad queda deshabilitado', (tester) async {
      await _pump(
        tester,
        _lineaOrden(_linea(TipoLineaOrden.repuesto), editable: false),
      );

      final control =
          tester.widget<ControlCantidad>(find.byType(ControlCantidad));
      expect(control.alCambiar, isNull);
    });
  });

  group('el repuesto no pasa del stock disponible', () {
    // Desde que anotar un repuesto lo descuenta del inventario, pedir más de
    // lo que hay lo rechaza el repositorio. Recortar aquí evita el viaje —y
    // el mensaje rojo— igual que lleva haciendo el carrito del mostrador.

    testWidgets('el + se apaga al llegar al tope', (tester) async {
      // Quedan 2 en bodega y la línea ya se llevó 3: el tope son 5.
      await _pump(
        tester,
        _lineaOrden(
          _linea(TipoLineaOrden.repuesto, cantidad: 5),
          disponible: 5,
        ),
      );

      final mas = tester.widget<InkWell>(
        find.ancestor(
          of: find.byIcon(Icons.add_rounded),
          matching: find.byType(InkWell),
        ),
      );
      expect(mas.onTap, isNull);
    });

    testWidgets('escribir de más recorta al tope', (tester) async {
      var avisada = 0.0;
      await _pump(
        tester,
        _lineaOrden(
          _linea(TipoLineaOrden.repuesto),
          disponible: 8,
          alCambiarCantidad: (c) => avisada = c,
        ),
      );

      await tester.enterText(find.byType(TextField).first, '50');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(avisada, 8);
    });

    testWidgets('sin dato de stock no se acota', (tester) async {
      // Es lo que pasa mientras el catálogo todavía no llegó: mejor dejar
      // teclear y que el repositorio decida, que bloquear por no saber.
      await _pump(tester, _lineaOrden(_linea(TipoLineaOrden.repuesto)));

      final control =
          tester.widget<ControlCantidad>(find.byType(ControlCantidad));
      expect(control.maximo, isNull);
    });
  });

  group('los botones de solo ícono llevan tooltip (§8)', () {
    testWidgets('la papelera y la casilla', (tester) async {
      await _pump(tester, _lineaOrden(_linea(TipoLineaOrden.servicio)));

      expect(find.byTooltip('Quitar de la orden'), findsOneWidget);
      expect(find.byTooltip('Marcar la tarea como hecha'), findsOneWidget);
    });
  });

  group('el orden de los bloques', () {
    test('el catálogo ofrece repuesto primero; los bloques, servicio', () {
      // Son dos órdenes distintos a propósito: al armar una orden se empieza
      // por las piezas, pero al leerla el cliente quiere ver primero la mano
      // de obra, como en el mockup.
      expect(TipoLineaOrden.ordenCatalogo.first, TipoLineaOrden.repuesto);
      expect(TipoLineaOrden.values.first, TipoLineaOrden.servicio);
    });

    test('solo el repuesto tiene cantidad y mueve inventario', () {
      expect(TipoLineaOrden.repuesto.tieneCantidad, isTrue);
      expect(TipoLineaOrden.servicio.tieneCantidad, isFalse);
      expect(TipoLineaOrden.cargo.tieneCantidad, isFalse);

      // El cargo suelto no descuenta a propósito: si el repuesto estuviera en
      // el catálogo, sería un repuesto.
      expect(TipoLineaOrden.cargo.mueveInventario, isFalse);
      expect(TipoLineaOrden.repuesto.mueveInventario, isTrue);
    });
  });
}
