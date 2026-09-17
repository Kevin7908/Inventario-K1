// Tocar una especialización enseña quiénes la tienen.
//
// La tarjeta de la rejilla ya decía «3 técnicos» y ese número no llevaba a
// ninguna parte: para saber cuáles había que irse a la pantalla de Técnicos y
// leer la columna fila por fila.
//
// Lo que se fija aquí es el orden y el trato de los inactivos, que es lo que
// se rompería sin que nadie se entere: quien pregunta quién sabe de frenos
// también quiere saber que el que sabía ya no está, pero no antes que los que
// están.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/especializacion/modelo/especializacion.dart';
import 'package:inventario_k1/backend/features/tecnicos/modelo/tecnico.dart';
import 'package:inventario_k1/frontend/features/especializacion/provider/especializacion_provider.dart';
import 'package:inventario_k1/frontend/features/especializacion/widgets/dialogo_tecnicos_especializacion.dart';
import 'package:inventario_k1/frontend/features/tecnicos/provider/tecnico_provider.dart';

const _frenos = Especializacion(id: 3, nombre: 'Frenos y suspensión');

Tecnico _tecnico({
  required String nombres,
  String? apellidos,
  int? especializacionId = 3,
  bool activo = true,
}) =>
    Tecnico(
      nombres: nombres,
      apellidos: apellidos,
      especializacionId: especializacionId,
      activo: activo,
      creadoEn: DateTime(2026),
    );

/// Monta el diálogo con un catálogo de técnicos fijo.
Future<void> _pump(WidgetTester tester, List<Tecnico> catalogo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        catalogoTecnicosProvider.overrideWith((ref) => Stream.value(catalogo)),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: DialogoTecnicosEspecializacion(especializacion: _frenos),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('el provider derivado', () {
    /// Los nombres que devuelve el provider, en orden.
    ///
    /// Es `async` porque un `StreamProvider` **no resuelve sin oyentes** y su
    /// primer valor llega en el microtask siguiente: leerlo de una vez
    /// devuelve `AsyncLoading` y una lista vacía que no prueba nada.
    Future<List<String>> nombresDe(List<Tecnico> catalogo) async {
      final container = ProviderContainer(
        overrides: [
          catalogoTecnicosProvider
              .overrideWith((ref) => Stream.value(catalogo)),
        ],
      );
      addTearDown(container.dispose);
      // En Riverpod 3 un provider sin oyentes se descarta apenas se lee y su
      // `.future` no resuelve nunca: hay que escucharlo antes de esperarlo.
      container.listen(catalogoTecnicosProvider, (_, _) {});
      await container.read(catalogoTecnicosProvider.future);

      return container
              .read(tecnicosDeEspecializacionProvider(3))
              .value
              ?.map((t) => t.nombres)
              .toList() ??
          const [];
    }

    test('trae solo los de esa especialidad', () async {
      final nombres = await nombresDe([
        _tecnico(nombres: 'Andrés'),
        _tecnico(nombres: 'Beatriz', especializacionId: 8),
        _tecnico(nombres: 'Camilo', especializacionId: null),
      ]);

      expect(nombres, ['Andrés']);
    });

    test('los activos primero, y dentro de cada grupo por nombre', () async {
      final nombres = await nombresDe([
        _tecnico(nombres: 'Zulema'),
        _tecnico(nombres: 'Bernardo', activo: false),
        _tecnico(nombres: 'Ana'),
        _tecnico(nombres: 'Álvaro', activo: false),
      ]);

      expect(nombres, ['Ana', 'Zulema', 'Álvaro', 'Bernardo']);
    });
  });

  group('el diálogo', () {
    testWidgets('lista a los técnicos de la especialidad', (tester) async {
      await _pump(tester, [
        _tecnico(nombres: 'Andrés', apellidos: 'Rojas'),
        _tecnico(nombres: 'Beatriz', apellidos: 'Lara', especializacionId: 8),
      ]);

      expect(find.text('Frenos y suspensión'), findsOneWidget);
      expect(find.text('Andrés Rojas'), findsOneWidget);
      expect(find.text('Beatriz Lara'), findsNothing);
    });

    testWidgets('al inactivo lo lista y lo dice', (tester) async {
      await _pump(tester, [
        _tecnico(nombres: 'Bernardo', apellidos: 'Cruz', activo: false),
      ]);

      expect(find.text('Bernardo Cruz'), findsOneWidget);
      expect(find.textContaining('Ya no trabaja aquí'), findsOneWidget);
    });

    testWidgets('sin nadie asignado lo dice en vez de quedar vacío',
        (tester) async {
      await _pump(tester, [_tecnico(nombres: 'Ana', especializacionId: 8)]);

      expect(
        find.text('Nadie tiene esta especialidad todavía'),
        findsOneWidget,
      );
    });
  });
}
