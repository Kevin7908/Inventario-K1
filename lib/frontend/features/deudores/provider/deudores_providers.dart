import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/deudores/modelo/deudor_detalle.dart';
import '../../../../backend/features/deudores/modelo/deudor_resumen.dart';
import '../../../../backend/features/deudores/repositorio/repositorio_deudores.dart';
import '../../../../backend/features/deudores/repositorio/repositorio_deudores_impl.dart';
import '../../../../backend/share/database/app_db_provider.dart';
import '../../autenticacion/provider/auth_providers.dart';

/// Providers del listado de Cuentas por cobrar.
///
/// Nada se filtra, se cuenta ni se recorta en memoria: el `WHERE`, el `COUNT`
/// y el `LIMIT` los resuelve SQLite (§5 de `REGLAS_BD.md`). El listado viejo
/// traía la cartera entera y la recorría cuatro veces —una por cada KPI— en
/// cada tecla del buscador.

final repositorioDeudoresProvider = Provider<RepositorioDeudores>(
  name: 'repositorioDeudoresProvider',
  (ref) => RepositorioDeudoresImpl(
    ref.watch(appDatabaseProvider),
    // Quién firma lo que este repositorio escriba. Es una dependencia
    // del constructor, no un registro global (`CLAUDE.md` §3).
    ref.watch(sesionActualProvider),
  ),
);

/// Estado del listado: **solo la página visible**, más lo que hace falta para
/// pintar el paginador.
final class DeudoresListaState {
  const DeudoresListaState({
    this.items = const [],
    this.total = 0,
    this.pagina = 0,
    this.tamanoPagina = 12,
    this.busqueda = '',
    this.vista = VistaDeudores.todas,
  });

  final List<DeudorResumen> items;

  /// Total de deudas que cumplen el filtro, en todas las páginas.
  final int total;

  /// Página actual, de base cero.
  final int pagina;
  final int tamanoPagina;

  final String busqueda;
  final VistaDeudores vista;

  int get totalPaginas =>
      total <= 0 ? 1 : (total + tamanoPagina - 1) ~/ tamanoPagina;

  bool get hayFiltro =>
      busqueda.isNotEmpty || vista != VistaDeudores.todas;

  FiltroDeudores get filtro =>
      FiltroDeudores(busqueda: busqueda, vista: vista);

  DeudoresListaState copyWith({
    List<DeudorResumen>? items,
    int? total,
    int? pagina,
    String? busqueda,
    VistaDeudores? vista,
  }) =>
      DeudoresListaState(
        items: items ?? this.items,
        total: total ?? this.total,
        pagina: pagina ?? this.pagina,
        tamanoPagina: tamanoPagina,
        busqueda: busqueda ?? this.busqueda,
        vista: vista ?? this.vista,
      );
}

class DeudoresListaNotifier extends AsyncNotifier<DeudoresListaState> {
  /// `late` **sin `final`**: Riverpod conserva la instancia del notifier y
  /// vuelve a llamar a `build()` cada vez que el provider se invalida. Con
  /// `late final`, esa segunda pasada revienta con «Field '_repo' has already
  /// been initialized» y la pantalla se queda en el mensaje de error.
  late RepositorioDeudores _repo;
  StreamSubscription<PaginaDeudores>? _sub;

  @override
  Future<DeudoresListaState> build() async {
    _repo = ref.watch(repositorioDeudoresProvider);
    ref.onDispose(() => _sub?.cancel());

    const inicial = DeudoresListaState();
    final primera = await _repo
        .observarPagina(
          filtro: inicial.filtro,
          pagina: inicial.pagina,
          tamano: inicial.tamanoPagina,
        )
        .first;

    _suscribir(inicial);
    return inicial.copyWith(items: primera.items, total: primera.total);
  }

  /// Reabre el stream con los filtros y la página vigentes.
  ///
  /// Cada cambio de filtro es una consulta nueva: por eso se cancela la
  /// suscripción anterior en vez de recortar en memoria.
  void _suscribir(DeudoresListaState estado) {
    _sub?.cancel();
    _sub = _repo
        .observarPagina(
          filtro: estado.filtro,
          pagina: estado.pagina,
          tamano: estado.tamanoPagina,
        )
        .listen(
      (pagina) {
        final actual = state.value;
        if (actual == null) return;
        state = AsyncData(
          actual.copyWith(items: pagina.items, total: pagina.total),
        );
      },
      onError: (Object e, StackTrace st) => state = AsyncError(e, st),
    );
  }

  void _aplicar(DeudoresListaState nuevo) {
    state = AsyncData(nuevo);
    _suscribir(nuevo);
  }

  // Los dos filtros vuelven a la primera página, porque el conjunto cambió.

  void buscar(String texto) {
    final actual = state.value;
    if (actual == null) return;
    final limpio = texto.trim();
    if (actual.busqueda == limpio) return;
    _aplicar(actual.copyWith(busqueda: limpio, pagina: 0));
  }

  /// Tocar el tramo ya activo lo quita: el mismo gesto pone y saca, sin
  /// necesitar un botón de «limpiar».
  void filtrarPorVista(VistaDeudores vista) {
    final actual = state.value;
    if (actual == null) return;
    final nueva =
        actual.vista == vista ? VistaDeudores.todas : vista;
    if (actual.vista == nueva) return;
    _aplicar(actual.copyWith(vista: nueva, pagina: 0));
  }

  void irAPagina(int pagina) {
    final actual = state.value;
    if (actual == null || pagina == actual.pagina) return;
    if (pagina < 0 || pagina >= actual.totalPaginas) return;
    _aplicar(actual.copyWith(pagina: pagina));
  }
}

final deudoresListaProvider =
    AsyncNotifierProvider<DeudoresListaNotifier, DeudoresListaState>(
  DeudoresListaNotifier.new,
  name: 'deudoresListaProvider',
);

/// Deudas de la página actual.
final deudoresPaginaProvider = Provider<List<DeudorResumen>>(
  name: 'deudoresPaginaProvider',
  (ref) => ref.watch(deudoresListaProvider).value?.items ?? const [],
);

/// Los cuatro contadores de la cabecera, sobre la cartera entera.
///
/// Van aparte del listado a propósito: la pantalla los quiere aunque la
/// búsqueda esté recortando la tabla, y contarlos sobre lo filtrado diría algo
/// distinto de lo que promete la etiqueta.
final resumenCarteraProvider = StreamProvider<ResumenCartera>(
  name: 'resumenCarteraProvider',
  (ref) => ref.watch(repositorioDeudoresProvider).observarResumen(),
);

/// Detalle completo de una deuda: cabecera y pagos.
///
/// El editor no lo usa —lee el detalle por su cuenta para releerlo tras cada
/// escritura—, pero sí quien lo necesita desde fuera.
final detalleDeudaProvider =
    FutureProvider.autoDispose.family<DeudorDetalle, int>(
  name: 'detalleDeudaProvider',
  (ref, id) => ref.watch(repositorioDeudoresProvider).obtenerDetalle(id),
);
