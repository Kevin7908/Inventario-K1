// Las piezas nuevas del módulo de Reservas: la barra de avance que salió a
// share2 y el pie de cuentas, que es lo único del panel derecho que no es
// igual al de los otros tres documentos.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/reservas/enum/enum_reserva.dart';
import 'package:inventario_k1/backend/features/reservas/modelo/reserva_item.dart';
import 'package:inventario_k1/backend/features/reservas/modelo/reserva_resumen.dart';
import 'package:inventario_k1/frontend/features/reservas/reserva_detalle/widgets/linea_reserva.dart';
import 'package:inventario_k1/frontend/features/reservas/reserva_detalle/widgets/pie_reserva.dart';
import 'package:inventario_k1/frontend/share2/share2.dart';

Future<void> _pump(WidgetTester tester, Widget hijo) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SizedBox(width: 360, child: hijo)),
      ),
    );

ReservaItem _item({double cantidad = 2}) => ReservaItem(
      id: 1,
      reservaId: 9,
      productoId: 7,
      nombreProducto: 'Aceite Motul 20W50',
      sku: 'SKU-1123',
      cantidad: cantidad,
      precioUnitario: 32000,
    );

ReservaResumen _resumen({int total = 100000, int pagado = 40000}) =>
    ReservaResumen(
      id: 9,
      numero: 'RES-0009',
      clienteId: 1,
      nombreCliente: 'Carlos Ramírez',
      estado: EstadoReserva.activa,
      totalReserva: total,
      pagadoAcumulado: pagado,
      creadoEn: DateTime(2026, 8, 1),
    );

