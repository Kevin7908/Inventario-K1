// Editor de cotizaciones: la línea del panel derecho, los totales y las reglas
// del notifier.
//
// Lo que más importa comprobar es que **el precio de un producto no se puede
// tocar** y el de un servicio sí: es la regla que separa "el catálogo manda"
// de "la mano de obra la cotiza el técnico", y en la interfaz se reduce a que
// haya o no un campo de texto en la línea.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/cotizaciones/enum/enum_cotizacion.dart';
import 'package:inventario_k1/backend/features/ventas/servicios/modelo/servicio.dart';
import 'package:inventario_k1/core/iva_app.dart';
import 'package:inventario_k1/core/resultado.dart';
import 'package:inventario_k1/frontend/features/cotizaciones/cotizaciones_detalle/modelo/item_cotizacion_editor.dart';
import 'package:inventario_k1/frontend/features/cotizaciones/cotizaciones_detalle/provider/cotizacion_editor_provider.dart';
import 'package:inventario_k1/frontend/features/cotizaciones/cotizaciones_detalle/provider/validacion_cotizacion.dart';
import 'package:inventario_k1/frontend/features/cotizaciones/cotizaciones_detalle/widgets/linea_cotizacion.dart';
import 'package:inventario_k1/frontend/features/cotizaciones/cotizaciones_detalle/widgets/totales_cotizacion.dart';
import 'package:inventario_k1/frontend/features/cotizaciones/cotizaciones_detalle/modelo/cotizacion_editor_state.dart';
import 'package:inventario_k1/frontend/features/cotizaciones/provider/cotizaciones_provider.dart';
import 'package:inventario_k1/frontend/share2/share2.dart';

import 'soporte/repositorio_cotizaciones_falso.dart';

ItemCotizacionEditor _item(
  TipoItemCotizacion tipo, {
  double cantidad = 2,
  int precio = 32000,
}) =>
    ItemCotizacionEditor(
      tipo: tipo,
      referenciaId: tipo == TipoItemCotizacion.libre ? null : 7,
      descripcion: 'Aceite Motul 20W50',
      cantidad: cantidad,
      precioUnitario: precio,
    );

/// El campo de precio de la línea, distinguido del de cantidad por su hint.
/// Contar `TextField` a secas ya no sirve: la cantidad también es editable.
final _campoPrecio = find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == 'Precio',
);

Future<void> _pump(WidgetTester tester, Widget hijo) => tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: Scaffold(body: hijo)),
      ),
    );

