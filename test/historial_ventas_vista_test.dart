// La pantalla de Historial de ventas.
//
// Lo que fijan estos tests son las decisiones que no se ven en el código:
//
// - cada fila dice **quién cobró**, que es lo que hace útil el historial;
// - una anulada se ve tachada en vez de desaparecer: el documento existe;
// - filtrar «hasta» un día incluye ese día entero, no hasta su medianoche;
// - **leerla** no pide permisos: la ve cualquiera. Deshacer una venta sí:
//   devolver y anular están detrás de `POS_ANULAR`, y una factura ya anulada
//   no ofrece ninguna de las dos.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/pos/enum/enum_ventas.dart';
import 'package:inventario_k1/backend/features/pos/modelo/linea_venta_mostrador.dart';
import 'package:inventario_k1/backend/features/pos/modelo/venta_detalle.dart';
import 'package:inventario_k1/backend/features/pos/modelo/venta_resumen.dart';
import 'package:inventario_k1/backend/features/pos/repositorio/repositorio_ventas.dart';
import 'package:inventario_k1/backend/share/dominio/permiso.dart';
import 'package:inventario_k1/frontend/features/autenticacion/provider/auth_providers.dart';
import 'package:inventario_k1/frontend/features/pos/provider/pos_providers.dart';
import 'package:inventario_k1/frontend/features/ventas/provider/historial_ventas_providers.dart';
import 'package:inventario_k1/frontend/features/ventas/vista/historial_ventas_vista.dart';

import 'soporte/repositorio_auth_falso.dart';

VentaResumen _venta({
  int id = 1,
  String numero = 'FAC-0001',
  String cliente = 'Carlos Ramírez',
  String cajero = 'Marta Ríos',
  int total = 120000,
  int devuelto = 0,
  EstadoPago estado = EstadoPago.pagado,
  TipoVenta tipo = TipoVenta.mostrador,
}) =>
    VentaResumen(
      id: id,
      numeroFactura: numero,
      tipo: tipo,
      clienteNombre: cliente,
      total: total,
      iva: 0,
      descuento: 0,
      estadoPago: estado,
      metodoPago: MetodoPago.efectivo,
      creadoEn: DateTime(2026, 8, 25, 14, 5),
      cajero: cajero,
      totalDevuelto: devuelto,
    );

/// Un repositorio de ventas de mentira que recuerda con qué filtro se le
/// preguntó: es lo que permite comprobar que el rango de fechas llega bien.
class _VentasFalsas implements RepositorioVentas {
  _VentasFalsas({this.ventas = const []});

  List<VentaResumen> ventas;
  FiltroVentas? ultimoFiltro;

  @override
  Stream<PaginaVentas> observarPagina({
    required FiltroVentas filtro,
    required int pagina,
    required int tamano,
  }) {
    ultimoFiltro = filtro;
    return Stream.value(PaginaVentas(items: ventas, total: ventas.length));
  }

  @override
  Stream<List<VentaResumen>> observarTodas() => Stream.value(ventas);

  @override
  Future<VentaDetalle> obtenerDetalle(int id) =>
      throw UnimplementedError('la pantalla no abre el detalle');

  @override
  Future<VentaResumen> registrarVentaMostrador({
    required List<LineaVentaMostrador> lineas,
    required MetodoPago metodoPago,
    int? clienteId,
    int iva = 0,
    int descuento = 0,
  }) =>
      throw UnimplementedError('la pantalla no vende');

  /// Los ids que se mandaron anular. La pantalla no debe llamar sin que el
  /// usuario confirme.
  final List<int> anuladas = [];

  @override
  Future<void> anular(int id) async => anuladas.add(id);
}

