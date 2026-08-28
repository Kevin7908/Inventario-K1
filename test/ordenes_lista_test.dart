// El listado nuevo de Órdenes de servicio: las cuatro tarjetas de conteo, la
// tabla de seis columnas, el paginador y el filtro que los une.
//
// El repositorio va sustituido por uno falso que **pagina en memoria**: bajo el
// `fakeAsync` de `flutter_test` los streams reales de Drift no avanzan y
// `pumpAndSettle` se cuelga (ver `test/productos_filtro_stock_test.dart`). Que
// el recorte de verdad ocurra en SQL se prueba en
// `test/repositorio_ordenes_test.dart`; aquí se prueba que la pantalla le pida
// la página correcta y pinte lo que le devuelve.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/ordenes/enum/enum_ordenes.dart';
import 'package:inventario_k1/backend/features/ordenes/modelo/orden_resumen.dart';
import 'package:inventario_k1/backend/features/ordenes/repositorio/repositorio_ordenes.dart';
import 'package:inventario_k1/core/formato.dart';
import 'package:inventario_k1/frontend/features/ordenes/provider/ordenes_providers.dart';
import 'package:inventario_k1/frontend/features/ordenes/widgets/tabla_ordenes.dart';
import 'package:inventario_k1/frontend/features/ordenes/widgets/tarjetas_ordenes.dart';
import 'package:inventario_k1/frontend/share/share.dart';

OrdenResumen _orden({
  required int id,
  required String numero,
  String cliente = 'Carlos Ramírez',
  String moto = 'Bajaj Pulsar 2022',
  EstadoOrden estado = EstadoOrden.abierta,
  int manoObra = 0,
  int repuestos = 0,
  int cargos = 0,
  int descuento = 0,
  String? tecnico,
  int tecnicos = 0,
}) =>
    OrdenResumen(
      id: id,
      numeroOrden: numero,
      motoDescripcion: moto,
      clienteNombre: cliente,
      kilometrajeEntrada: 15000,
      diagnostico: null,
      estado: estado,
      fechaIngreso: DateTime(2026, 8, 18),
      subtotalManoObra: manoObra,
      subtotalRepuestos: repuestos,
      subtotalCargos: cargos,
      descuento: descuento,
      tecnicoNombre: tecnico,
      tecnicosDistintos: tecnicos,
    );

const _resumen = (total: 4, enProceso: 2, pendientes: 1, completadas: 1);

/// Repositorio de mentira que hace en Dart lo que el de verdad hace en SQL.
///
/// Solo implementa `observarPagina`: es lo único que el listado usa. Los
/// filtros replican el `WHERE` del repositorio para que el test pueda afirmar
/// que la vista **le pasa** el filtro, no que lo aplica ella.
class _RepoFalso implements RepositorioOrdenes {
  _RepoFalso(this.todas);

  final List<OrdenResumen> todas;

  /// Los filtros con los que la vista fue pidiendo páginas, en orden.
  final peticiones = <({FiltroOrdenes filtro, int pagina, int tamano})>[];

