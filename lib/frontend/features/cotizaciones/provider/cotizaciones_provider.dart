import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/cotizaciones/modelo/cotizacion_detalle.dart';
import '../../../../backend/features/cotizaciones/modelo/cotizacion_resumen.dart';
import '../../../../backend/features/cotizaciones/repositorio/repositorio_cotizaciones.dart';
import '../../../../backend/features/cotizaciones/repositorio/repositorio_cotizaciones_impl.dart';
import '../../../../backend/share/database/app_db_provider.dart';
import '../../../../core/resultado.dart';
import '../../autenticacion/provider/auth_providers.dart';

// Repositorio

final repositorioCotizacionesProvider = Provider<RepositorioCotizaciones>(
  name: 'repositorioCotizacionesProvider',
  (ref) => RepositorioCotizacionesImpl(
    ref.watch(appDatabaseProvider),
    // Quién firma lo que este repositorio escriba. Es una dependencia
    // del constructor, no un registro global (`CLAUDE.md` §3).
    ref.watch(sesionActualProvider),
  ),
);

// Estado

/// Estado del listado de cotizaciones: **solo la página visible**.
///
/// El filtrado por texto, el filtro de estado, el conteo y el recorte los
/// resuelve SQLite. Antes esta clase guardaba la lista entera y filtraba en
/// Dart, así que el conteo de los chips y el total de la paginación se
/// recalculaban en cada repintado sobre todas las cotizaciones del taller.
final class CotizacionesState {
  const CotizacionesState({
    this.items = const [],
    this.total = 0,
    this.pagina = 0,
    this.tamanoPagina = 12,
    this.busqueda = '',
    this.filtroEstado,
  });

  /// Cotizaciones de la página actual.
  final List<CotizacionResumen> items;

  /// Total de cotizaciones que cumplen el filtro, en todas las páginas.
  final int total;

  /// Página actual, de base cero.
  final int pagina;
  final int tamanoPagina;

  final String busqueda;

  /// `null` = todos los estados.
  final EstadoCotizacion? filtroEstado;

  int get totalPaginas =>
      total <= 0 ? 1 : (total + tamanoPagina - 1) ~/ tamanoPagina;

  bool get hayFiltro => busqueda.isNotEmpty || filtroEstado != null;

  /// Traduce los filtros de la interfaz a los que entiende el repositorio.
  FiltroCotizaciones get filtro =>
      FiltroCotizaciones(busqueda: busqueda, estado: filtroEstado);

  /// Centinela para distinguir "no tocar [filtroEstado]" de "ponerlo en null"
  /// (= quitar el filtro), que con `??` serían lo mismo.
  static const Object _sinCambio = Object();

  CotizacionesState copyWith({
    List<CotizacionResumen>? items,
    int? total,
    int? pagina,
    int? tamanoPagina,
    String? busqueda,
    Object? filtroEstado = _sinCambio,
  }) =>
      CotizacionesState(
        items: items ?? this.items,
        total: total ?? this.total,
        pagina: pagina ?? this.pagina,
        tamanoPagina: tamanoPagina ?? this.tamanoPagina,
        busqueda: busqueda ?? this.busqueda,
        filtroEstado: identical(filtroEstado, _sinCambio)
            ? this.filtroEstado
            : filtroEstado as EstadoCotizacion?,
      );
}

// Notifier

class CotizacionesNotifier extends AsyncNotifier<CotizacionesState> {
  late final RepositorioCotizaciones _repo;
  StreamSubscription<PaginaCotizaciones>? _sub;

  @override
  Future<CotizacionesState> build() async {
    _repo = ref.watch(repositorioCotizacionesProvider);
    ref.onDispose(() => _sub?.cancel());

    const inicial = CotizacionesState();
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
  void _suscribir(CotizacionesState estado) {
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

  void _aplicar(CotizacionesState nuevo) {
    state = AsyncData(nuevo);
    _suscribir(nuevo);
  }

  // Filtros — todos vuelven a la primera página, porque el conjunto cambió.

  void buscar(String query) {
    final actual = state.value;
    if (actual == null) return;
    final limpio = query.trim();
    if (actual.busqueda == limpio) return;
    _aplicar(actual.copyWith(busqueda: limpio, pagina: 0));
  }

  /// Filtra por vigencia. `null` quita el filtro y muestra todas.
  void filtrarPorEstado(EstadoCotizacion? estado) {
    final actual = state.value;
    if (actual == null || actual.filtroEstado == estado) return;
    _aplicar(actual.copyWith(filtroEstado: estado, pagina: 0));
  }

  void irAPagina(int pagina) {
    final actual = state.value;
    if (actual == null || pagina == actual.pagina) return;
    if (pagina < 0 || pagina >= actual.totalPaginas) return;
    _aplicar(actual.copyWith(pagina: pagina));
  }

  // Mutaciones

  /// Borra la cotización y su detalle.
  ///
  /// No hay borrado optimista: el stream de Drift repinta la página en cuanto
  /// la fila desaparece, y adelantarse solo abriría la puerta a mostrar una
  /// lista que no coincide con la base si el `DELETE` falla.
  Future<Resultado> eliminar(int id) async {
    try {
      await _repo.eliminar(id);
      return const Exito();
    } catch (e) {
      return const Fallo(
        MotivoFallo.persistencia,
        'No se pudo eliminar la cotización. Puede tener una reserva asociada.',
      );
    }
  }
}

// Providers públicos

final cotizacionesProvider =
    AsyncNotifierProvider<CotizacionesNotifier, CotizacionesState>(
  CotizacionesNotifier.new,
  name: 'cotizacionesProvider',
);

/// Cotizaciones de la página actual.
final cotizacionesPaginaProvider = Provider<List<CotizacionResumen>>(
  name: 'cotizacionesPaginaProvider',
  (ref) => ref.watch(cotizacionesProvider).value?.items ?? const [],
);

/// Conteos del encabezado y monto todavía en juego, resueltos con `COUNT` y
/// `SUM` en SQL.
final cotizacionesResumenProvider = StreamProvider<ResumenCotizaciones>(
  name: 'cotizacionesResumenProvider',
  (ref) => ref.watch(repositorioCotizacionesProvider).observarResumen(),
);

/// Cotización completa con sus ítems. La usa el editor al abrir una existente.
final cotizacionDetalleProvider = FutureProvider.family<CotizacionDetalle, int>(
  name: 'cotizacionDetalleProvider',
  (ref, id) => ref.watch(repositorioCotizacionesProvider).obtenerDetalle(id),
);