void main() {
  group('línea de la cotización', () {
    testWidgets('el precio de un producto se muestra pero no se edita',
        (tester) async {
      await _pump(
        tester,
        LineaCotizacion(
          item: _item(TipoItemCotizacion.producto),
          alCambiarCantidad: (_) {},
          alCambiarPrecio: (_) {},
          alEliminar: () {},
        ),
      );

      expect(find.text('\$32.000'), findsOneWidget);
      expect(
        _campoPrecio,
        findsNothing,
        reason: 'el precio lo pone el catálogo, no se teclea',
      );
      expect(
        find.byType(ControlCantidad),
        findsOneWidget,
        reason: 'la cantidad sí se edita, incluso en un producto',
      );
    });

    testWidgets('el precio de un servicio sí se edita', (tester) async {
      var precio = 0;
      await _pump(
        tester,
        LineaCotizacion(
          item: _item(TipoItemCotizacion.servicio, cantidad: 1, precio: 0),
          alCambiarCantidad: (_) {},
          alCambiarPrecio: (valor) => precio = valor,
          alEliminar: () {},
        ),
      );

      expect(_campoPrecio, findsOneWidget);
      await tester.enterText(_campoPrecio, '25000');
      expect(precio, 25000);
    });

    testWidgets('la fila muestra el precio unitario, no el subtotal',
        (tester) async {
      // Es la fila del carrito del diseño: nombre y precio por unidad. El
      // importe de la línea se ve en el total del pie.
      await _pump(
        tester,
        LineaCotizacion(
          item: _item(TipoItemCotizacion.producto, cantidad: 3, precio: 18000),
          alCambiarCantidad: (_) {},
          alCambiarPrecio: (_) {},
          alEliminar: () {},
        ),
      );

      expect(find.text('\$18.000'), findsOneWidget);
      expect(find.text('\$54.000'), findsNothing);
    });

    testWidgets('el − con cantidad 1 quita la línea, no la deja en cero',
        (tester) async {
      var eliminada = false;
      final cantidades = <double>[];

      await _pump(
        tester,
        LineaCotizacion(
          item: _item(TipoItemCotizacion.producto, cantidad: 1),
          alCambiarCantidad: cantidades.add,
          alCambiarPrecio: (_) {},
          alEliminar: () => eliminada = true,
        ),
      );

      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();

      expect(eliminada, isTrue, reason: 'el diseño no tiene papelera');
      expect(cantidades, isEmpty);
    });

    testWidgets('el + suma una unidad', (tester) async {
      final cambios = <double>[];
      await _pump(
        tester,
        LineaCotizacion(
          item: _item(TipoItemCotizacion.producto, cantidad: 1),
          alCambiarCantidad: cambios.add,
          alCambiarPrecio: (_) {},
          alEliminar: () {},
        ),
      );

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();

      expect(cambios, [2.0]);
    });
  });

  group('totales', () {
    // `kIva` es una constante de compilación, así que un test no puede
    // moverla: lo que se comprueba es que **hoy**, con la tasa en 0, el pie no
    // pinta ni subtotal ni IVA. Si algún día `kIva` deja de ser 0, este test
    // avisa cambiando de resultado y hay que actualizarlo.
    testWidgets('sin IVA el pie va directo al total', (tester) async {
      await _pump(tester, const TotalesCotizacion(cotizacionId: null));
      await tester.pumpAndSettle();

      expect(find.text('Total'), findsOneWidget);
      expect(hayIva, isFalse, reason: 'el taller no factura IVA hoy');
      expect(find.text(etiquetaIva), findsNothing);
      // Sin descuento, subtotal y total son el mismo número.
      expect(find.text('Subtotal'), findsNothing);
    });
  });

  group('validación', () {
    test('una cotización sin líneas no se guarda', () {
      final resultado = validarCotizacion(
        items: const [],
        vigenciaHasta: DateTime.now(),
      );
      expect(resultado, isA<Fallo>());
    });

    test('el servicio sin precio no se guarda; el producto sí pasa', () {
      final sinPrecio = validarCotizacion(
        items: [_item(TipoItemCotizacion.servicio, precio: 0)],
        vigenciaHasta: DateTime.now(),
      );
      expect(sinPrecio, isA<Fallo>());

      final conPrecio = validarCotizacion(
        items: [_item(TipoItemCotizacion.producto)],
        vigenciaHasta: DateTime.now(),
      );
      expect(conPrecio, isNull);
    });

    test('la vigencia no puede quedar en el pasado', () {
      final resultado = validarCotizacion(
        items: [_item(TipoItemCotizacion.producto)],
        vigenciaHasta: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(resultado, isA<Fallo>());
    });

    test('cliente y moto no son obligatorios', () {
      // No hay nada que pasarle: la firma ni los recibe. Si algún día se
      // exigieran, este test dejaría de compilar y no de fallar en silencio.
      final resultado = validarCotizacion(
        items: [_item(TipoItemCotizacion.producto)],
        vigenciaHasta: DateTime.now().add(const Duration(days: 30)),
      );
      expect(resultado, isNull);
    });
  });

  group('notifier', () {
    late ProviderContainer container;
    late RepositorioCotizacionesFalso repo;

    setUp(() {
      repo = RepositorioCotizacionesFalso();
      container = ProviderContainer(
        overrides: [repositorioCotizacionesProvider.overrideWithValue(repo)],
      );
      // Sin un oyente el provider no se mantiene vivo y `.future` no resuelve.
      container.listen(cotizacionEditorProvider(null), (_, _) {});
    });

    tearDown(() => container.dispose());

    test('agregar dos veces el mismo servicio suma cantidad, no duplica',
        () async {
      await container.read(cotizacionEditorProvider(null).future);
      final notifier =
          container.read(cotizacionEditorProvider(null).notifier);

      notifier
        ..agregarServicio(
          const Servicio(id: 3, nombre: 'Cambio de aceite', activo: true),
        )
        ..agregarServicio(
          const Servicio(id: 3, nombre: 'Cambio de aceite', activo: true),
        );

      final items = container.read(cotizacionEditorProvider(null)).value!.items;
      expect(items, hasLength(1));
      expect(items.single.cantidad, 2);
    });

    test('dos líneas libres no se funden aunque digan lo mismo', () async {
      await container.read(cotizacionEditorProvider(null).future);
      final notifier =
          container.read(cotizacionEditorProvider(null).notifier);

      notifier
        ..agregarLibre(descripcion: 'Guardabarros', precio: 80000)
        ..agregarLibre(descripcion: 'Guardabarros', precio: 80000);

      final items = container.read(cotizacionEditorProvider(null)).value!.items;
      expect(
        items,
        hasLength(2),
        reason: 'sin catálogo detrás, son dos cargos distintos',
      );
    });

    test('un servicio con precio sugerido entra con ese precio puesto',
        () async {
      await container.read(cotizacionEditorProvider(null).future);
      container.read(cotizacionEditorProvider(null).notifier).agregarServicio(
            const Servicio(
              id: 3,
              nombre: 'Cambio de aceite',
              precioSugerido: 25000,
              activo: true,
            ),
          );

      final items = container.read(cotizacionEditorProvider(null)).value!.items;
      expect(items.single.precioUnitario, 25000);
    });

    test('un servicio sin precio sugerido entra en cero, para teclearlo',
        () async {
      await container.read(cotizacionEditorProvider(null).future);
      container.read(cotizacionEditorProvider(null).notifier).agregarServicio(
            const Servicio(id: 4, nombre: 'Diagnóstico', activo: true),
          );

      final items = container.read(cotizacionEditorProvider(null)).value!.items;
      expect(items.single.precioUnitario, 0);
    });

    test('el total no le suma IVA: ya viene dentro del precio', () async {
      await container.read(cotizacionEditorProvider(null).future);
      container
          .read(cotizacionEditorProvider(null).notifier)
          .agregarLibre(descripcion: 'Repuesto', precio: 100000);

      final estado = container.read(cotizacionEditorProvider(null)).value!;
      expect(estado.subtotal, 100000);
      expect(estado.total, 100000);
      expect(estado.iva, ivaIncluidoEn(100000));
    });
  });

  group('guardado automático', () {
    late ProviderContainer container;
    late RepositorioCotizacionesFalso repo;

    // Getters locales no se pueden declarar dentro de una función, así que
    // van como funciones: se leen igual en las aserciones.
    CotizacionEditorNotifier notifier() =>
        container.read(cotizacionEditorProvider(null).notifier);
    CotizacionEditorState estado() =>
        container.read(cotizacionEditorProvider(null)).value!;

    Future<void> abrir({bool falla = false}) async {
      repo = RepositorioCotizacionesFalso(fallaAlGuardar: falla);
      container = ProviderContainer(
        overrides: [repositorioCotizacionesProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      container.listen(cotizacionEditorProvider(null), (_, _) {});
      await container.read(cotizacionEditorProvider(null).future);
    }

    test('una cotización vacía no se crea: quemaría un consecutivo', () async {
      await abrir();

      // Tocar solo la cabecera no debería crear nada.
      notifier().cambiarNotas('para el cliente de la Pulsar');
      await notifier().guardarAhora();

      expect(repo.vecesGuardado, 0);
      expect(estado().guardado, EstadoGuardado.sinCambios);
    });

    test('la primera línea la crea; la segunda ya actualiza', () async {
      await abrir();

      notifier().agregarLibre(descripcion: 'Repuesto', precio: 50000);
      await notifier().guardarAhora();

      expect(repo.creaciones, hasLength(1));
      expect(estado().guardado, EstadoGuardado.guardado);
      expect(estado().cotizacionId, isNotNull);
      expect(estado().numero, 'COT-2026-0001', reason: 'relee el consecutivo');

      notifier().agregarLibre(descripcion: 'Otro', precio: 10000);
      await notifier().guardarAhora();

      expect(
        repo.creaciones,
        hasLength(1),
        reason: 'no crea una segunda cotización',
      );
      expect(repo.actualizaciones, hasLength(1));
    });

    test('un cambio deja el estado en pendiente hasta que se guarda', () async {
      await abrir();

      notifier().agregarLibre(descripcion: 'Repuesto', precio: 50000);
      expect(estado().guardado, EstadoGuardado.pendiente);

      await notifier().guardarAhora();
      expect(estado().guardado, EstadoGuardado.guardado);
    });

    test('lo inválido no se guarda a medias: queda bloqueado con el motivo',
        () async {
      await abrir();

      // Un servicio sin precio: la validación lo rechaza.
      notifier().agregarServicio(
        const Servicio(id: 3, nombre: 'Cambio de aceite', activo: true),
      );
      await notifier().guardarAhora();

      expect(repo.vecesGuardado, 0);
      expect(estado().guardado, EstadoGuardado.bloqueado);
      expect(estado().motivoBloqueo, contains('precio'));
      expect(estado().haySinGuardar, isTrue);

      // Al ponerle precio se desbloquea y sí se guarda.
      notifier().cambiarPrecio(0, 25000);
      await notifier().guardarAhora();

      expect(repo.creaciones, hasLength(1));
      expect(estado().guardado, EstadoGuardado.guardado);
    });

    test('si la base falla, lo dice en vez de decir que guardó', () async {
      await abrir(falla: true);

      notifier().agregarLibre(descripcion: 'Repuesto', precio: 50000);
      final resultado = await notifier().guardarAhora();

      expect(resultado, isA<Fallo>());
      expect(estado().guardado, EstadoGuardado.bloqueado);
      expect(estado().motivoBloqueo, contains('No se pudo guardar'));
    });

    test('filtrar el catálogo no cuenta como cambio que guardar', () async {
      await abrir();

      notifier()
        ..cambiarTipo(TipoItemCotizacion.servicio)
        ..buscarEnCatalogo('aceite')
        ..filtrarPorCategoria(3);

      expect(
        estado().guardado,
        EstadoGuardado.sinCambios,
        reason: 'los filtros son de pantalla, no de la cotización',
      );
    });
  });


  group('descuento', () {
    test('se recorta al subtotal: el total nunca queda en negativo', () {
      final estado = CotizacionEditorState(
        vigenciaHasta: DateTime(2026, 12, 31),
        items: [_item(TipoItemCotizacion.producto, cantidad: 2, precio: 30000)],
      );

      // 2 x 30.000 = 60.000 de subtotal.
      expect(estado.subtotal, 60000);
      expect(estado.conDescuento(200000).descuento, 60000);
      expect(estado.conDescuento(-5000).descuento, 0);
      expect(estado.conDescuento(10000).total, 50000);
    });

    test('quitar una línea recorta el descuento que ya no cabe', () {
      final estado = CotizacionEditorState(
        vigenciaHasta: DateTime(2026, 12, 31),
        items: [
          _item(TipoItemCotizacion.producto, cantidad: 1, precio: 30000),
          _item(TipoItemCotizacion.servicio, cantidad: 1, precio: 50000),
        ],
      ).conDescuento(60000);

      expect(estado.descuento, 60000);

      // Se va el servicio: quedan 30.000 de subtotal y la rebaja no cabe.
      // Sin el recorte, el total daría -30.000 y el CHECK de la tabla
      // rechazaría el guardado con un error que nadie puede leer.
      final sinServicio = estado.sinItem(1);
      expect(sinServicio.subtotal, 30000);
      expect(sinServicio.descuento, 30000);
      expect(sinServicio.total, 0);
    });

    test('el descuento sale del precio con IVA, y el total no suma nada', () {
      final estado = CotizacionEditorState(
        vigenciaHasta: DateTime(2026, 12, 31),
        items: [_item(TipoItemCotizacion.producto, cantidad: 1, precio: 100000)],
      ).conDescuento(20000);

      // Misma regla que el punto de venta: los precios ya traen el IVA dentro,
      // así que rebajar 20.000 rebaja 20.000 de lo que paga el cliente.
      expect(estado.total, 80000);
      expect(estado.iva, ivaIncluidoEn(80000),
          reason: 'el IVA se extrae del total, no se le suma');
    });
  });

  group('agrupación de líneas', () {
    test('separa productos de servicios y suma cada bloque', () {
      final grupos = CotizacionEditorState.agrupar([
        _item(TipoItemCotizacion.producto, cantidad: 1, precio: 60000),
        _item(TipoItemCotizacion.servicio, cantidad: 1, precio: 50000),
        _item(TipoItemCotizacion.servicio, cantidad: 1, precio: 30000),
      ]);

      expect(grupos, hasLength(2));
      expect(grupos[0].tipo, TipoItemCotizacion.producto);
      expect(grupos[0].titulo, 'Productos');
      expect(grupos[0].subtotal, 60000);
      expect(grupos[1].titulo, 'Servicios');
      expect(grupos[1].subtotal, 80000);
    });

    test('no devuelve grupos vacíos', () {
      final grupos = CotizacionEditorState.agrupar([
        _item(TipoItemCotizacion.producto),
      ]);

      expect(grupos, hasLength(1));
      expect(grupos.single.titulo, 'Productos');
    });

    test('cada línea conserva su índice en la lista original', () {
      // Es lo que impide que borrar la primera línea de "Servicios" borre la
      // primera de la cotización: el notifier indexa sobre `items`.
      final grupos = CotizacionEditorState.agrupar([
        _item(TipoItemCotizacion.servicio, precio: 10000),
        _item(TipoItemCotizacion.producto, precio: 20000),
        _item(TipoItemCotizacion.servicio, precio: 30000),
      ]);

      final productos = grupos.firstWhere(
        (g) => g.tipo == TipoItemCotizacion.producto,
      );
      final servicios = grupos.firstWhere(
        (g) => g.tipo == TipoItemCotizacion.servicio,
      );

      expect(productos.lineas.single.indice, 1);
      expect(servicios.lineas.map((l) => l.indice), [0, 2]);
    });

    test('sin líneas no hay grupos', () {
      expect(CotizacionEditorState.agrupar(const []), isEmpty);
    });
  });
}
