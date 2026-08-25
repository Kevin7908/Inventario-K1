import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/proveedores/modelo/proveedor.dart';
import '../../../../backend/features/proveedores/repositorio/repositorio_proveedor_impl.dart';
import '../../../../backend/features/proveedores/repositorio/repositorio_proveedores.dart';
import '../../../../backend/share/database/app_db_provider.dart';
import '../../../../core/resultado.dart';
import '../../productos/provider/productos_provider.dart';
import '../../autenticacion/provider/auth_providers.dart';

// Repositorio

final repositorioProveedoresProvider = Provider<RepositorioProveedores>(
  name: 'repositorioProveedoresProvider',
  (ref) => RepositorioProveedoresImpl(
    ref.watch(appDatabaseProvider),
    // Quién firma lo que este repositorio escriba. Es una dependencia
    // del constructor, no un registro global (`CLAUDE.md` §3).
    ref.watch(sesionActualProvider),
  ),
);

// Estado

/// Estado del catálogo de proveedores: **solo la página visible**.
///
/// El filtrado, el conteo y el recorte los hace SQLite. Quien necesite todos
/// los proveedores —el selector del formulario de producto— usa
/// [catalogoProveedoresProvider].
final class ProveedoresState {
  const ProveedoresState({
    this.items = const [],
    this.total = 0,
    this.pagina = 0,
    this.tamanoPagina = 12,
    this.busqueda = '',
    this.filtroActivo,
  });

  /// Proveedores de la página actual.
  final List<Proveedor> items;

  /// Total de proveedores que cumplen el filtro, en todas las páginas.
  final int total;

  /// Página actual, de base cero.
  final int pagina;
  final int tamanoPagina;

  final String busqueda;

  /// `null` = todos; `true` = solo activos; `false` = solo inactivos.
  final bool? filtroActivo;

  int get totalPaginas =>
      total <= 0 ? 1 : (total + tamanoPagina - 1) ~/ tamanoPagina;

  bool get hayFiltro => busqueda.isNotEmpty || filtroActivo != null;

  /// Traduce los filtros de la interfaz a los que entiende el repositorio.
  FiltroProveedores get filtro =>
      FiltroProveedores(busqueda: busqueda, activo: filtroActivo);

  /// Centinela para distinguir "no tocar [filtroActivo]" de "ponerlo en null"
  /// (= quitar el filtro de estado), que con `??` serían lo mismo.
  static const Object _sinCambio = Object();

