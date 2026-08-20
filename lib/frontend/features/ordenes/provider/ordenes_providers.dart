import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/ventas/ordenes/enum/enum_ordenes.dart';
import '../../../../backend/features/ventas/ordenes/modelo/orden_detalle.dart';
import '../../../../backend/features/ventas/ordenes/modelo/orden_resumen.dart';
import '../../../../backend/features/ventas/ordenes/repositorio/repositrio_ordenes.dart';
import '../../../../backend/features/ventas/ordenes/repositorio/repositrio_ordenes_impl.dart';
import '../../../../backend/share/database/app_db_provider.dart';

/// Providers del módulo de Órdenes de servicio (el nuevo, con el diseño del
/// mockup).
///
/// Convive con `features/ventas/ordenes/` mientras se termina la migración.
/// El repositorio es el mismo; lo que cambia es que aquí **nada se filtra, se
/// cuenta ni se recorta en memoria**: el `WHERE`, el `COUNT` y el `LIMIT` los
/// resuelve SQLite (§5 de `REGLAS_BD.md`).

final repositorioOrdenesProvider = Provider<RepositorioOrdenes>(
  name: 'repositorioOrdenesProvider2',
  (ref) => RepositorioOrdenesImpl(ref.watch(appDatabaseProvider)),
);

/// Los cuatro contadores del encabezado, de un `COUNT` por estado.
///
/// Va aparte del listado a propósito: cuenta **toda** la tabla, no lo que el
/// buscador esté mostrando. Buscar "Ana" no cambia el "12" de Órdenes
/// totales, porque contarlo sobre lo filtrado diría algo distinto de lo que
/// promete la etiqueta.
final ordenesResumenProvider = StreamProvider<ResumenOrdenes>(
  name: 'ordenesResumenProvider',
  (ref) => ref.watch(repositorioOrdenesProvider).observarResumen(),
);

/// Estado del listado: **solo la página visible**, más lo que hace falta para
/// pintar el paginador.
final class OrdenesState {
  const OrdenesState({
    this.items = const [],
    this.total = 0,
    this.pagina = 0,
    this.tamanoPagina = 12,
    this.busqueda = '',
    this.filtroEstado,
  });

  /// Órdenes de la página actual.
  final List<OrdenResumen> items;

  /// Total de órdenes que cumplen el filtro, en todas las páginas.
  final int total;

  /// Página actual, de base cero.
  final int pagina;
  final int tamanoPagina;

  final String busqueda;

  /// `null` = todos los estados.
  final EstadoOrden? filtroEstado;

  int get totalPaginas =>
      total <= 0 ? 1 : (total + tamanoPagina - 1) ~/ tamanoPagina;

  bool get hayFiltro => busqueda.isNotEmpty || filtroEstado != null;

  /// Traduce los filtros de la interfaz a los que entiende el repositorio.
  FiltroOrdenes get filtro =>
      FiltroOrdenes(busqueda: busqueda, estado: filtroEstado);

  /// Centinela para distinguir "no tocar [filtroEstado]" de "ponerlo en null"
  /// (= quitar el filtro), que con `??` serían lo mismo.
  static const Object _sinCambio = Object();

  OrdenesState copyWith({
    List<OrdenResumen>? items,
    int? total,
    int? pagina,
    int? tamanoPagina,
    String? busqueda,
    Object? filtroEstado = _sinCambio,
  }) =>
      OrdenesState(
        items: items ?? this.items,
        total: total ?? this.total,
        pagina: pagina ?? this.pagina,
        tamanoPagina: tamanoPagina ?? this.tamanoPagina,
        busqueda: busqueda ?? this.busqueda,
        filtroEstado: identical(filtroEstado, _sinCambio)
            ? this.filtroEstado
            : filtroEstado as EstadoOrden?,
      );
}

class OrdenesNotifier extends AsyncNotifier<OrdenesState> {
  late final RepositorioOrdenes _repo;
  StreamSubscription<PaginaOrdenes>? _sub;

  @override
  Future<OrdenesState> build() async {
    _repo = ref.watch(repositorioOrdenesProvider);
    ref.onDispose(() => _sub?.cancel());

    const inicial = OrdenesState();
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
  void _suscribir(OrdenesState estado) {
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

  void _aplicar(OrdenesState nuevo) {
    state = AsyncData(nuevo);
    _suscribir(nuevo);
  }

  // Filtros — los dos vuelven a la primera página, porque el conjunto cambió.

  void buscar(String texto) {
    final actual = state.value;
    if (actual == null) return;
    final limpio = texto.trim();
    if (actual.busqueda == limpio) return;
    _aplicar(actual.copyWith(busqueda: limpio, pagina: 0));
  }

  /// Tocar la tarjeta ya activa quita el filtro: es el mismo gesto para poner
  /// y para sacar, sin necesitar un botón de "limpiar".
  void filtrarPorEstado(EstadoOrden? estado) {
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

final ordenesProvider =
    AsyncNotifierProvider<OrdenesNotifier, OrdenesState>(
  OrdenesNotifier.new,
  name: 'ordenesProvider2',
);

/// Órdenes de la página actual.
final ordenesPaginaProvider = Provider<List<OrdenResumen>>(
  name: 'ordenesPaginaProvider',
  (ref) => ref.watch(ordenesProvider).value?.items ?? const [],
);

/// Detalle completo de una orden: cabecera, tareas, repuestos y cargos.
///
/// El editor no lo usa —lee el detalle por su cuenta para poder releerlo tras
/// cada escritura incremental—, pero sí quien necesita invalidarlo desde
/// fuera: facturar una orden le cambia el estado.
final ordenDetalleProvider = FutureProvider.family<OrdenDetalle, int>(
  name: 'ordenDetalleProvider',
  (ref, id) => ref.watch(repositorioOrdenesProvider).obtenerDetalle(id),
);