Future<void> _montar(
  WidgetTester tester,
  _VentasFalsas ventas, {
  Set<Permiso> permisos = const {},
}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final auth = RepositorioAuthFalso();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositorioVentasProvider.overrideWithValue(ventas),
        repositorioAuthProvider.overrideWithValue(auth),
        repositorioAuthAnonimoProvider.overrideWithValue(auth),
        usuarioEnSesionProvider.overrideWithValue(usuarioDePrueba()),
        permisosSesionProvider.overrideWith((ref) => Stream.value(permisos)),
      ],
      child: const MaterialApp(home: Scaffold(body: HistorialVentasVista())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('la fila dice quién cobró, a quién y cuánto', (tester) async {
    await _montar(tester, _VentasFalsas(ventas: [_venta()]));

    expect(find.text('FAC-0001'), findsOneWidget);
    expect(find.text('Carlos Ramírez'), findsOneWidget);
    expect(find.text('Marta Ríos'), findsOneWidget);
    expect(find.text(r'$120.000'), findsOneWidget);
    expect(find.text('25/08/2026'), findsOneWidget);
    expect(find.text('14:05'), findsOneWidget);
  });

  testWidgets('una anulada se ve tachada, no desaparece', (tester) async {
    await _montar(
      tester,
      _VentasFalsas(ventas: [_venta(estado: EstadoPago.anulada)]),
    );

    final total = tester.widget<Text>(find.text(r'$120.000'));
    expect(total.style?.decoration, TextDecoration.lineThrough);
    // Dos veces: el chip del filtro y la celda de estado.
    expect(find.text('Anulada'), findsNWidgets(2));
  });

  testWidgets('«hasta» incluye el día entero', (tester) async {
    final ventas = _VentasFalsas(ventas: [_venta()]);
    await _montar(tester, ventas);

    ProviderScope.containerOf(
      tester.element(find.byType(HistorialVentasVista)),
    ).read(historialVentasProvider.notifier).filtrarPorFechas(
          hasta: DateTime(2026, 8, 25),
        );
    await tester.pumpAndSettle();

    final hasta = ventas.ultimoFiltro!.hasta!;
    expect(hasta.hour, 23);
    expect(hasta.minute, 59);
    expect(hasta.day, 25);
  });

  testWidgets('el estado llega al filtro y se quita al volver a tocarlo',
      (tester) async {
    final ventas = _VentasFalsas(ventas: [_venta()]);
    await _montar(tester, ventas);

    await tester.tap(find.text('Anulada').first);
    await tester.pumpAndSettle();
    expect(ventas.ultimoFiltro!.estado, EstadoPago.anulada);

    await tester.tap(find.text('Anulada').first);
    await tester.pumpAndSettle();
    expect(ventas.ultimoFiltro!.estado, isNull);
  });

  testWidgets('sin ventas lo dice y no ofrece quitar filtros', (tester) async {
    await _montar(tester, _VentasFalsas());

    expect(
      find.textContaining('Todavía no se ha vendido nada'),
      findsOneWidget,
    );
    expect(find.text('Quitar los filtros'), findsNothing);
  });

  group('deshacer una venta', () {
    testWidgets('sin POS_ANULAR no se ofrece ni devolver ni anular',
        (tester) async {
      await _montar(tester, _VentasFalsas(ventas: [_venta()]));

      expect(find.byTooltip('Recibir una devolución'), findsNothing);
      expect(find.byTooltip('Anular la venta entera'), findsNothing);
    });

    testWidgets('con POS_ANULAR aparecen las dos acciones', (tester) async {
      await _montar(
        tester,
        _VentasFalsas(ventas: [_venta()]),
        permisos: {Permiso.posAnular},
      );

      expect(find.byTooltip('Recibir una devolución'), findsOneWidget);
      expect(find.byTooltip('Anular la venta entera'), findsOneWidget);
    });

    testWidgets('una factura anulada ya no ofrece nada', (tester) async {
      await _montar(
        tester,
        _VentasFalsas(ventas: [_venta(estado: EstadoPago.anulada)]),
        permisos: {Permiso.posAnular},
      );

      expect(find.byTooltip('Recibir una devolución'), findsNothing);
      expect(find.byTooltip('Anular la venta entera'), findsNothing);
    });

    testWidgets('anular pide confirmación antes de tocar la base',
        (tester) async {
      final ventas = _VentasFalsas(ventas: [_venta()]);
      await _montar(tester, ventas, permisos: {Permiso.posAnular});

      await tester.tap(find.byTooltip('Anular la venta entera'));
      await tester.pumpAndSettle();

      // El diálogo está, pero todavía no se anuló nada.
      expect(find.text('¿Anular FAC-0001?'), findsOneWidget);
      expect(ventas.anuladas, isEmpty);

      await tester.tap(find.text('Anular'));
      await tester.pumpAndSettle();

      expect(ventas.anuladas, [1]);
    });

    testWidgets('lo devuelto se ve bajo el total, sin cambiarlo',
        (tester) async {
      await _montar(
        tester,
        _VentasFalsas(ventas: [_venta(total: 120000, devuelto: 30000)]),
      );

      // La factura sigue diciendo lo que se cobró...
      expect(find.text(r'$120.000'), findsOneWidget);
      // ...y aparte, cuánto volvió.
      expect(find.text(r'−$30.000 devuelto'), findsOneWidget);
    });
  });
}
