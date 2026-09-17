// El detalle de una factura, y lo que volvió de ella.
//
// `RepositorioDevoluciones.observarPorVenta` devolvía el documento con sus
// líneas y su autor, y no lo pintaba nadie: del historial solo se sabía el
// total devuelto, en letra chica bajo el importe. Quién recibió la devolución,
// por qué, y si la pieza volvió al estante, no se podían consultar.
//
// Lo que fijan estos tests:
//
// - la factura enseña sus líneas con el precio al que se cobró;
// - cada devolución dice su número, su motivo, quién la recibió y qué trajo;
// - la que **no** repuso stock lo avisa, porque esa pieza está apartada para
//   el proveedor y alguien tiene que acordarse;
// - una factura sin devoluciones no pinta el bloque: un «no hubo
//   devoluciones» solo alarga el diálogo de la venta corriente.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/devoluciones/enum/enum_devoluciones.dart';
import 'package:inventario_k1/backend/features/devoluciones/modelo/devolucion.dart';
import 'package:inventario_k1/backend/features/devoluciones/repositorio/repositorio_devoluciones.dart';
import 'package:inventario_k1/backend/features/pos/enum/enum_ventas.dart';
import 'package:inventario_k1/backend/features/pos/modelo/venta_detalle.dart';
import 'package:inventario_k1/backend/features/pos/modelo/venta_item.dart';
import 'package:inventario_k1/core/resultado.dart';
import 'package:inventario_k1/frontend/features/ventas/provider/devoluciones_providers.dart';
import 'package:inventario_k1/frontend/features/ventas/provider/historial_ventas_providers.dart';
import 'package:inventario_k1/frontend/features/ventas/widgets/dialogo_detalle_venta.dart';

VentaItem _item({
  int id = 1,
  String descripcion = 'Pastilla de freno',
  double cantidad = 2,
  int precio = 30000,
  TipoItem tipo = TipoItem.producto,
}) =>
    VentaItem(
      id: id,
      ventaId: 7,
      tipoItem: tipo,
      productoId: tipo == TipoItem.producto ? 3 : null,
      descripcion: descripcion,
      cantidad: cantidad,
      precioUnitario: precio,
      costoUnitario: 18000,
      subtotal: (cantidad * precio).round(),
    );

VentaDetalle _venta({List<VentaItem>? items, int descuento = 0}) {
  final lineas = items ?? [_item()];
  final subtotal = lineas.fold<int>(0, (suma, i) => suma + i.subtotal);

  return VentaDetalle(
    id: 7,
    numeroFactura: 'FAC-0012',
    tipo: TipoVenta.mostrador,
    clienteNombre: 'Carlos Ramírez',
    subtotal: subtotal,
    iva: 0,
    descuento: descuento,
    total: subtotal - descuento,
    totalPagado: subtotal - descuento,
    metodoPago: MetodoPago.efectivo,
    estadoPago: EstadoPago.pagado,
    creadoEn: DateTime(2026, 8, 25, 14, 5),
    items: lineas,
  );
}

Devolucion _devolucion({
  int id = 1,
  String numero = 'DEV-0003',
  MotivoDevolucion motivo = MotivoDevolucion.defectuoso,
  bool reingresaStock = false,
  int total = 30000,
  String? notas,
  List<DevolucionLinea>? lineas,
}) =>
    Devolucion(
      id: id,
      numero: numero,
      ventaId: 7,
      numeroFactura: 'FAC-0012',
      motivo: motivo,
      reingresaStock: reingresaStock,
      total: total,
      notas: notas,
      usuarioId: 2,
      recibidoPor: 'Marta Ríos',
      creadoEn: DateTime(2026, 8, 27, 9, 30),
      lineas: lineas ??
          const [
            DevolucionLinea(
              id: 1,
              ventaDetalleId: 1,
              productoId: 3,
              descripcion: 'Pastilla de freno',
              cantidad: 1,
              precioUnitario: 30000,
            ),
          ],
    );

/// Solo responde lo que el diálogo pregunta: las devoluciones de una venta.
class _DevolucionesFalsas implements RepositorioDevoluciones {
  _DevolucionesFalsas({this.documentos = const []});

  List<Devolucion> documentos;

  @override
  Stream<List<Devolucion>> observarPorVenta(int ventaId) =>
      Stream.value(documentos);

  @override
  Future<List<LineaDevolvible>> lineasDevolvibles(int ventaId) async => const [];

  @override
  Future<Resultado> registrar({
    required int ventaId,
    required MotivoDevolucion motivo,
    required List<LineaADevolver> lineas,
    bool? reingresaStock,
    String? notas,
  }) async =>
      const Exito();

