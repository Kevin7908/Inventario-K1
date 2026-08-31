// AtajosFormulario no puede robarle el foco al campo que lo pide.
//
// Bug real: el diálogo de cobro del punto de venta abre con «Efectivo» y su
// campo «Recibido» lleva `autofocus`. Como `AtajosFormulario` envolvía todo en
// un `Focus(autofocus: true)`, ganaba el de fuera —que no es un campo de
// texto— y **no se podía teclear el monto recibido**. Los atajos seguían
// funcionando, así que no había nada roto a la vista.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/frontend/share/share.dart';

void main() {
  testWidgets('un campo con autofocus dentro se queda con el foco',
      (tester) async {
    // Se comprueba el **foco**, no `enterText`: ese fuerza el foco antes de
    // escribir, así que pasaría igual con el bug puesto. Lo que el usuario
    // vive es abrir el diálogo y que el teclado no vaya a ninguna parte.
    final controlador = TextEditingController();
    final foco = FocusNode();
    addTearDown(controlador.dispose);
    addTearDown(foco.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AtajosFormulario(
          alGuardar: () {},
          alCancelar: () {},
          child: TextField(
            controller: controlador,
            focusNode: foco,
            autofocus: true,
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(foco.hasFocus, isTrue,
        reason: 'el campo con autofocus tiene que quedarse con el foco');
    expect(tester.binding.focusManager.primaryFocus, same(foco));
  });

  testWidgets('sin nadie que pida el foco, los atajos siguen funcionando',
      (tester) async {
    var guardado = false;
    var cancelado = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AtajosFormulario(
          alGuardar: () => guardado = true,
          alCancelar: () => cancelado = true,
          child: const Text('sin campos'),
        ),
      ),
    ));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    expect(guardado, isTrue, reason: 'Ctrl+Enter debe guardar');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(cancelado, isTrue, reason: 'Esc debe cancelar');
  });

  testWidgets('con el foco en un campo, los atajos siguen llegando',
      (tester) async {
    var guardado = false;
    final controlador = TextEditingController();
    addTearDown(controlador.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AtajosFormulario(
          alGuardar: () => guardado = true,
          child: TextField(controller: controlador, autofocus: true),
        ),
      ),
    ));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    expect(guardado, isTrue);
  });
}
