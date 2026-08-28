// PieTotales: el pie de documento del punto de venta, las cotizaciones y las
// órdenes.
//
// Es share, así que lo que se comprueba es que **no decide ni formatea nada**:
// recibe importes ya formateados, no guarda el descuento y avisa por callback.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/frontend/share/share.dart';

class _Anfitrion extends StatefulWidget {
  const _Anfitrion({
    this.subtotal,
    this.iva,
    this.hayDescuento = false,
    this.editable = true,
    this.alCambiar,
  });

  final String? subtotal;
  final String? iva;
  final bool hayDescuento;
  final bool editable;
  final ValueChanged<String>? alCambiar;

  @override
  State<_Anfitrion> createState() => _AnfitrionState();
}

class _AnfitrionState extends State<_Anfitrion> {
  final _controlador = TextEditingController();
  final _foco = FocusNode();

  @override
  void dispose() {
    _controlador.dispose();
    _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: PieTotales(
            subtotal: widget.subtotal,
            total: r'$85.000',
            iva: widget.iva,
            etiquetaIva: 'IVA (19%) incluido',
            controladorDescuento: _controlador,
            focoDescuento: _foco,
            hayDescuento: widget.hayDescuento,
            editable: widget.editable,
            alCambiarDescuento: widget.alCambiar ?? (_) {},
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('pinta los importes tal cual llegan', (tester) async {
    await tester.pumpWidget(
      const _Anfitrion(subtotal: r'$90.000', iva: r'$13.571'),
    );

    expect(find.text(r'$90.000'), findsOneWidget);
    expect(find.text(r'$85.000'), findsOneWidget);
    expect(find.text(r'$13.571'), findsOneWidget);
    expect(find.text('IVA (19%) incluido'), findsOneWidget);
  });

  testWidgets('sin subtotal y sin IVA no pinta esos renglones',
      (tester) async {
    // Con `kIva` en 0 el renglón sería un `$0` que solo estorba, y sin
    // descuento el subtotal repite al total.
    await tester.pumpWidget(const _Anfitrion());

    expect(find.text('Subtotal'), findsNothing);
    expect(find.text('IVA (19%) incluido'), findsNothing);
    expect(find.text(r'$85.000'), findsOneWidget);
  });

  testWidgets('el descuento avisa por callback, no lo guarda', (tester) async {
    final tecleado = <String>[];

    await tester.pumpWidget(
      _Anfitrion(hayDescuento: true, alCambiar: tecleado.add),
    );
    await tester.enterText(find.byType(TextField), '5000');

    expect(tecleado, ['5000']);
    // Con descuento el campo se marca: prefijo `–$` en vez de `$`.
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration!.prefixText,
      r'–$',
    );
  });

  testWidgets('el campo solo admite dígitos', (tester) async {
    final tecleado = <String>[];

    await tester.pumpWidget(_Anfitrion(alCambiar: tecleado.add));
    await tester.enterText(find.byType(TextField), '5.000abc');

    expect(tecleado, ['5000']);
  });

  testWidgets('con el documento cerrado el campo no se puede tocar',
      (tester) async {
    // Una orden ENTREGADA o ANULADA es de solo lectura: dejar teclear contra
    // una guarda de la base es mentirle al usuario.
    await tester.pumpWidget(const _Anfitrion(editable: false));

    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  });
}
