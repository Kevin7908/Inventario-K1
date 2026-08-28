// Widgets extendidos y creados al migrar Clientes a share2.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/clientes/modelo/cliente.dart';
import 'package:inventario_k1/frontend/features/clientes/widgets/tarjeta_cliente.dart';
import 'package:inventario_k1/frontend/share2/share2.dart';

Widget _envolver(Widget child) => MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(width: 320, child: child),
        ),
      ),
    );

Cliente _cliente({
  String nombres = 'Carlos',
  String? apellidos = 'Ramírez',
  String? telefono = '300 555 1234',
  bool activo = true,
}) =>
    Cliente(
      id: 1,
      nombres: nombres,
      apellidos: apellidos,
      telefono: telefono,
      activo: activo,
    );

/// Decoración del cuadro del marcador, para inspeccionar fondo y degradado.
BoxDecoration _decoracionMarcador(WidgetTester tester) {
  final contenedor = tester.widget<Container>(
    find.descendant(
      of: find.byType(MarcadorIdentidad),
      matching: find.byType(Container),
    ),
  );
  return contenedor.decoration! as BoxDecoration;
}

void main() {
  group('MarcadorIdentidad', () {
    testWidgets('sin colorFondoFin pinta un fondo plano', (tester) async {
      await tester.pumpWidget(_envolver(
        const MarcadorIdentidad(
          inicial: 'CR',
          colorFondo: ColoresApp.goGreen,
        ),
      ));

      final decoracion = _decoracionMarcador(tester);
      expect(decoracion.color, ColoresApp.goGreen);
      expect(decoracion.gradient, isNull);
    });

    testWidgets('con colorFondoFin pinta un degradado diagonal y deja el '
        'color plano en null', (tester) async {
      await tester.pumpWidget(_envolver(
        const MarcadorIdentidad(
          inicial: 'CR',
          colorFondo: ColoresApp.goGreen,
          colorFondoFin: ColoresApp.castletonGreen,
        ),
      ));

      final decoracion = _decoracionMarcador(tester);
      // `BoxDecoration` revienta si recibe `color` y `gradient` a la vez.
      expect(decoracion.color, isNull);

      final degradado = decoracion.gradient! as LinearGradient;
      expect(degradado.colors, [ColoresApp.goGreen, ColoresApp.castletonGreen]);
      expect(degradado.begin, Alignment.topLeft);
      expect(degradado.end, Alignment.bottomRight);
    });
  });

  group('PanelSeccion', () {
    testWidgets('la acción va en el encabezado, a la derecha del título',
        (tester) async {
      await tester.pumpWidget(_envolver(
        PanelSeccion(
          titulo: 'Motos',
          accion: BotonSecundario(etiqueta: 'Agregar moto', alPresionar: () {}),
          child: const Text('contenido'),
        ),
      ));

      final titulo = tester.getCenter(find.text('Motos'));
      final accion = tester.getCenter(find.text('Agregar moto'));
      final contenido = tester.getCenter(find.text('contenido'));

      expect(accion.dx, greaterThan(titulo.dx));
      expect((accion.dy - titulo.dy).abs(), lessThan(20),
          reason: 'la acción comparte fila con el título');
      expect(contenido.dy, greaterThan(accion.dy));
    });

    testWidgets('sin acción el título sigue en su sitio', (tester) async {
      await tester.pumpWidget(_envolver(
        const PanelSeccion(titulo: 'Contacto', child: Text('contenido')),
      ));

      expect(find.text('Contacto'), findsOneWidget);
      expect(find.byType(BotonSecundario), findsNothing);
    });
  });

  group('TarjetaCliente', () {
    testWidgets('un cliente al día se marca en verde, sin monto',
        (tester) async {
      await tester.pumpWidget(_envolver(
        TarjetaCliente(cliente: _cliente(), motos: (cantidad: 1, principal: 'Honda CB110')),
      ));

      expect(find.text('Al día'), findsOneWidget);

      final badge = tester.widget<IndicadorEstado>(
        find.widgetWithText(IndicadorEstado, 'Al día'),
      );
      expect(badge.color, ColoresApp.statusSuccess);
      expect(badge.colorFondo, ColoresApp.statusSuccessBg);
    });

    testWidgets('un cliente que debe muestra el monto real en rojo',
        (tester) async {
      await tester.pumpWidget(_envolver(
        TarjetaCliente(
          cliente: _cliente(),
          motos: (cantidad: 1, principal: 'Honda CB110'),
          saldo: (pendiente: 250000, deudas: 2),
        ),
      ));

      expect(find.text('Al día'), findsNothing);
      expect(find.text('\$250.000'), findsOneWidget);

      final badge = tester.widget<IndicadorEstado>(
        find.widgetWithText(IndicadorEstado, '\$250.000'),
      );
      expect(badge.color, ColoresApp.statusDanger);
      expect(badge.colorFondo, ColoresApp.statusDangerBg);
    });

    testWidgets('solo el cliente inactivo lleva badge', (tester) async {
      await tester.pumpWidget(_envolver(
        TarjetaCliente(cliente: _cliente(activo: false)),
      ));

      final badge = tester.widget<IndicadorEstado>(
        find.widgetWithText(IndicadorEstado, 'Inactivo'),
      );
      expect(badge.color, ColoresApp.statusNeutral);
      expect(badge.colorFondo, ColoresApp.statusNeutralBg);

      // Que un cliente siga siendo cliente es lo normal: sin badge. El único
      // `IndicadorEstado` que queda es el del saldo, en el pie.
      await tester.pumpWidget(_envolver(TarjetaCliente(cliente: _cliente())));

      expect(find.text('Inactivo'), findsNothing);
      expect(find.byType(IndicadorEstado), findsOneWidget);
    });

    testWidgets('la franja de motos singulariza el conteo', (tester) async {
      await tester.pumpWidget(_envolver(
        TarjetaCliente(
          cliente: _cliente(),
          motos: (cantidad: 1, principal: 'Honda CB110 · HRT88D'),
        ),
      ));

      expect(find.text('Honda CB110 · HRT88D'), findsOneWidget);
      expect(find.text('1 moto'), findsOneWidget);

      await tester.pumpWidget(_envolver(
        TarjetaCliente(
          cliente: _cliente(),
          motos: (cantidad: 3, principal: 'AKT 125 · LPQ04A'),
        ),
      ));

      expect(find.text('3 motos'), findsOneWidget);
    });

    testWidgets('sin motos lo dice, en vez de dejar la franja vacía',
        (tester) async {
      await tester.pumpWidget(_envolver(TarjetaCliente(cliente: _cliente())));

      expect(find.text('Sin motos registradas'), findsOneWidget);
      expect(find.text('0 motos'), findsOneWidget);
    });

    testWidgets('el avatar usa las iniciales del nombre completo',
        (tester) async {
      await tester.pumpWidget(_envolver(TarjetaCliente(cliente: _cliente())));

      expect(find.text('CR'), findsOneWidget);
    });
  });
}
