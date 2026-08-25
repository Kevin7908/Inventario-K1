import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/motos/modelo/moto.dart';
import '../../../../backend/features/motos/repositorio/repositorio_moto_impl.dart';
import '../../../../backend/features/motos/repositorio/repositorio_motos.dart';
import '../../../../backend/share/database/app_db_provider.dart';
import '../../../../core/resultado.dart';
import 'validacion_moto.dart';
import '../../autenticacion/provider/auth_providers.dart';

// Repositorio

final repositorioMotosProvider = Provider<RepositorioMotos>(
  name: 'repositorioMotosProvider',
  (ref) => RepositorioMotosImpl(
    ref.watch(appDatabaseProvider),
    // Quién firma lo que este repositorio escriba. Es una dependencia
    // del constructor, no un registro global (`CLAUDE.md` §3).
    ref.watch(sesionActualProvider),
  ),
);

// Estado

/// Estado del catálogo de motos: **solo la página visible**.
///
/// El filtrado, el conteo y el recorte los hace SQLite. Quien necesite todas
/// las motos —los selectores de órdenes, reservas y cotizaciones— usa
/// [catalogoMotosProvider].
final class MotosState {
  const MotosState({
    this.items = const [],
    this.total = 0,
    this.pagina = 0,
    this.tamanoPagina = 12,
    this.busqueda = '',
    this.filtroActivo,
  });

  /// Motos de la página actual.
  final List<Moto> items;

  /// Total de motos que cumplen el filtro, en todas las páginas.
  final int total;

  /// Página actual, de base cero.
  final int pagina;
  final int tamanoPagina;

  final String busqueda;

  /// `null` = todas; `true` = solo activas; `false` = solo dadas de baja.
  final bool? filtroActivo;

  int get totalPaginas =>
      total <= 0 ? 1 : (total + tamanoPagina - 1) ~/ tamanoPagina;

  bool get hayFiltro => busqueda.isNotEmpty || filtroActivo != null;

  /// Traduce los filtros de la interfaz a los que entiende el repositorio.
  FiltroMotos get filtro =>
      FiltroMotos(busqueda: busqueda, activo: filtroActivo);

  /// Centinela para distinguir "no tocar [filtroActivo]" de "ponerlo en null"
  /// (= quitar el filtro), que con `??` serían lo mismo.
  static const Object _sinCambio = Object();

  MotosState copyWith({
    List<Moto>? items,
    int? total,
    int? pagina,
    int? tamanoPagina,
    String? busqueda,
    Object? filtroActivo = _sinCambio,
  }) =>
      MotosState(
        items:        items        ?? this.items,
        total:        total        ?? this.total,
        pagina:       pagina       ?? this.pagina,
        tamanoPagina: tamanoPagina ?? this.tamanoPagina,
        busqueda:     busqueda     ?? this.busqueda,
        filtroActivo: identical(filtroActivo, _sinCambio)
            ? this.filtroActivo
            : filtroActivo as bool?,
      );
}

// Notifier

class MotosNotifier extends AsyncNotifier<MotosState> {
  late final RepositorioMotos _repo;
  StreamSubscription<PaginaMotos>? _sub;

  @override
  Future<MotosState> build() async {
    _repo = ref.watch(repositorioMotosProvider);
    ref.onDispose(() => _sub?.cancel());

    const inicial = MotosState();
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
  void _suscribir(MotosState estado) {
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

  void _aplicar(MotosState nuevo) {
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

  /// Filtra por estado. `null` quita el filtro y muestra todas.
  void filtrarPorActivo(bool? activo) {
    final actual = state.value;
    if (actual == null || actual.filtroActivo == activo) return;
    _aplicar(actual.copyWith(filtroActivo: activo, pagina: 0));
  }

  void irAPagina(int pagina) {
    final actual = state.value;
    if (actual == null || pagina == actual.pagina) return;
    if (pagina < 0 || pagina >= actual.totalPaginas) return;
    _aplicar(actual.copyWith(pagina: pagina));
  }

  // Mutaciones

  /// Alta o edición de una moto del catálogo.
  ///
  /// Es un solo método y no un `crear`/`actualizar` separados porque el
  /// formulario es el mismo: una moto con `id == 0` se inserta, el resto se
  /// actualiza. La validación va antes de tocar la base para que el mensaje
  /// diga *quién* tiene la placa y no el error crudo del índice `unique`.
  Future<Resultado> guardar(Moto moto) async {
    final invalida =
        await validarMoto(moto: moto, repo: _repo, exigirDueno: true);
    if (invalida != null) return invalida;

    try {
      if (moto.id == 0) {
        await _repo.crear(moto);
      } else {
        await _repo.actualizar(moto);
      }
      return const Exito();
    } catch (e) {
      return Fallo(MotivoFallo.persistencia, 'No se pudo guardar la moto: $e');
    }
  }

  Future<Resultado> eliminar(int id) async {
    try {
      await _repo.eliminar(id);
      return const Exito();
    } catch (e) {
      // Las FK de órdenes, reservas y cotizaciones apuntan a `motos`: una moto
      // con historial no se puede borrar, y el error crudo de SQLite no se lo
      // explica a nadie.
      return const Fallo(
        MotivoFallo.persistencia,
        'No se pudo eliminar la moto. Puede tener órdenes, reservas o '
        'cotizaciones asociadas.',
      );
    }
  }
}

// Providers públicos

final motosProvider = AsyncNotifierProvider<MotosNotifier, MotosState>(
  MotosNotifier.new,
  name: 'motosProvider',
);

/// Catálogo completo de motos, en vivo.
///
/// Para lo que necesita todas: los selectores de moto de órdenes, reservas y
/// cotizaciones. El catálogo de Configuración no lo usa —ese va paginado
/// contra la base de datos.
final catalogoMotosProvider = StreamProvider<List<Moto>>(
  name: 'catalogoMotosProvider',
  (ref) => ref.watch(repositorioMotosProvider).observarTodos(),
);

/// Motos de la página actual.
final motosFiltradasProvider = Provider<List<Moto>>(
  name: 'motosFiltradasProvider',
  (ref) => ref.watch(motosProvider).value?.items ?? const [],
);

/// Conteos del encabezado, resueltos con `COUNT` en SQL.
final motosResumenProvider = StreamProvider<ResumenMotos>(
  name: 'motosResumenProvider',
  (ref) => ref.watch(repositorioMotosProvider).observarResumen(),
);
