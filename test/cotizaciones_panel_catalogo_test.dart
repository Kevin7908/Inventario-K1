// Panel izquierdo del editor de cotizaciones: que arme el layout sin reventar
// y que muestre lo que toca según el tipo elegido.
//
// El caso que motiva este archivo es de layout, no de datos: `PanelCategorias`
// tiene un `Expanded` dentro de un `Column`, así que exige altura acotada, y la
// rejilla de tarjetas vive al lado de un panel de 360 px. Nada de eso lo ve
// `flutter analyze`.
//
// La superficie se fija a 1400×900 a propósito: los 800×600 por defecto de
// `flutter_test` no son una ventana de escritorio realista y desbordan por el
// ancho, que es un falso positivo aquí.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/categorias/modelo/categoria.dart';
import 'package:inventario_k1/backend/features/cotizaciones/enum/enum_cotizacion.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';
import 'package:inventario_k1/backend/features/productos/repositorio/repositorio_producto.dart';
import 'package:inventario_k1/backend/features/ventas/servicios/modelo/servicio.dart';
import 'package:inventario_k1/frontend/features/categorias/provider/categorias_provider.dart';
import 'package:inventario_k1/frontend/features/cotizaciones/cotizaciones_detalle/provider/catalogo_cotizacion_providers.dart';
import 'package:inventario_k1/frontend/features/cotizaciones/cotizaciones_detalle/provider/cotizacion_editor_provider.dart';
import 'package:inventario_k1/frontend/features/cotizaciones/cotizaciones_detalle/widgets/panel_catalogo.dart';
import 'package:inventario_k1/frontend/features/productos/provider/productos_provider.dart';
import 'package:inventario_k1/frontend/features/ventas/servicios/provider/servicios_provider.dart';
import 'package:inventario_k1/frontend/features/cotizaciones/provider/cotizaciones_provider.dart';
import 'package:inventario_k1/frontend/share2/share2.dart';

import 'soporte/repositorio_cotizaciones_falso.dart';

final _categorias = [
  Categoria(
    id: 1,
    nombre: 'Frenos',
    colorHex: '#01B763',
    icono: 'disc',
    creadoEn: DateTime(2026),
    actualizadoEn: DateTime(2026),
  ),
];

const _productos = [
  Producto(
    id: 7,
    sku: 'SKU-1123',
    nombre: 'Aceite Motul 20W50',
    precioCompra: 20000,
    precioVenta: 32000,
    stockActual: 12,
    stockMinimo: 2,
    aplicaIva: false,
    activo: true,
  ),
  Producto(
    id: 8,
    sku: 'SKU-1201',
    nombre: 'Pastilla de freno',
    precioCompra: 30000,
    precioVenta: 45000,
    stockActual: 0,
    stockMinimo: 1,
    aplicaIva: false,
    activo: true,
  ),
];

const _servicios = [
  Servicio(
    id: 3,
    nombre: 'Cambio de aceite',
    descripcion: 'Incluye filtro',
    precioSugerido: 25000,
    activo: true,
  ),
];

/// Monta el panel igual que el editor: dentro de una `Row` de altura acotada.
Future<ProviderContainer> _montar(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final container = ProviderContainer(
    overrides: [
      catalogoCategoriasProvider.overrideWith((_) => Stream.value(_categorias)),
      // La rejilla ya no lee el catálogo entero: pide una página al
      // repositorio. `catalogoCompletoProvider` sigue overrideado porque de él
      // salen las fotos de las líneas ya agregadas.
      catalogoCompletoProvider.overrideWith((_) => Stream.value(_productos)),
      paginaProductosCotizacionProvider.overrideWith(
        (_, _) => Stream.value(
          PaginaProductos(items: _productos, total: _productos.length),
        ),
      ),
      serviciosProvider.overrideWith(_ServiciosFalsos.new),
      // El editor guarda solo: sin esto, el temporizador del autoguardado
      // escribiría en la base real del desarrollador desde un test.
      repositorioCotizacionesProvider
          .overrideWithValue(RepositorioCotizacionesFalso()),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: PanelCatalogo(
                  cotizacionId: null,
                  focoBusqueda: FocusNode(),
                ),
              ),
              const SizedBox(width: 360),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

class _ServiciosFalsos extends ServiciosNotifier {
  @override
  Future<List<Servicio>> build() async => _servicios;
}

void main() {
  testWidgets('con productos arma el panel de categorías y la rejilla',
      (tester) async {
    await _montar(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(PanelCategorias), findsOneWidget);
    expect(find.text('Frenos'), findsOneWidget);
    // El panel es una barra lateral, no una tarjeta suelta: ocupa todo el alto.
    expect(tester.getSize(find.byType(PanelCategorias)).height, 900);
    expect(find.byType(TarjetaProducto), findsNWidgets(2));
    expect(find.text('SKU-1123'), findsOneWidget);
  });

  testWidgets('el stock se muestra pero no impide agregar', (tester) async {
    final container = await _montar(tester);

    expect(find.text('Sin stock · hay que pedirlo'), findsOneWidget);

    await tester.tap(find.byTooltip('Agregar a la cotización').last);
    // Deja correr el retardo del guardado automático para que no quede un
    // `Timer` vivo al desmontar el árbol.
    await tester.pump(const Duration(seconds: 2));

    final items =
        container.read(cotizacionEditorProvider(null)).value!.items;
    expect(items, hasLength(1));
    expect(items.single.referenciaId, 8, reason: 'el agotado sí entra');
  });

  testWidgets('en modo servicio el panel de categorías se queda, apagado',
      (tester) async {
    final container = await _montar(tester);

    container
        .read(cotizacionEditorProvider(null).notifier)
        .cambiarTipo(TipoItemCotizacion.servicio);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Antes desaparecía y la rejilla saltaba 208 px a la izquierda en cada
    // cambio de tipo.
    final panel = tester.widget<PanelCategorias>(find.byType(PanelCategorias));
    expect(panel.habilitado, isFalse);
    expect(find.byType(TarjetaProducto), findsNothing);
    expect(find.text('Cambio de aceite'), findsOneWidget);
  });

  testWidgets('en modo línea libre no hay buscador, pero sí panel apagado',
      (tester) async {
    final container = await _montar(tester);

    container
        .read(cotizacionEditorProvider(null).notifier)
        .cambiarTipo(TipoItemCotizacion.libre);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final panel = tester.widget<PanelCategorias>(find.byType(PanelCategorias));
    expect(panel.habilitado, isFalse);
    // El buscador del catálogo sí se va: no hay catálogo que buscar. El del
    // propio panel de categorías sigue ahí, pero deshabilitado.
    expect(find.text('Agregar a la cotización'), findsOneWidget);
  });

  testWidgets('el tipo se elige con radios, no con un desplegable',
      (tester) async {
    await _montar(tester);

    // Las tres a la vista sin abrir nada: era lo que escondía el dropdown.
    expect(find.byType(GrupoRadio<TipoItemCotizacion>), findsOneWidget);
    expect(find.text('Producto'), findsOneWidget);
    expect(find.text('Servicio'), findsOneWidget);
    expect(find.text('Línea libre'), findsOneWidget);
  });

  testWidgets('tocar el radio de servicio cambia el contenido del panel',
      (tester) async {
    await _montar(tester);

    await tester.tap(find.text('Servicio'));
    await tester.pumpAndSettle();

    expect(find.text('Cambio de aceite'), findsOneWidget);
    expect(find.byType(TarjetaProducto), findsNothing);
  });
}