void main() {
  group('BarraProgreso', () {
    testWidgets('el relleno ocupa la fracción que se le pasa', (tester) async {
      await _pump(
        tester,
        const SizedBox(
          width: 200,
          child: BarraProgreso(progreso: 0.25, color: ColoresApp.goGreen),
        ),
      );

      final relleno = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(relleno.widthFactor, 0.25);
    });

    testWidgets('un progreso imposible se acota en vez de desbordar',
        (tester) async {
      // Pasa por redondeo: 100.001 pagados de 100.000 da 1.00001.
      await _pump(
        tester,
        const SizedBox(
          width: 200,
          child: BarraProgreso(progreso: 1.4, color: ColoresApp.goGreen),
        ),
      );

      expect(tester.takeException(), isNull);
      final relleno = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(relleno.widthFactor, 1.0);
    });

    testWidgets('en cero no pinta relleno pero conserva el canal',
        (tester) async {
      await _pump(
        tester,
        const SizedBox(
          width: 200,
          child: BarraProgreso(progreso: 0, color: ColoresApp.goGreen),
        ),
      );

      final relleno = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(relleno.widthFactor, 0);
      expect(tester.getSize(find.byType(BarraProgreso)).height, 8);
    });
  });

  group('PieReserva', () {
    testWidgets('reparte total, pagado y saldo', (tester) async {
      await _pump(tester, const PieReserva(total: 100000, pagado: 40000));

      expect(find.text(r'$100.000'), findsNWidgets(2)); // la fila y el total
      expect(find.text(r'$40.000'), findsOneWidget);
      expect(find.text(r'$60.000'), findsOneWidget);
      expect(find.text('40 % pagado'), findsOneWidget);
    });

    testWidgets('sin nada pagado el saldo es el total', (tester) async {
      await _pump(tester, const PieReserva(total: 12000, pagado: 0));

      expect(find.text(r'$0'), findsOneWidget);
      expect(find.text('0 % pagado'), findsOneWidget);
    });

    testWidgets('una reserva sin líneas no divide por cero', (tester) async {
      // Es el estado en que nace: creada y todavía vacía.
      await _pump(tester, const PieReserva(total: 0, pagado: 0));

      expect(tester.takeException(), isNull);
      expect(find.text('0 % pagado'), findsOneWidget);
    });

    testWidgets('sin callbacks no ofrece cerrar la reserva', (tester) async {
      // Es lo que se ve en una reserva ya completada o cancelada: las cuentas
      // se leen, pero no hay nada más que hacerle.
      await _pump(tester, const PieReserva(total: 100000, pagado: 40000));

      expect(find.text('Cancelar reserva'), findsNothing);
      expect(find.text('Marcar entregada'), findsNothing);
    });

    testWidgets('entregar va encima de cancelar', (tester) async {
      // El orden importa: entregar es el cierre normal y cancelar el que
      // deshace. Poner primero el destructivo invita a errarle.
      await _pump(
        tester,
        PieReserva(
          total: 100000,
          pagado: 40000,
          alEntregar: () {},
          alCancelar: () {},
        ),
      );

      final entregar = tester.getCenter(find.text('Marcar entregada'));
      final cancelar = tester.getCenter(find.text('Cancelar reserva'));
      expect(entregar.dy, lessThan(cancelar.dy));
    });

    testWidgets('el botón de entregar avisa por su callback', (tester) async {
      var entregada = false;
      await _pump(
        tester,
        PieReserva(
          total: 100000,
          pagado: 100000,
          alEntregar: () => entregada = true,
        ),
      );

      await tester.tap(find.text('Marcar entregada'));
      await tester.pump();

      expect(entregada, isTrue);
      expect(find.text('Cancelar reserva'), findsNothing);
    });

    testWidgets('con callback el botón cancela', (tester) async {
      var cancelada = false;
      await _pump(
        tester,
        PieReserva(
          total: 100000,
          pagado: 40000,
          alCancelar: () => cancelada = true,
        ),
      );

      await tester.tap(find.text('Cancelar reserva'));
      await tester.pump();

      expect(cancelada, isTrue);
    });
  });

  group('los colores del pie salen de la paleta', () {
    // El bloque de cuentas es lo único del panel derecho que no se parece a
    // los otros tres documentos, así que es donde más fácil se cuela un color
    // inventado. Estos tests fijan los tres que importan.

    Color colorDe(WidgetTester tester, String texto) =>
        tester.widget<Text>(find.text(texto)).style!.color!;

    testWidgets('el total va en el verde de marca, como en PieTotales',
        (tester) async {
      await _pump(tester, const PieReserva(total: 100000, pagado: 40000));

      // El importe grande del pie: el segundo `$100.000` de la pantalla.
      final total = tester.widgetList<Text>(find.text(r'$100.000')).last;
      expect(total.style?.color, ColoresApp.castletonGreen);
    });

    testWidgets('lo pagado va en verde y el saldo en ámbar', (tester) async {
      await _pump(tester, const PieReserva(total: 100000, pagado: 40000));

      expect(colorDe(tester, r'$40.000'), ColoresApp.statusSuccess);
      // Ámbar, no rojo: deber de un apartado es el estado normal, no un error.
      expect(colorDe(tester, r'$60.000'), ColoresApp.statusWarning);
    });

    testWidgets('sin saldo la cifra se apaga en vez de seguir en ámbar',
        (tester) async {
      await _pump(tester, const PieReserva(total: 50000, pagado: 50000));

      expect(colorDe(tester, r'$0'), ColoresApp.textMuted);
    });
  });

  group('LineaReserva', () {
    testWidgets('muestra el producto, su SKU y el precio unitario',
        (tester) async {
      await _pump(
        tester,
        LineaReserva(
          linea: _item(cantidad: 3),
          editable: true,
          alCambiarCantidad: (_) {},
          alEliminar: () {},
        ),
      );

      expect(find.text('Aceite Motul 20W50'), findsOneWidget);
      expect(find.text('SKU-1123'), findsOneWidget);
      // El unitario, no el subtotal: 3 x 32.000 se lee en el pie.
      expect(find.text(r'$32.000'), findsOneWidget);
      expect(find.text(r'$96.000'), findsNothing);
    });

    testWidgets('el − con cantidad 1 quita la línea', (tester) async {
      var eliminada = false;
      await _pump(
        tester,
        LineaReserva(
          linea: _item(cantidad: 1),
          editable: true,
          alCambiarCantidad: (_) {},
          alEliminar: () => eliminada = true,
        ),
      );

      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();

      expect(eliminada, isTrue);
    });

    testWidgets('el tope de stock apaga el +', (tester) async {
      // Quedan 0 en bodega y la línea ya apartó 2: el tope son 2.
      await _pump(
        tester,
        LineaReserva(
          linea: _item(cantidad: 2),
          editable: true,
          disponible: 2,
          alCambiarCantidad: (_) {},
          alEliminar: () {},
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

    testWidgets('una reserva cerrada se ve pero no se toca', (tester) async {
      await _pump(
        tester,
        LineaReserva(
          linea: _item(),
          editable: false,
          alCambiarCantidad: (_) {},
          alEliminar: () {},
        ),
      );

      final control =
          tester.widget<ControlCantidad>(find.byType(ControlCantidad));
      expect(control.alCambiar, isNull);
    });
  });

  group('el saldo de la reserva es derivado, no una columna', () {
    test('pagada solo cuando no falta nada', () {
      expect(_resumen(total: 100000, pagado: 40000).pagada, isFalse);
      expect(_resumen(total: 100000, pagado: 100000).pagada, isTrue);
    });

    test('una reserva vacía no cuenta como pagada', () {
      // Total 0 y pagado 0 cumpliría `pagado >= total`, pero no hay nada
      // apartado: decir «Pagada» ahí sería mentir.
      expect(_resumen(total: 0, pagado: 0).pagada, isFalse);
    });

    test('el saldo nunca es negativo', () {
      expect(_resumen(total: 50000, pagado: 50000).saldo, 0);
    });
  });
}
