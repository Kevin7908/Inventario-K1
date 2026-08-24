// El listado de Cuentas por cobrar: que pida la página con el filtro correcto,
// que los contadores no dependan de la búsqueda y que **sobreviva a que lo
// invaliden**.
//
// El repositorio va sustituido por uno falso: bajo el `fakeAsync` de
// `flutter_test` los streams reales de Drift no avanzan. Que el recorte de
// verdad ocurra en SQL —y que «vencida» signifique lo mismo en Dart y en el
// `WHERE`— se prueba en `test/repositorio_deudores_test.dart`.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/deudores/enum/enum_deudor.dart';
import 'package:inventario_k1/backend/features/deudores/modelo/deudor_resumen.dart';
import 'package:inventario_k1/backend/features/deudores/repositorio/repositorio_deudores.dart';
import 'package:inventario_k1/frontend/features/deudores/provider/deudores_providers.dart';

DeudorResumen _deuda({
  required int id,
  required String numero,
  String cliente = 'Carlos Ramírez',
  String concepto = 'Repuestos a crédito',
  EstadoDeudor estado = EstadoDeudor.activa,
  int total = 100000,
  int pagado = 40000,
  DateTime? vence,
}) =>
    DeudorResumen(
      id: id,
      numero: numero,
      clienteId: 1,
      nombreCliente: cliente,
      concepto: concepto,
      montoTotal: total,
      montoPagado: pagado,
      estado: estado,
      fechaVencimiento: vence,
      creadoEn: DateTime(2026, 8, 20),
    );

/// Repositorio de mentira que hace en Dart lo que el de verdad hace en SQL.
class _RepoFalso implements RepositorioDeudores {
  _RepoFalso(this.todas);

  final List<DeudorResumen> todas;

  /// Los filtros con los que el listado fue pidiendo páginas, en orden.
  final peticiones = <({FiltroDeudores filtro, int pagina, int tamano})>[];

  /// Cuántas veces se pidió el resumen de la cabecera.
  var vecesResumen = 0;

  @override
  Stream<PaginaDeudores> observarPagina({
    required FiltroDeudores filtro,
    required int pagina,
    required int tamano,
  }) {
    peticiones.add((filtro: filtro, pagina: pagina, tamano: tamano));

    final query = filtro.busqueda.toLowerCase();
    final coinciden = [
      for (final d in todas)
        if (_enVista(d, filtro.vista) &&
            (query.isEmpty ||
                d.numero.toLowerCase().contains(query) ||
                (d.concepto?.toLowerCase().contains(query) ?? false) ||
                d.nombreCliente.toLowerCase().contains(query)))
          d,
    ];

    final desde = (pagina * tamano).clamp(0, coinciden.length);
    final hasta = (desde + tamano).clamp(0, coinciden.length);

    return Stream.value(
      PaginaDeudores(
        items: coinciden.sublist(desde, hasta),
        total: coinciden.length,
      ),
    );
  }

  static bool _enVista(DeudorResumen d, VistaDeudores vista) => switch (vista) {
        VistaDeudores.todas => true,
        VistaDeudores.alDia => d.estaViva && !d.estaVencida,
        VistaDeudores.vencidas => d.estaViva && d.estaVencida,
        VistaDeudores.pagadas => d.estado == EstadoDeudor.pagada,
      };

