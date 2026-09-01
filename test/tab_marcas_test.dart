// La pestaña «Marcas y modelos» de Configuración.
//
// Existe por un desborde real: la lista de marcas usa `itemExtent` para
// saltarse el cálculo de layout de cada fila, y el valor estaba un pixel corto
// para las dos líneas de texto que la fila lleva. Flutter pintaba la franja
// amarilla en **cada** marca y llenaba la consola de excepciones.
//
// Lo que fija este test es que la fila quepa en su casilla. Es el tipo de
// error que ningún análisis estático ve y que solo aparece al abrir la
// pantalla.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/motos/modelo/marca_moto.dart';
import 'package:inventario_k1/backend/share/dominio/permiso.dart';
import 'package:inventario_k1/frontend/features/autenticacion/provider/auth_providers.dart';
import 'package:inventario_k1/frontend/features/configuracion/widgets/tab_marcas.dart';
import 'package:inventario_k1/frontend/features/motos/provider/marcas_provider.dart';

MarcaMoto _marca({
  int id = 1,
  String nombre = 'Bajaj',
  bool activo = true,
  int modelos = 3,
}) =>
    MarcaMoto(id: id, nombre: nombre, activo: activo, modelos: modelos);

Future<void> _montar(
  WidgetTester tester, {
  required List<MarcaMoto> marcas,
  Set<Permiso> permisos = const {Permiso.configuracionEditar},
}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        marcasMotoProvider.overrideWith((ref) => Stream.value(marcas)),
        // Los modelos de la marca elegida: el panel de la derecha los pide y
        // sin esto se quedaría cargando para siempre.
        modelosMotoProvider.overrideWith((ref, marcaId) =>
            Stream.value(const <ModeloMoto>[])),
        permisosSesionProvider.overrideWith((ref) => Stream.value(permisos)),
      ],
      child: const MaterialApp(home: Scaffold(body: TabMarcas())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('la fila de una marca cabe en su casilla', (tester) async {
    // Nombre y «3 modelos» son dos líneas: con la casilla un pixel corta,
    // Flutter lanza una excepción de desborde por cada fila visible.
    await _montar(tester, marcas: [_marca()]);

    expect(tester.takeException(), isNull);
    expect(find.text('Bajaj'), findsOneWidget);
    expect(find.text('3 modelos'), findsOneWidget);
  });

  testWidgets('tampoco desborda la que está dada de baja', (tester) async {
    // Su segunda línea es más larga —«3 modelos · dada de baja»— y es la que
    // más cerca está de no caber.
    await _montar(
      tester,
      marcas: [_marca(nombre: 'Yamaha', activo: false)],
    );

    expect(tester.takeException(), isNull);
    expect(find.text('3 modelos · dada de baja'), findsOneWidget);
  });

  testWidgets('una lista entera se pinta sin una sola excepción',
      (tester) async {
    await _montar(
      tester,
      marcas: [
        for (var i = 1; i <= 8; i++)
          _marca(id: i, nombre: 'Marca $i', modelos: i),
      ],
    );

    expect(tester.takeException(), isNull);
    expect(find.text('1 modelo'), findsOneWidget, reason: 'singular');
    expect(find.text('2 modelos'), findsOneWidget);
  });

  testWidgets('sin permiso de editar no hay botones en la fila',
      (tester) async {
    await _montar(tester, marcas: [_marca()], permisos: const {});

    expect(find.byTooltip('Renombrar'), findsNothing);
    expect(find.byTooltip('Nueva marca'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
