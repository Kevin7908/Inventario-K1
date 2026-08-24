// El listado de Reservas: que pida la página con el filtro correcto y que
// **sobreviva a que lo invaliden**.
//
// El repositorio va sustituido por uno falso: bajo el `fakeAsync` de
// `flutter_test` los streams reales de Drift no avanzan. Que el recorte de
// verdad ocurra en SQL se prueba en `test/repositorio_reservas_test.dart`.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/reservas/enum/enum_reserva.dart';
import 'package:inventario_k1/backend/features/reservas/modelo/reserva_resumen.dart';
import 'package:inventario_k1/backend/features/reservas/repositorio/repositorio_reservas.dart';
import 'package:inventario_k1/frontend/features/reservas/provider/reservas_providers.dart';

ReservaResumen _reserva({
  required int id,
  required String numero,
  String cliente = 'Carlos Ramírez',
  EstadoReserva estado = EstadoReserva.activa,
  int total = 100000,
  int pagado = 40000,
}) =>
    ReservaResumen(
      id: id,
      numero: numero,
      clienteId: 1,
      nombreCliente: cliente,
      estado: estado,
      totalReserva: total,
      pagadoAcumulado: pagado,
      creadoEn: DateTime(2026, 8, 20),
    );

/// Repositorio de mentira que hace en Dart lo que el de verdad hace en SQL.
class _RepoFalso implements RepositorioReservas {
  _RepoFalso(this.todas);

  final List<ReservaResumen> todas;

  /// Los filtros con los que el listado fue pidiendo páginas, en orden.
  final peticiones = <({FiltroReservas filtro, int pagina, int tamano})>[];

  @override
  Stream<PaginaReservas> observarPagina({
    required FiltroReservas filtro,
    required int pagina,
    required int tamano,
  }) {
    peticiones.add((filtro: filtro, pagina: pagina, tamano: tamano));

    final query = filtro.busqueda.toLowerCase();
    final coinciden = [
      for (final r in todas)
        if ((filtro.estado == null || r.estado == filtro.estado) &&
            (query.isEmpty ||
                r.numero.toLowerCase().contains(query) ||
                r.nombreCliente.toLowerCase().contains(query)))
          r,
    ];

    final desde = (pagina * tamano).clamp(0, coinciden.length);
    final hasta = (desde + tamano).clamp(0, coinciden.length);

    return Stream.value(
      PaginaReservas(
        items: coinciden.sublist(desde, hasta),
        total: coinciden.length,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('El listado no usa ${invocation.memberName}');
}

/// Deja el provider con un oyente antes de leerlo: en Riverpod 3 uno sin
/// oyentes se descarta apenas se lee y su `.future` no resuelve nunca.
Future<ReservasListaState> _leer(ProviderContainer container) {
  container.listen(reservasListaProvider, (_, _) {});
  return container.read(reservasListaProvider.future);
}

ProviderContainer _contenedor(_RepoFalso repo) {
  final container = ProviderContainer(
    overrides: [repositorioReservasProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('pide la primera página con el filtro vacío', () async {
    final repo = _RepoFalso([
      for (var i = 1; i <= 20; i++) _reserva(id: i, numero: 'RES-000$i'),
    ]);
    final container = _contenedor(repo);

    final estado = await _leer(container);

    expect(estado.items, hasLength(12), reason: 'el tamaño de página');
    expect(estado.total, 20, reason: 'el total es el real, no el de la página');
    expect(estado.totalPaginas, 2);
    expect(repo.peticiones.first.pagina, 0);
  });

  test('invalidar el listado no lo rompe', () async {
    // Es el fallo que se vio en pantalla: `late final _repo` asignado dentro
    // de `build()` reventaba con «has already been initialized» en cuanto
    // algo invalidaba el provider, y la rejilla se quedaba en el mensaje de
    // error en vez de la lista.
    final repo = _RepoFalso([_reserva(id: 1, numero: 'RES-0001')]);
    final container = _contenedor(repo);

    await _leer(container);
    container.invalidate(reservasListaProvider);
    final segunda = await _leer(container);

    expect(segunda.items, hasLength(1));
    expect(container.read(reservasListaProvider).hasError, isFalse);
  });

  test('buscar vuelve a la primera página y pasa el texto al repositorio',
      () async {
    final repo = _RepoFalso([
      for (var i = 1; i <= 20; i++) _reserva(id: i, numero: 'RES-000$i'),
      _reserva(id: 99, numero: 'RES-0099', cliente: 'Ana Torres'),
    ]);
    final container = _contenedor(repo);
    await _leer(container);

    container.read(reservasListaProvider.notifier).irAPagina(1);
    container.read(reservasListaProvider.notifier).buscar('Ana');
    await Future<void>.delayed(Duration.zero);

    final ultima = repo.peticiones.last;
    expect(ultima.filtro.busqueda, 'Ana');
    expect(ultima.pagina, 0, reason: 'el conjunto cambió: se vuelve al inicio');
  });

  test('el filtro de estado se quita tocándolo otra vez', () async {
    final repo = _RepoFalso([
      _reserva(id: 1, numero: 'RES-0001'),
      _reserva(id: 2, numero: 'RES-0002', estado: EstadoReserva.cancelada),
    ]);
    final container = _contenedor(repo);
    await _leer(container);
    final notifier = container.read(reservasListaProvider.notifier);

    notifier.filtrarPorEstado(EstadoReserva.cancelada);
    await Future<void>.delayed(Duration.zero);
    expect(repo.peticiones.last.filtro.estado, EstadoReserva.cancelada);

    notifier.filtrarPorEstado(EstadoReserva.cancelada);
    await Future<void>.delayed(Duration.zero);
    expect(repo.peticiones.last.filtro.estado, isNull);
  });
}