  @override
  Future<Map<int, double>> devueltoPorLinea(int ventaId) async => const {};

  @override
  Stream<Map<int, int>> observarTotalDevueltoPorVenta() =>
      Stream.value(const {});

  @override
  Future<Map<int, int>> descuadres() async => const {};
}

Future<void> _montar(
  WidgetTester tester, {
  VentaDetalle? venta,
  List<Devolucion> devoluciones = const [],
}) async {
  tester.view.physicalSize = const Size(900, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ventaDetalleProvider(7).overrideWith((ref) async => venta ?? _venta()),
        repositorioDevolucionesProvider
            .overrideWithValue(_DevolucionesFalsas(documentos: devoluciones)),
      ],
      child: const MaterialApp(
        home: Scaffold(body: DialogoDetalleVenta(ventaId: 7)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('la factura', () {
    testWidgets('enseña su número, su cliente y sus líneas', (tester) async {
      await _montar(tester);

      expect(find.text('FAC-0012'), findsOneWidget);
      expect(find.text('Carlos Ramírez'), findsOneWidget);
      expect(find.text('Pastilla de freno'), findsOneWidget);
      // El precio al que se cobró, no el del catálogo de hoy.
      expect(find.textContaining(r'2 × $30.000'), findsOneWidget);
    });

    testWidgets('sin descuento no se pinta ese renglón', (tester) async {
      await _montar(tester);

      expect(find.text('Descuento'), findsNothing);
    });

    testWidgets('con descuento sí, y en negativo', (tester) async {
      await _montar(tester, venta: _venta(descuento: 5000));

      expect(find.text('Descuento'), findsOneWidget);
      expect(find.text(r'−$5.000'), findsOneWidget);
    });
  });

  group('las devoluciones', () {
    testWidgets('sin ninguna, el bloque no se pinta', (tester) async {
      await _montar(tester);

      expect(find.text('Devuelto'), findsNothing);
    });

    testWidgets('cada una dice número, motivo, quién y qué', (tester) async {
      await _montar(tester, devoluciones: [_devolucion()]);

      expect(find.text('Devuelto'), findsOneWidget);
      expect(
        find.text('DEV-0003 · ${MotivoDevolucion.defectuoso.etiqueta}'),
        findsOneWidget,
      );
      expect(find.textContaining('la recibió Marta Ríos'), findsOneWidget);
      expect(find.textContaining('27/08/2026'), findsOneWidget);
      expect(find.text('1 × Pastilla de freno'), findsOneWidget);
      expect(find.text(r'−$30.000'), findsOneWidget);
    });

    testWidgets('la que no repuso stock lo avisa', (tester) async {
      // Es lo único que le recuerda a alguien que esa pieza está apartada
      // esperando a que se le reclame al proveedor.
      await _montar(
        tester,
        devoluciones: [_devolucion(reingresaStock: false)],
      );

      expect(
        find.textContaining('No volvió al inventario'),
        findsOneWidget,
      );
    });

    testWidgets('la que sí repuso no dice nada', (tester) async {
      await _montar(
        tester,
        devoluciones: [
          _devolucion(
            motivo: MotivoDevolucion.equivocado,
            reingresaStock: true,
          ),
        ],
      );

      expect(find.textContaining('No volvió al inventario'), findsNothing);
    });

    testWidgets('una devolución de solo servicios no habla de inventario',
        (tester) async {
      // Un servicio no vuelve a ninguna estantería, así que avisar de que «no
      // volvió al inventario» sería ruido: nunca podía volver.
      await _montar(
        tester,
        venta: _venta(
          items: [_item(descripcion: 'Sincronización', tipo: TipoItem.servicio)],
        ),
        devoluciones: [
          _devolucion(
            reingresaStock: false,
            lineas: const [
              DevolucionLinea(
                id: 1,
                ventaDetalleId: 1,
                descripcion: 'Sincronización',
                cantidad: 1,
                precioUnitario: 30000,
              ),
            ],
          ),
        ],
      );

      expect(find.textContaining('No volvió al inventario'), findsNothing);
    });

    testWidgets('varias devoluciones suman en el encabezado', (tester) async {
      await _montar(
        tester,
        devoluciones: [
          _devolucion(id: 1, numero: 'DEV-0003', total: 30000),
          _devolucion(id: 2, numero: 'DEV-0004', total: 15000),
        ],
      );

      expect(find.text('DEV-0003 · Llegó defectuosa'), findsOneWidget);
      expect(find.text('DEV-0004 · Llegó defectuosa'), findsOneWidget);
      expect(find.text(r'$45.000'), findsOneWidget);
    });
  });
}