  @override
  Stream<ResumenCartera> observarResumen() {
    vecesResumen++;
    return Stream.value((
      porCobrar: todas.where((d) => d.estaViva).fold(0, (s, d) => s + d.saldo),
      alDia: todas.where((d) => _enVista(d, VistaDeudores.alDia)).length,
      vencidas: todas.where((d) => _enVista(d, VistaDeudores.vencidas)).length,
      pagadas: todas.where((d) => d.estado == EstadoDeudor.pagada).length,
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('El listado no usa ${invocation.memberName}');
}

/// Deja el provider con un oyente antes de leerlo: en Riverpod 3 uno sin
/// oyentes se descarta apenas se lee y su `.future` no resuelve nunca.
Future<DeudoresListaState> _leer(ProviderContainer container) {
  container.listen(deudoresListaProvider, (_, _) {});
  return container.read(deudoresListaProvider.future);
}

ProviderContainer _contenedor(_RepoFalso repo) {
  final container = ProviderContainer(
    overrides: [repositorioDeudoresProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('pide la primera página con el filtro vacío', () async {
    final repo = _RepoFalso([
      for (var i = 1; i <= 20; i++) _deuda(id: i, numero: 'DEU-000$i'),
    ]);
    final container = _contenedor(repo);

    final estado = await _leer(container);

    expect(estado.items, hasLength(12), reason: 'el tamaño de página');
    expect(estado.total, 20, reason: 'el total es el real, no el de la página');
    expect(estado.totalPaginas, 2);
    expect(repo.peticiones.first.pagina, 0);
    expect(repo.peticiones.first.filtro.vista, VistaDeudores.todas);
  });

  test('invalidar el listado no lo rompe', () async {
    // Es el fallo que ya se vio en Reservas y en el «Reintentar» de Deudores:
    // `late final _repo` asignado dentro de `build()` reventaba con «has
    // already been initialized» en cuanto algo invalidaba el provider, y la
    // pantalla se quedaba en el mensaje de error en vez de la tabla.
    final repo = _RepoFalso([_deuda(id: 1, numero: 'DEU-0001')]);
    final container = _contenedor(repo);

    await _leer(container);
    container.invalidate(deudoresListaProvider);
    final segunda = await _leer(container);

    expect(segunda.items, hasLength(1));
    expect(container.read(deudoresListaProvider).hasError, isFalse);
  });

  test('buscar vuelve a la primera página y pasa el texto al repositorio',
      () async {
    final repo = _RepoFalso([
      for (var i = 1; i <= 20; i++) _deuda(id: i, numero: 'DEU-000$i'),
      _deuda(id: 99, numero: 'DEU-0099', cliente: 'Ana Torres'),
    ]);
    final container = _contenedor(repo);
    await _leer(container);

    container.read(deudoresListaProvider.notifier).irAPagina(1);
    container.read(deudoresListaProvider.notifier).buscar('Ana');
    await Future<void>.delayed(Duration.zero);

    final ultima = repo.peticiones.last;
    expect(ultima.filtro.busqueda, 'Ana');
    expect(ultima.pagina, 0, reason: 'el conjunto cambió: se vuelve al inicio');
  });

  test('el tramo se quita tocándolo otra vez', () async {
    final repo = _RepoFalso([
      _deuda(id: 1, numero: 'DEU-0001'),
      _deuda(id: 2, numero: 'DEU-0002', estado: EstadoDeudor.pagada),
    ]);
    final container = _contenedor(repo);
    await _leer(container);
    final notifier = container.read(deudoresListaProvider.notifier);

    notifier.filtrarPorVista(VistaDeudores.pagadas);
    await Future<void>.delayed(Duration.zero);
    expect(repo.peticiones.last.filtro.vista, VistaDeudores.pagadas);

    notifier.filtrarPorVista(VistaDeudores.pagadas);
    await Future<void>.delayed(Duration.zero);
    expect(repo.peticiones.last.filtro.vista, VistaDeudores.todas);
  });

  test('«vencidas» recorta por calendario, no por el estado guardado',
      () async {
    final vencida = _deuda(
      id: 1,
      numero: 'DEU-0001',
      vence: DateTime.now().subtract(const Duration(days: 3)),
    );
    final repo = _RepoFalso([
      vencida,
      _deuda(
        id: 2,
        numero: 'DEU-0002',
        vence: DateTime.now().add(const Duration(days: 10)),
      ),
    ]);
    final container = _contenedor(repo);
    await _leer(container);

    container
        .read(deudoresListaProvider.notifier)
        .filtrarPorVista(VistaDeudores.vencidas);
    await Future<void>.delayed(Duration.zero);

    final estado = container.read(deudoresListaProvider).value!;
    expect(estado.items.map((d) => d.id), [1]);
    expect(estado.items.single.estado, EstadoDeudor.activa,
        reason: 'nadie la marcó: la venció el calendario');
  });

  test('los contadores miran la cartera entera, no lo que filtra la búsqueda',
      () async {
    // Es el motivo de que el resumen sea un provider aparte: si se calculara
    // sobre la página, «Total por cobrar» diría otra cosa según lo que hubiera
    // tecleado el usuario en el buscador.
    final repo = _RepoFalso([
      _deuda(id: 1, numero: 'DEU-0001', total: 100000, pagado: 40000),
      _deuda(
        id: 2,
        numero: 'DEU-0002',
        cliente: 'Ana Torres',
        total: 50000,
        pagado: 0,
      ),
      _deuda(
        id: 3,
        numero: 'DEU-0003',
        total: 30000,
        pagado: 30000,
        estado: EstadoDeudor.pagada,
      ),
    ]);
    final container = _contenedor(repo);
    container.listen(resumenCarteraProvider, (_, _) {});
    await _leer(container);

    container.read(deudoresListaProvider.notifier).buscar('Ana');
    await Future<void>.delayed(Duration.zero);

    final resumen = await container.read(resumenCarteraProvider.future);
    expect(container.read(deudoresListaProvider).value!.items, hasLength(1));
    expect(resumen.porCobrar, 110000, reason: '60.000 + 50.000, sin la pagada');
    expect(resumen.pagadas, 1);
  });
}
