// La rejilla del punto de venta va paginada contra SQLite, así que lo que hay
// que cuidar aquí es la página: si un filtro nuevo no la reinicia, la rejilla
// queda vacía sin explicar por qué.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/frontend/features/pos/provider/pos_providers.dart';

ProviderContainer _contenedor() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('buscar vuelve a la primera página', () {
    final container = _contenedor();
    final notifier = container.read(posProvider.notifier);

    notifier.irAPagina(3);
    expect(container.read(posProvider).pagina, 3);

    notifier.buscar('pastilla');

    expect(container.read(posProvider).pagina, 0);
    expect(container.read(posProvider).busqueda, 'pastilla');
  });

  test('filtrar por categoría vuelve a la primera página', () {
    final container = _contenedor();
    final notifier = container.read(posProvider.notifier);

    notifier.irAPagina(2);
    notifier.filtrarPorCategoria(7);

    expect(container.read(posProvider).pagina, 0);
    expect(container.read(posProvider).categoriaId, 7);
  });

  test('no se puede ir a una página negativa', () {
    final container = _contenedor();

    container.read(posProvider.notifier).irAPagina(-4);

    expect(container.read(posProvider).pagina, 0);
  });

  test('el filtro que se manda al repositorio deja fuera lo inactivo', () {
    final container = _contenedor();
    container.read(posProvider.notifier).buscar('  aceite  ');

    final filtro = container.read(posProvider).filtro;

    expect(filtro.soloActivos, isTrue);
    expect(filtro.busqueda, 'aceite', reason: 'la búsqueda va sin espacios');
  });
}
