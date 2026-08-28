// ControlCantidad: los botones, el número editable y quién manda sobre el valor.
//
// Lo que más importa es que el widget **no decide**: el padre es la fuente de
// verdad. Si rechaza un cambio, el campo tiene que volver a lo que el padre
// dice, no quedarse mostrando lo que se tecleó.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/frontend/share2/share2.dart';

/// Envoltorio que se comporta como un padre real: guarda la cantidad y la
/// devuelve por parámetro, igual que hace un notifier.
class _Padre extends StatefulWidget {
  const _Padre({
    this.inicial = 1,
    this.maximo,
    this.permitirDecimales = false,
    this.aceptar,
  });

  final double inicial;
  final double? maximo;
  final bool permitirDecimales;

  /// Si devuelve `false`, el padre ignora el cambio: sirve para comprobar que
  /// el campo se vuelve a sincronizar.
  final bool Function(double)? aceptar;

  @override
  State<_Padre> createState() => _PadreState();
}

class _PadreState extends State<_Padre> {
  late double _cantidad = widget.inicial;
  final recibidos = <double>[];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ControlCantidad(
            cantidad: _cantidad,
            maximo: widget.maximo,
            permitirDecimales: widget.permitirDecimales,
            alCambiar: (valor) {
              recibidos.add(valor);
              if (widget.aceptar?.call(valor) ?? true) {
                setState(() => _cantidad = valor);
              } else {
                // Fuerza un rebuild sin cambiar la cantidad, como haría un
                // notifier que valida y descarta.
                setState(() {});
              }
            },
          ),
        ),
      ),
    );
  }
}

_PadreState _estado(WidgetTester tester) =>
    tester.state<_PadreState>(find.byType(_Padre));

void main() {
  testWidgets('el + y el − ajustan de a uno', (tester) async {
    await tester.pumpWidget(const _Padre(inicial: 2));

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.pump();

    expect(_estado(tester).recibidos, [3.0, 2.0]);
  });

  testWidgets('escribir el número directamente lo cambia', (tester) async {
    await tester.pumpWidget(const _Padre(inicial: 1));

    await tester.enterText(find.byType(TextField), '12');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(_estado(tester).recibidos, [12.0]);
  });

  testWidgets('no baja del mínimo ni sube del máximo', (tester) async {
    await tester.pumpWidget(const _Padre(inicial: 1, maximo: 5));

    // Con la cantidad en el mínimo, el botón de restar está deshabilitado.
    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.pump();
    expect(_estado(tester).recibidos, isEmpty);

    // Y lo tecleado se recorta al tope en vez de aceptarse.
    await tester.enterText(find.byType(TextField), '99');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(_estado(tester).recibidos, [5.0]);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('un texto ilegible vuelve al valor anterior', (tester) async {
    await tester.pumpWidget(const _Padre(inicial: 4));

    await tester.enterText(find.byType(TextField), '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(_estado(tester).recibidos, isEmpty, reason: 'no manda un cero');
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('si el padre rechaza el cambio, el campo se resincroniza',
      (tester) async {
    await tester.pumpWidget(_Padre(inicial: 3, aceptar: (_) => false));

    await tester.enterText(find.byType(TextField), '9');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(_estado(tester).recibidos, [9.0]);
    expect(
      find.text('3'),
      findsOneWidget,
      reason: 'la cantidad la manda el padre, no el campo',
    );
  });

  testWidgets('sin decimales el campo ni deja escribir el punto',
      (tester) async {
    await tester.pumpWidget(const _Padre(inicial: 1));

    await tester.enterText(find.byType(TextField), '2.6');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(
      _estado(tester).recibidos,
      [26.0],
      reason: 'el filtro descarta el punto: quedan los dígitos',
    );
  });

  testWidgets('con decimales acepta 2,5', (tester) async {
    await tester.pumpWidget(const _Padre(inicial: 1, permitirDecimales: true));

    await tester.enterText(find.byType(TextField), '2,5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(_estado(tester).recibidos, [2.5]);
  });

  testWidgets('con alCambiar en null el campo queda deshabilitado',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ControlCantidad(cantidad: 2, alCambiar: null),
        ),
      ),
    );

    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  });
}
