// Las piezas del módulo de Cuentas por cobrar y las dos que salieron a share
// al migrarlo.
//
// Lo que fijan estos tests no es cómo se ve, sino las tres reglas que se
// pueden romper sin que el analizador diga nada: que «vencida» sea el
// calendario y no la columna, que el saldo de una deuda se pinte distinto que
// el de una reserva, y que el formulario de abono no deje cobrar de más.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/deudores/enum/enum_deudor.dart';
import 'package:inventario_k1/backend/features/deudores/modelo/deudor_item.dart';
import 'package:inventario_k1/backend/features/deudores/modelo/deudor_resumen.dart';
import 'package:inventario_k1/core/formato.dart';
import 'package:inventario_k1/frontend/features/deudores/deuda_detalle/widgets/linea_deuda.dart';
import 'package:inventario_k1/frontend/features/deudores/deuda_detalle/widgets/pie_deuda.dart';
import 'package:inventario_k1/frontend/features/deudores/widgets/estado_deuda_ui.dart';
import 'package:inventario_k1/frontend/share/share.dart';

Future<void> _pump(WidgetTester tester, Widget hijo) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SizedBox(width: 360, child: hijo)),
      ),
    );

DeudorResumen _deuda({
  EstadoDeudor estado = EstadoDeudor.activa,
  int total = 100000,
  int pagado = 40000,
  DateTime? vence,
}) =>
    DeudorResumen(
      id: 7,
      numero: 'DEU-0007',
      clienteId: 1,
      nombreCliente: 'Carlos Ramírez',
      concepto: 'Kit de arrastre',
      montoTotal: total,
      montoPagado: pagado,
      estado: estado,
      fechaVencimiento: vence,
      creadoEn: DateTime(2026, 8, 1),
    );

DateTime _haceDias(int dias) => DateTime.now().subtract(Duration(days: dias));

DeudorItem _linea({double cantidad = 2}) => DeudorItem(
      id: 1,
      deudorId: 7,
      productoId: 3,
      nombreProducto: 'Pastilla de freno',
      sku: 'FRE-1123',
      cantidad: cantidad,
      precioUnitario: 30000,
    );

