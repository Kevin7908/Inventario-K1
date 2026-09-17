// Widgets creados al migrar Motos: la tarjeta del catálogo y el selector con
// buscador que se agregó a share para elegir dueño.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/motos/modelo/moto.dart';
import 'package:inventario_k1/frontend/features/motos/widgets/tarjeta_moto.dart';
import 'package:inventario_k1/frontend/share/share.dart';

Widget _envolver(Widget child) => MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(width: 320, child: child),
        ),
      ),
    );

Moto _moto({
  String marca = 'Bajaj',
  String modelo = 'Pulsar NS200',
  String? placa = 'KMN12C',
  String? nombreCliente = 'Carlos Ramírez',
  int? anio = 2022,
  int? cilindraje = 200,
  String? color = 'Rojo',
  bool activo = true,
}) =>
    Moto(
      id: 1,
      clienteId: 1,
      nombreCliente: nombreCliente,
      marcaId: 1,
      marca: marca,
      modeloId: 1,
      modelo: modelo,
      placa: placa,
      anio: anio,
      cilindraje: cilindraje,
      color: color,
      activo: activo,
      creadoEn: DateTime(2026),
      actualizadoEn: DateTime(2026),
    );

void main() {
  group('TarjetaMoto', () {
    testWidgets('muestra marca, modelo, placa, dueño y ficha técnica',
        (tester) async {
      await tester.pumpWidget(_envolver(
        TarjetaMoto(moto: _moto(), alEditar: () {}, alEliminar: () {}),
      ));

      expect(find.text('Bajaj Pulsar NS200'), findsOneWidget);
      expect(find.text('KMN12C'), findsOneWidget);
      expect(find.text('Carlos Ramírez'), findsOneWidget);
      expect(find.text('2022 · 200 cc · Rojo'), findsOneWidget);
    });

    testWidgets('los huecos se nombran en vez de quedar mudos', (tester) async {
      await tester.pumpWidget(_envolver(
        TarjetaMoto(
          moto: _moto(
            placa: null,
            nombreCliente: null,
            anio: null,
            cilindraje: null,
            color: null,
          ),
          alEditar: () {},
          alEliminar: () {},
        ),
      ));

      expect(find.text('Sin placa'), findsOneWidget);
      expect(find.text('Sin dueño registrado'), findsOneWidget);
      expect(find.text('Sin ficha técnica'), findsOneWidget);
    });

    testWidgets('solo la moto dada de baja lleva badge', (tester) async {
      await tester.pumpWidget(_envolver(
        TarjetaMoto(
          moto: _moto(activo: false),
          alEditar: () {},
          alEliminar: () {},
        ),
      ));

      final badge = tester.widget<IndicadorEstado>(
        find.widgetWithText(IndicadorEstado, 'Inactiva'),
      );
      expect(badge.color, ColoresApp.statusNeutral);

      await tester.pumpWidget(_envolver(
        TarjetaMoto(moto: _moto(), alEditar: () {}, alEliminar: () {}),
      ));

      expect(find.byType(IndicadorEstado), findsNothing);
    });

    testWidgets('los botones de la tarjeta avisan a quién corresponde',
        (tester) async {
      var editadas = 0;
      var eliminadas = 0;

      await tester.pumpWidget(_envolver(
        TarjetaMoto(
          moto: _moto(),
          alEditar: () => editadas++,
          alEliminar: () => eliminadas++,
        ),
      ));

      await tester.tap(find.byTooltip('Editar moto'));
      await tester.tap(find.byTooltip('Eliminar moto'));

      expect(editadas, 1);
      expect(eliminadas, 1);
    });
  });

  group('CampoBusqueda', () {
    /// Campo montado sobre un `StatefulBuilder` para que elegir una opción se
    /// refleje de verdad, como en un formulario real.
    Widget campo({
      String? Function(String?)? validador,
      GlobalKey<FormState>? formKey,
      void Function(String?)? alCambiar,
    }) {
      String? seleccion;
      return MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Form(
              key: formKey,
              child: CampoBusqueda<String>(
                etiqueta: 'Dueño',
                valor: seleccion,
                opciones: const ['Carlos Ramírez', 'Diana Cardona'],
                constructorEtiqueta: (c) => c,
                constructorDetalle: (c) =>
                    c.startsWith('Carlos') ? '300 555 1234' : '311 222 8890',
                placeholder: 'Elegir cliente…',
                validador: validador,
                alCambiar: (c) {
                  alCambiar?.call(c);
                  setState(() => seleccion = c);
                },
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('sin selección muestra el placeholder', (tester) async {
      await tester.pumpWidget(campo());

      expect(find.text('Elegir cliente…'), findsOneWidget);
      expect(find.text('Carlos Ramírez'), findsNothing);
    });

    testWidgets('el cuadro filtra por etiqueta y por detalle', (tester) async {
      await tester.pumpWidget(campo());

      await tester.tap(find.text('Elegir cliente…'));
      await tester.pumpAndSettle();

      expect(find.text('Carlos Ramírez'), findsOneWidget);
      expect(find.text('Diana Cardona'), findsOneWidget);

      // Por etiqueta.
      await tester.enterText(find.byType(TextField).last, 'diana');
      await tester.pumpAndSettle();
      expect(find.text('Carlos Ramírez'), findsNothing);
      expect(find.text('Diana Cardona'), findsOneWidget);

      // Por detalle: el teléfono no está en el texto principal.
      await tester.enterText(find.byType(TextField).last, '300 555');
      await tester.pumpAndSettle();
      expect(find.text('Carlos Ramírez'), findsOneWidget);
      expect(find.text('Diana Cardona'), findsNothing);
    });

    testWidgets('elegir una opción la reporta y la deja en el campo',
        (tester) async {
      String? elegido;
      await tester.pumpWidget(campo(alCambiar: (c) => elegido = c));

      await tester.tap(find.text('Elegir cliente…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Diana Cardona'));
      await tester.pumpAndSettle();

      expect(elegido, 'Diana Cardona');
      expect(find.text('Diana Cardona'), findsOneWidget);
      expect(find.text('Elegir cliente…'), findsNothing);
    });

    testWidgets('participa de la validación del Form que lo contiene',
        (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(campo(
        formKey: formKey,
        validador: (v) => v == null ? 'Elige un cliente.' : null,
      ));

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Elige un cliente.'), findsOneWidget);

      await tester.tap(find.text('Elegir cliente…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Carlos Ramírez'));
      await tester.pumpAndSettle();

      expect(formKey.currentState!.validate(), isTrue);
    });
  });
}
