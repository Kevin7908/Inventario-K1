import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/reservas/enum/enum_reserva.dart';
import '../../../../backend/features/reservas/modelo/reserva_detalle.dart';
import '../../../../backend/features/reservas/modelo/reserva_resumen.dart';
import '../../../../backend/features/reservas/repositorio/repositorio_reservas.dart';
import '../../../../backend/features/reservas/repositorio/repositorio_reservas_impl.dart';
import '../../../../backend/share/database/app_db_provider.dart';

/// Providers del listado de Reservas con el diseño del mockup.
///
/// Nada se filtra, se cuenta ni se recorta en memoria: el `WHERE`, el `COUNT`
/// y el `LIMIT` los resuelve SQLite (§5 de `REGLAS_BD.md`). Las reservas se
/// acumulan con los meses, y el listado viejo traía el histórico entero para
/// descartarlo en Dart en cada tecla del buscador.

final repositorioReservasProvider = Provider<RepositorioReservas>(
  name: 'repositorioReservasProvider',
  (ref) => RepositorioReservasImpl(ref.watch(appDatabaseProvider)),
);

/// Estado del listado: **solo la página visible**, más lo que hace falta para
/// pintar el paginador.
final class ReservasListaState {
  const ReservasListaState({
    this.items = const [],
    this.total = 0,
    this.pagina = 0,
    this.tamanoPagina = 12,
    this.busqueda = '',
    this.filtroEstado,
  });

  final List<ReservaResumen> items;

  /// Total de reservas que cumplen el filtro, en todas las páginas.
  final int total;

  /// Página actual, de base cero.
  final int pagina;
  final int tamanoPagina;

  final String busqueda;

  /// `null` = todos los estados.
  final EstadoReserva? filtroEstado;

  int get totalPaginas =>
      total <= 0 ? 1 : (total + tamanoPagina - 1) ~/ tamanoPagina;

  bool get hayFiltro => busqueda.isNotEmpty || filtroEstado != null;

  FiltroReservas get filtro =>
      FiltroReservas(busqueda: busqueda, estado: filtroEstado);

  /// Centinela para distinguir "no tocar [filtroEstado]" de "ponerlo en null"
  /// (= quitar el filtro), que con `??` serían lo mismo.
  static const Object _sinCambio = Object();

  ReservasListaState copyWith({
    List<ReservaResumen>? items,
    int? total,
    int? pagina,
    String? busqueda,
    Object? filtroEstado = _sinCambio,
  }) =>
      ReservasListaState(
        items: items ?? this.items,
        total: total ?? this.total,
        pagina: pagina ?? this.pagina,
        tamanoPagina: tamanoPagina,
        busqueda: busqueda ?? this.busqueda,
        filtroEstado: identical(filtroEstado, _sinCambio)
            ? this.filtroEstado
            : filtroEstado as EstadoReserva?,
      );
}

class ReservasListaNotifier extends AsyncNotifier<ReservasListaState> {
  late final RepositorioReservas _repo;
  StreamSubscription<PaginaReservas>? _sub;

  @override
  Future<ReservasListaState> build() async {
    _repo = ref.watch(repositorioReservasProvider);
    ref.onDispose(() => _sub?.cancel());

    const inicial = ReservasListaState();
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
  void _suscribir(ReservasListaState estado) {
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

  void _aplicar(ReservasListaState nuevo) {
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

  /// Tocar el filtro ya activo lo quita: el mismo gesto pone y saca, sin
  /// necesitar un botón de "limpiar".
  void filtrarPorEstado(EstadoReserva? estado) {
    final actual = state.value;
    if (actual == null) return;
    final nuevo = actual.filtroEstado == estado ? null : estado;
    _aplicar(actual.copyWith(filtroEstado: nuevo, pagina: 0));
  }

  void irAPagina(int pagina) {
    final actual = state.value;
    if (actual == null || pagina == actual.pagina) return;
    if (pagina < 0 || pagina >= actual.totalPaginas) return;
    _aplicar(actual.copyWith(pagina: pagina));
  }
}

final reservasListaProvider =
    AsyncNotifierProvider<ReservasListaNotifier, ReservasListaState>(
  ReservasListaNotifier.new,
  name: 'reservasListaProvider',
);

/// Reservas de la página actual.
final reservasPaginaProvider = Provider<List<ReservaResumen>>(
  name: 'reservasPaginaProvider',
  (ref) => ref.watch(reservasListaProvider).value?.items ?? const [],
);

/// Detalle completo de una reserva: cabecera, líneas y abonos.
///
/// El editor no lo usa —lee el detalle por su cuenta para releerlo tras cada
/// escritura incremental—, pero sí quien lo necesita desde fuera.
final detalleReservaProvider =
    FutureProvider.autoDispose.family<ReservaDetalle, int>(
  name: 'detalleReservaProvider',
  (ref, id) => ref.watch(repositorioReservasProvider).obtenerDetalle(id),
);