void main() {
  group('la situación de una deuda no es su columna estado', () {
    test('activa con el plazo cumplido se lee «Vencida»', () {
      final deuda = _deuda(vence: _haceDias(2));

      expect(deuda.estado, EstadoDeudor.activa);
      expect(situacionDe(deuda), SituacionDeuda.vencida);
    });

    test('activa dentro del plazo se lee «Al día»', () {
      final deuda = _deuda(vence: DateTime.now().add(const Duration(days: 5)));

      expect(situacionDe(deuda), SituacionDeuda.alDia);
    });

    test('sin plazo pactado nunca vence', () {
      expect(situacionDe(_deuda()), SituacionDeuda.alDia);
    });

    test('marcada VENCIDA se lee vencida aunque falte para la fecha', () {
      // La marca la pone el usuario cuando da la deuda por vencida antes de
      // tiempo. Es lo único que la columna aporta sobre el calendario.
      final deuda = _deuda(
        estado: EstadoDeudor.vencida,
        vence: DateTime.now().add(const Duration(days: 30)),
      );

      expect(situacionDe(deuda), SituacionDeuda.vencida);
    });

    test('cobrada o dada por perdida ya no vence', () {
      expect(
        situacionDe(_deuda(
          estado: EstadoDeudor.pagada,
          pagado: 100000,
          vence: _haceDias(90),
        )),
        SituacionDeuda.pagada,
      );
      expect(
        situacionDe(_deuda(
          estado: EstadoDeudor.incobrable,
          vence: _haceDias(90),
        )),
        SituacionDeuda.incobrable,
      );
    });

    testWidgets('el badge dice la situación, no el enum', (tester) async {
      await _pump(tester, BadgeSituacionDeuda(deuda: _deuda(vence: _haceDias(1))));

      expect(find.text('Vencida'), findsOneWidget);
      expect(find.text('Activa'), findsNothing);
    });
  });

  group('PieDeuda', () {
    Color colorDe(WidgetTester tester, String texto) =>
        tester.widget<Text>(find.text(texto)).style!.color!;

    testWidgets('reparte deuda, cobrado y saldo', (tester) async {
      await _pump(
        tester,
        const PieDeuda(
          total: 100000,
          pagado: 40000,
          colorAvance: ColoresApp.goGreen,
        ),
      );

      expect(find.text(r'$100.000'), findsOneWidget);
      expect(find.text(r'$40.000'), findsOneWidget);
      expect(find.text(r'$60.000'), findsOneWidget);
      expect(find.text('40 % cobrado'), findsOneWidget);
    });

    testWidgets('el saldo va en rojo, al revés que en una reserva',
        (tester) async {
      // Es la diferencia que justifica que cada módulo arme su pie: un
      // apartado a medio pagar está en su estado normal y va en ámbar; una
      // deuda a medio cobrar es plata en la calle.
      await _pump(
        tester,
        const PieDeuda(
          total: 100000,
          pagado: 40000,
          colorAvance: ColoresApp.goGreen,
        ),
      );

      expect(colorDe(tester, r'$60.000'), ColoresApp.statusDanger);
      expect(colorDe(tester, r'$40.000'), ColoresApp.statusSuccess);
    });

    testWidgets('sin saldo la cifra se apaga en vez de seguir en rojo',
        (tester) async {
      await _pump(
        tester,
        const PieDeuda(
          total: 50000,
          pagado: 50000,
          colorAvance: ColoresApp.statusSuccess,
        ),
      );

      expect(colorDe(tester, r'$0'), ColoresApp.textMuted);
      expect(find.text('Cobrada del todo'), findsOneWidget);
    });

    testWidgets('sin callbacks no ofrece cerrar ni reabrir', (tester) async {
      // Es lo que se ve en una deuda ya cobrada: las cuentas se leen, pero no
      // hay nada más que hacerle.
      await _pump(
        tester,
        const PieDeuda(
          total: 50000,
          pagado: 50000,
          colorAvance: ColoresApp.statusSuccess,
        ),
      );

      expect(find.text('Dar por perdida'), findsNothing);
      expect(find.text('Volver a cobrarla'), findsNothing);
    });

    testWidgets('dar por perdida avisa por su callback', (tester) async {
      var perdida = false;
      await _pump(
        tester,
        PieDeuda(
          total: 100000,
          pagado: 0,
          colorAvance: ColoresApp.statusDanger,
          alDarPorPerdida: () => perdida = true,
        ),
      );

      await tester.tap(find.text('Dar por perdida'));
      await tester.pump();

      expect(perdida, isTrue);
    });
  });

  group('FormularioAbono', () {
    Widget formulario({
      required int saldo,
      bool habilitado = true,
      void Function(int, String, String?)? alRegistrar,
    }) =>
        FormularioAbono<String>(
          saldo: saldo,
          habilitado: habilitado,
          metodos: const ['Efectivo', 'Nequi'],
          metodoInicial: 'Efectivo',
          constructorEtiqueta: (m) => m,
          formatearImporte: formatearPrecio,
          textoSaldado: 'No queda saldo: esta deuda ya está cobrada.',
          alRegistrar: alRegistrar ?? (_, _, _) {},
        );

    testWidgets('sin saldo se reemplaza por el aviso', (tester) async {
      await _pump(tester, formulario(saldo: 0));

      expect(find.text('No queda saldo: esta deuda ya está cobrada.'),
          findsOneWidget);
      expect(find.text('Registrar abono'), findsOneWidget,
          reason: 'solo queda el título de la sección, no el botón');
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('el monto en blanco deja el botón apagado', (tester) async {
      var registros = 0;
      await _pump(
        tester,
        formulario(saldo: 60000, alRegistrar: (_, _, _) => registros++),
      );

      await tester.tap(find.text('Registrar abono').last);
      await tester.pump();

      expect(registros, 0);
    });

    testWidgets('pasarse del saldo no registra y lo dice con la diferencia',
        (tester) async {
      var registros = 0;
      await _pump(
        tester,
        formulario(saldo: 60000, alRegistrar: (_, _, _) => registros++),
      );

      await tester.enterText(find.byType(TextField).first, '75000');
      await tester.pump();

      expect(find.textContaining(r'$15.000 de más'), findsOneWidget);
      await tester.tap(find.text('Registrar abono').last);
      await tester.pump();
      expect(registros, 0);
    });

    testWidgets('«Todo el saldo» teclea la cifra que falta', (tester) async {
      int? cobrado;
      await _pump(
        tester,
        formulario(saldo: 60000, alRegistrar: (m, _, _) => cobrado = m),
      );

      await tester.tap(find.text('Todo el saldo'));
      await tester.pump();
      await tester.tap(find.text('Registrar abono').last);
      await tester.pump();

      expect(cobrado, 60000);
    });

    testWidgets('registrar limpia el formulario para el siguiente abono',
        (tester) async {
      await _pump(tester, formulario(saldo: 60000));

      await tester.enterText(find.byType(TextField).first, '20000');
      await tester.pump();
      await tester.tap(find.text('Registrar abono').last);
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        isEmpty,
      );
    });

    testWidgets('un documento cerrado se lee pero no se cobra', (tester) async {
      var registros = 0;
      await _pump(
        tester,
        formulario(
          saldo: 60000,
          habilitado: false,
          alRegistrar: (_, _, _) => registros++,
        ),
      );

      await tester.tap(find.text('Todo el saldo'));
      await tester.pump();
      await tester.tap(find.text('Registrar abono').last);
      await tester.pump();

      expect(registros, 0);
      expect(find.textContaining(r'Faltan $60.000'), findsOneWidget);
    });
  });

  group('LineaDeuda', () {
    testWidgets('muestra el repuesto, su SKU y el precio unitario',
        (tester) async {
      await _pump(
        tester,
        LineaDeuda(
          linea: _linea(),
          editable: true,
          alCambiarCantidad: (_) {},
          alEliminar: () {},
        ),
      );

      expect(find.text('Pastilla de freno'), findsOneWidget);
      expect(find.text('FRE-1123'), findsOneWidget);
      // El unitario, no el subtotal: es lo que se compara con el catálogo.
      expect(find.text(r'$30.000'), findsOneWidget);
    });

    testWidgets('el − con cantidad 1 quita la línea', (tester) async {
      // Bajar de 1 a 0 es la única forma de quitarla: el diseño no tiene
      // papelera. Y quitarla devuelve el repuesto al estante, porque
      // significa que nunca debió anotarse.
      var quitada = false;
      var cantidades = <double>[];
      await _pump(
        tester,
        LineaDeuda(
          linea: _linea(cantidad: 1),
          editable: true,
          alCambiarCantidad: cantidades.add,
          alEliminar: () => quitada = true,
        ),
      );

      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();

      expect(quitada, isTrue);
      expect(cantidades, isEmpty, reason: 'no se pide cantidad 0');
    });

    testWidgets('el tope de stock apaga el +', (tester) async {
      // Fiar saca la mercancía de verdad: no se puede fiar lo que no hay, y
      // el repositorio lo rechaza. El control avisa antes de intentarlo.
      var cantidades = <double>[];
      await _pump(
        tester,
        LineaDeuda(
          linea: _linea(cantidad: 3),
          editable: true,
          disponible: 3,
          alCambiarCantidad: cantidades.add,
          alEliminar: () {},
        ),
      );

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();

      expect(cantidades, isEmpty);
    });

    testWidgets('una deuda cerrada se ve pero no se toca', (tester) async {
      var cantidades = <double>[];
      var quitada = false;
      await _pump(
        tester,
        LineaDeuda(
          linea: _linea(),
          editable: false,
          alCambiarCantidad: cantidades.add,
          alEliminar: () => quitada = true,
        ),
      );

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();

      expect(cantidades, isEmpty);
      expect(quitada, isFalse);
      expect(find.text('Pastilla de freno'), findsOneWidget);
    });
  });
}