  @override
  Stream<PaginaOrdenes> observarPagina({
    required FiltroOrdenes filtro,
    required int pagina,
    required int tamano,
  }) {
    peticiones.add((filtro: filtro, pagina: pagina, tamano: tamano));

    final query = filtro.busqueda.toLowerCase();
    final coinciden = [
      for (final o in todas)
        if ((filtro.estado == null || o.estado == filtro.estado) &&
            (query.isEmpty ||
                o.numeroOrden.toLowerCase().contains(query) ||
                o.clienteNombre.toLowerCase().contains(query) ||
                o.motoDescripcion.toLowerCase().contains(query)))
          o,
    ];

    final desde = (pagina * tamano).clamp(0, coinciden.length);
    final hasta = (desde + tamano).clamp(0, coinciden.length);

    return Stream.value(
      PaginaOrdenes(
        items: coinciden.sublist(desde, hasta),
        // El total cuenta todas las coincidencias, no las de la página: es lo
        // que el paginador necesita para saber cuántas hay.
        total: coinciden.length,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('El listado no usa \${invocation.memberName}');
}

late _RepoFalso _repo;

Future<ProviderContainer> _montar(
  WidgetTester tester, {
  required List<OrdenResumen> ordenes,
  ResumenOrdenes resumen = _resumen,
}) async {
  // La superficie por defecto del test son 800x600. Esta es una app de
  // escritorio: cuatro tarjetas y seis columnas no caben ahí, y el
  // desbordamiento sería del test, no del diseño.
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  _repo = _RepoFalso(ordenes);

  final container = ProviderContainer(
    overrides: [
      repositorioOrdenesProvider.overrideWithValue(_repo),
      ordenesResumenProvider.overrideWith((ref) => Stream.value(resumen)),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const TarjetasOrdenes(),
              Expanded(child: TablaOrdenes(alAbrir: (_) {})),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('la tabla trae las seis columnas del diseño', (tester) async {
    await _montar(tester, ordenes: [_orden(id: 1, numero: 'ORD-0001')]);

    for (final titulo in [
      'Orden',
      'Cliente / Moto',
      'Técnico',
      'Fecha',
      'Estado',
      'Total',
    ]) {
      expect(find.text(titulo.toUpperCase()), findsOneWidget,
          reason: 'falta la columna $titulo');
    }
  });

  testWidgets('cada fila muestra número, cliente, moto y estado',
      (tester) async {
    await _montar(tester, ordenes: [
      _orden(id: 1, numero: 'ORD-0001', estado: EstadoOrden.lista),
    ]);

    expect(find.text('ORD-0001'), findsOneWidget);
    expect(find.text('Carlos Ramírez'), findsOneWidget);
    expect(find.text('Bajaj Pulsar 2022'), findsOneWidget);
    expect(find.text('Lista'), findsOneWidget);
  });

  testWidgets('el total de la fila resta el descuento', (tester) async {
    await _montar(tester, ordenes: [
      _orden(
        id: 1,
        numero: 'ORD-0001',
        manoObra: 50000,
        repuestos: 60000,
        cargos: 8000,
        descuento: 18000,
      ),
    ]);

    // 118.000 - 18.000. Sin IVA sumado encima: ya viene dentro del precio.
    expect(find.text(formatearPrecio(100000)), findsOneWidget);
  });

  testWidgets('la columna de técnico dice el nombre, "Varios" o "Sin asignar"',
      (tester) async {
    await _montar(tester, ordenes: [
      _orden(id: 1, numero: 'ORD-0001', tecnico: 'Ana Torres', tecnicos: 1),
      _orden(id: 2, numero: 'ORD-0002', tecnico: 'Ana Torres', tecnicos: 3),
      _orden(id: 3, numero: 'ORD-0003'),
    ]);

    expect(find.text('Ana Torres'), findsOneWidget);
    expect(find.text('Varios'), findsOneWidget);
    expect(find.text('Sin asignar'), findsOneWidget);
  });

  testWidgets('las cuatro tarjetas muestran el conteo de SQL', (tester) async {
    await _montar(tester, ordenes: const []);

    expect(find.text('Órdenes totales'), findsOneWidget);
    expect(find.text('En proceso'), findsOneWidget);
    expect(find.text('Pendientes'), findsOneWidget);
    expect(find.text('Completadas'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('el conteo de las tarjetas no cambia al filtrar', (tester) async {
    // Sale de un COUNT sobre toda la tabla, no de la lista recortada: contarlo
    // sobre lo filtrado diría algo distinto de lo que promete la etiqueta.
    final container = await _montar(tester, ordenes: [
      _orden(id: 1, numero: 'ORD-0001', estado: EstadoOrden.abierta),
      _orden(id: 2, numero: 'ORD-0002', estado: EstadoOrden.entregada),
    ]);

    container
        .read(ordenesProvider.notifier)
        .filtrarPorEstado(EstadoOrden.abierta);
    await tester.pumpAndSettle();

    expect(find.text('ORD-0001'), findsOneWidget);
    expect(find.text('ORD-0002'), findsNothing);
    expect(find.text('4'), findsOneWidget, reason: 'el total sigue siendo 4');
  });

  testWidgets('tocar la tarjeta activa quita el filtro', (tester) async {
    final container = await _montar(tester, ordenes: [
      _orden(id: 1, numero: 'ORD-0001', estado: EstadoOrden.abierta),
      _orden(id: 2, numero: 'ORD-0002', estado: EstadoOrden.entregada),
    ]);

    await tester.tap(find.text('En proceso'));
    await tester.pumpAndSettle();
    expect(find.text('ORD-0002'), findsNothing);

    // Mismo gesto para poner y para sacar: sin botón de "limpiar".
    await tester.tap(find.text('En proceso'));
    await tester.pumpAndSettle();
    expect(find.text('ORD-0002'), findsOneWidget);
    expect(container.read(ordenesProvider).value?.filtroEstado, isNull);
  });

  testWidgets('la búsqueda encuentra por número, cliente y moto',
      (tester) async {
    final container = await _montar(tester, ordenes: [
      _orden(id: 1, numero: 'ORD-0001', cliente: 'Carlos Ramírez'),
      _orden(id: 2, numero: 'ORD-0002', cliente: 'Lucía Peña', moto: 'Honda CB'),
    ]);

    final notifier = container.read(ordenesProvider.notifier);

    notifier.buscar('lucía');
    await tester.pumpAndSettle();
    expect(find.text('ORD-0002'), findsOneWidget);
    expect(find.text('ORD-0001'), findsNothing);

    notifier.buscar('honda');
    await tester.pumpAndSettle();
    expect(find.text('ORD-0002'), findsOneWidget);

    notifier.buscar('ORD-0001');
    await tester.pumpAndSettle();
    expect(find.text('ORD-0001'), findsOneWidget);
    expect(find.text('ORD-0002'), findsNothing);
  });

  testWidgets('sin resultados lo dice en vez de dejar la tabla en blanco',
      (tester) async {
    final container = await _montar(tester, ordenes: [
      _orden(id: 1, numero: 'ORD-0001'),
    ]);

    container.read(ordenesProvider.notifier).buscar('no existe');
    await tester.pumpAndSettle();

    expect(find.text('No hay órdenes que coincidan'), findsOneWidget);
  });

  testWidgets('la búsqueda y el estado se aplican juntos', (tester) async {
    final container = await _montar(tester, ordenes: [
      _orden(id: 1, numero: 'ORD-0001', cliente: 'Ana', estado: EstadoOrden.abierta),
      _orden(id: 2, numero: 'ORD-0002', cliente: 'Ana', estado: EstadoOrden.entregada),
    ]);

    container.read(ordenesProvider.notifier).buscar('ana');
    container
        .read(ordenesProvider.notifier)
        .filtrarPorEstado(EstadoOrden.entregada);
    await tester.pumpAndSettle();

    expect(find.text('ORD-0002'), findsOneWidget);
    expect(find.text('ORD-0001'), findsNothing);
  });

  group('el listado pide páginas, no el histórico entero', () {
    List<OrdenResumen> muchas(int cuantas) => [
          for (var i = 1; i <= cuantas; i++)
            _orden(id: i, numero: 'ORD-${i.toString().padLeft(4, '0')}'),
        ];

    testWidgets('la tabla solo pinta la página que le dieron', (tester) async {
      await _montar(tester, ordenes: muchas(30));

      // 12 por página: la 13ª no está en el árbol, ni recortada ni fuera de
      // pantalla. La 12ª sí está, pero puede no haberse construido todavía
      // —la tabla es perezosa—, así que el rango del paginador es quien lo
      // afirma.
      expect(find.text('ORD-0001'), findsOneWidget);
      expect(find.text('ORD-0013'), findsNothing);
      expect(find.text('Mostrando 1–12 de 30'), findsOneWidget);
    });

    testWidgets('el paginador cuenta con el total real, no con la página',
        (tester) async {
      await _montar(tester, ordenes: muchas(30));

      // 30 órdenes de a 12 son tres páginas. Si el total saliera de la página
      // visible, el paginador diría una sola.
      expect(find.text('3'), findsWidgets, reason: 'la tercera página existe');
      expect(find.textContaining('de 30'), findsOneWidget);
    });

    testWidgets('cambiar de página pide el OFFSET siguiente al repositorio',
        (tester) async {
      final container = await _montar(tester, ordenes: muchas(30));

      container.read(ordenesProvider.notifier).irAPagina(1);
      await tester.pumpAndSettle();

      expect(_repo.peticiones.last.pagina, 1);
      expect(_repo.peticiones.last.tamano, 12);
      expect(find.text('ORD-0013'), findsOneWidget);
      expect(find.text('ORD-0001'), findsNothing);
    });

    testWidgets('el filtro viaja al repositorio, no se aplica en la vista',
        (tester) async {
      final container = await _montar(tester, ordenes: muchas(30));

      container.read(ordenesProvider.notifier).buscar('ORD-0020');
      await tester.pumpAndSettle();

      expect(_repo.peticiones.last.filtro.busqueda, 'ORD-0020');
    });

    testWidgets('buscar vuelve a la primera página', (tester) async {
      // Si no volviera, buscar desde la página 3 dejaría la tabla en blanco:
      // el resultado cabe en la primera y el OFFSET se pasa de largo.
      final container = await _montar(tester, ordenes: muchas(30));
      final notifier = container.read(ordenesProvider.notifier);

      notifier.irAPagina(2);
      await tester.pumpAndSettle();

      notifier.buscar('ORD-0002');
      await tester.pumpAndSettle();

      expect(_repo.peticiones.last.pagina, 0);
      expect(find.text('ORD-0002'), findsOneWidget);
    });

    testWidgets('filtrar por estado también vuelve a la primera página',
        (tester) async {
      final container = await _montar(tester, ordenes: muchas(30));
      final notifier = container.read(ordenesProvider.notifier);

      notifier.irAPagina(2);
      await tester.pumpAndSettle();

      notifier.filtrarPorEstado(EstadoOrden.abierta);
      await tester.pumpAndSettle();

      expect(_repo.peticiones.last.pagina, 0);
      expect(_repo.peticiones.last.filtro.estado, EstadoOrden.abierta);
    });

    testWidgets('con una sola página el paginador no se pinta', (tester) async {
      await _montar(tester, ordenes: muchas(3));

      expect(find.byType(PaginacionWidget), findsNothing);
    });
  });
}