  ProveedoresState copyWith({
    List<Proveedor>? items,
    int? total,
    int? pagina,
    int? tamanoPagina,
    String? busqueda,
    Object? filtroActivo = _sinCambio,
  }) =>
      ProveedoresState(
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

class ProveedoresNotifier extends AsyncNotifier<ProveedoresState> {
  late final RepositorioProveedores _repo;
  StreamSubscription<PaginaProveedores>? _sub;

  @override
  Future<ProveedoresState> build() async {
    _repo = ref.watch(repositorioProveedoresProvider);
    ref.onDispose(() => _sub?.cancel());

    const inicial = ProveedoresState();
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
  void _suscribir(ProveedoresState estado) {
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

  void _aplicar(ProveedoresState nuevo) {
    state = AsyncData(nuevo);
    _suscribir(nuevo);
  }

  // Filtros — todos vuelven a la primera página, porque el conjunto cambió.

  void buscar(String query) {
    final actual = state.value;
    if (actual == null) return;
    final trimmed = query.trim();
    if (actual.busqueda == trimmed) return;
    _aplicar(actual.copyWith(busqueda: trimmed, pagina: 0));
  }

  /// Filtra por estado. `null` quita el filtro y muestra todos.
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

  Future<Resultado> crear(Proveedor proveedor) async {
    final invalido = await _validar(proveedor);
    if (invalido != null) return invalido;

    try {
      await _repo.crear(
        proveedor.copyWith(
          creadoEn: DateTime.now(),
          actualizadoEn: DateTime.now(),
        ),
      );
      return const Exito();
    } catch (e) {
      return Fallo(MotivoFallo.persistencia, 'Error al crear el proveedor: $e');
    }
  }

  Future<Resultado> actualizar(Proveedor proveedor) async {
    final invalido = await _validar(proveedor, excludirId: proveedor.id);
    if (invalido != null) return invalido;

    try {
      await _repo.actualizar(
        proveedor.copyWith(actualizadoEn: DateTime.now()),
      );
      return const Exito();
    } catch (e) {
      return Fallo(
        MotivoFallo.persistencia,
        'Error al actualizar el proveedor: $e',
      );
    }
  }

  Future<Resultado> eliminar(int id) async {
    try {
      await _repo.eliminar(id);
      return const Exito();
    } catch (e) {
      return Fallo(
        MotivoFallo.persistencia,
        'No se pudo eliminar el proveedor: $e',
      );
    }
  }

  /// Reglas de negocio del alta y la edición. Viven en el notifier y no en el
  /// formulario para que el diálogo de otro módulo no pueda saltárselas.
  Future<Resultado?> _validar(Proveedor proveedor, {int? excludirId}) async {
    final nombre = proveedor.nombre.trim();
    if (nombre.isEmpty) {
      return const Fallo(
        MotivoFallo.validacion,
        'El nombre no puede estar vacío.',
      );
    }
    if (nombre.length < 2) {
      return const Fallo(
        MotivoFallo.validacion,
        'El nombre debe tener al menos 2 caracteres.',
      );
    }
    if (await _repo.existeNombre(nombre, excludirId: excludirId)) {
      return const Fallo(
        MotivoFallo.nombreDuplicado,
        'Ya existe un proveedor con ese nombre.',
      );
    }

    final nit = proveedor.nitCedula?.trim() ?? '';
    if (nit.isNotEmpty &&
        await _repo.existeNit(nit, excludirId: excludirId)) {
      return const Fallo(
        MotivoFallo.documentoDuplicado,
        'Ya existe un proveedor con ese NIT o cédula.',
      );
    }

    return null;
  }
}

// Providers públicos

final proveedoresProvider =
    AsyncNotifierProvider<ProveedoresNotifier, ProveedoresState>(
  ProveedoresNotifier.new,
  name: 'proveedoresProvider',
);

/// Catálogo completo de proveedores, en vivo.
///
/// Para lo que necesita todos: el selector de proveedor del formulario de
/// producto. La grilla de Proveedores no lo usa — esa va paginada contra la
/// base de datos.
final catalogoProveedoresProvider = StreamProvider<List<Proveedor>>(
  name: 'catalogoProveedoresProvider',
  (ref) => ref.watch(repositorioProveedoresProvider).observarTodas(),
);

/// Proveedores de la página actual.
final proveedoresFiltradosProvider = Provider<List<Proveedor>>(
  name: 'proveedoresFiltradosProvider',
  (ref) => ref.watch(proveedoresProvider).value?.items ?? const [],
);

/// Conteos del encabezado, resueltos con un COUNT en SQL.
final proveedoresResumenProvider = StreamProvider<({int total, int activos})>(
  name: 'proveedoresResumenProvider',
  (ref) => ref.watch(repositorioProveedoresProvider).observarResumen(),
);

/// Cuántos productos surte cada proveedor, indexado por id de proveedor.
///
/// Sale de un `GROUP BY` en SQLite, no de recorrer el catálogo en memoria.
/// El `distinct` compara el contenido del mapa: Drift re-emite ante cualquier
/// cambio en la tabla de productos, y sin esto la grilla se reconstruiría
/// aunque ningún conteo hubiera cambiado.
final conteoProductosPorProveedorProvider = StreamProvider<Map<int, int>>(
  name: 'conteoProductosPorProveedorProvider',
  (ref) => ref
      .watch(repositorioProductosProvider)
      .observarConteoPorProveedor()
      .distinct(_mismoConteo),
);

bool _mismoConteo(Map<int, int> a, Map<int, int> b) {
  if (a.length != b.length) return false;
  for (final entrada in a.entries) {
    if (b[entrada.key] != entrada.value) return false;
  }
  return true;
}
