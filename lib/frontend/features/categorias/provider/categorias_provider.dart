import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/categorias/modelo/categoria.dart';
import '../../../../backend/features/categorias/repositorio/repositorio_categorias.dart';
import '../../../../backend/features/categorias/repositorio/repositorio_categorias_impl.dart';
import '../../../../backend/share/database/app_db_provider.dart';
import '../../../../core/resultado.dart';
import '../../productos/provider/productos_provider.dart';
import '../../autenticacion/provider/auth_providers.dart';

final repositorioCategoriasProvider = Provider<RepositorioCategorias>(
  name: 'repositorioCategoriasProvider',
  (ref) => RepositorioCategoriasImpl(
    ref.watch(appDatabaseProvider),
    // Quién firma lo que este repositorio escriba. Es una dependencia
    // del constructor, no un registro global (`CLAUDE.md` §3).
    ref.watch(sesionActualProvider),
  ),
);

/// Estado del catálogo de categorías: **solo la página visible**.
///
/// El filtrado, el conteo y el recorte los hace SQLite. Quien necesite todas
/// las categorías —el panel lateral de Productos, el selector del formulario—
/// usa [catalogoCategoriasProvider].
class CategoriasState {
  const CategoriasState({
    this.items = const [],
    this.total = 0,
    this.pagina = 0,
    this.tamanoPagina = 24,
    this.textoBusqueda = '',
  });

  final List<Categoria> items;
  final int total;
  final int pagina;
  final int tamanoPagina;
  final String textoBusqueda;

  int get totalPaginas =>
      total <= 0 ? 1 : (total + tamanoPagina - 1) ~/ tamanoPagina;

  CategoriasState copyWith({
    List<Categoria>? items,
    int? total,
    int? pagina,
    int? tamanoPagina,
    String? textoBusqueda,
  }) =>
      CategoriasState(
        items:         items         ?? this.items,
        total:         total         ?? this.total,
        pagina:        pagina        ?? this.pagina,
        tamanoPagina:  tamanoPagina  ?? this.tamanoPagina,
        textoBusqueda: textoBusqueda ?? this.textoBusqueda,
      );
}

class CategoriasNotifier extends AsyncNotifier<CategoriasState> {
  late final RepositorioCategorias _repo;
  StreamSubscription<PaginaCategorias>? _sub;

  @override
  Future<CategoriasState> build() async {
    _repo = ref.watch(repositorioCategoriasProvider);
    ref.onDispose(() => _sub?.cancel());

    const inicial = CategoriasState();
    final primera = await _repo
        .observarPagina(
          busqueda: inicial.textoBusqueda,
          pagina: inicial.pagina,
          tamano: inicial.tamanoPagina,
        )
        .first;

    _suscribir(inicial);
    return inicial.copyWith(items: primera.items, total: primera.total);
  }

  /// Reabre el stream con la búsqueda y la página vigentes.
  void _suscribir(CategoriasState estado) {
    _sub?.cancel();
    _sub = _repo
        .observarPagina(
          busqueda: estado.textoBusqueda,
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

  void _aplicar(CategoriasState nuevo) {
    state = AsyncData(nuevo);
    _suscribir(nuevo);
  }

  void buscar(String texto) {
    final actual = state.value;
    if (actual == null) return;
    final trimmed = texto.trim();
    if (actual.textoBusqueda == trimmed) return;
    _aplicar(actual.copyWith(textoBusqueda: trimmed, pagina: 0));
  }

  void irAPagina(int pagina) {
    final actual = state.value;
    if (actual == null || pagina == actual.pagina) return;
    if (pagina < 0 || pagina >= actual.totalPaginas) return;
    _aplicar(actual.copyWith(pagina: pagina));
  }

  Future<Resultado> crear({
    required String nombre,
    String? descripcion,
  }) async {
    try {
      final repo = ref.read(repositorioCategoriasProvider);
      if (nombre.trim().isEmpty) {
        return const Fallo(
          MotivoFallo.validacion,
          'El nombre no puede estar vacío.',
        );
      }
      if (nombre.trim().length < 2) {
        return const Fallo(
          MotivoFallo.validacion,
          'El nombre debe tener al menos 2 caracteres.',
        );
      }
      if (await repo.existeNombre(nombre.trim())) {
        return const Fallo(
          MotivoFallo.nombreDuplicado,
          'Ya existe una categoría con ese nombre.',
        );
      }
      await repo.crear(Categoria(
        nombre: nombre.trim(),
        descripcion: descripcion?.trim(),
        creadoEn: DateTime.now(),
        actualizadoEn: DateTime.now(),
      ));
      return const Exito();
    } catch (e) {
      return Fallo(MotivoFallo.persistencia, 'Error al crear la categoría: $e');
    }
  }

  Future<Resultado> actualizar({
    required int id,
    required String nombre,
    String? descripcion,
  }) async {
    try {
      final repo = ref.read(repositorioCategoriasProvider);
      if (nombre.trim().isEmpty) {
        return const Fallo(
          MotivoFallo.validacion,
          'El nombre no puede estar vacío.',
        );
      }
      if (nombre.trim().length < 2) {
        return const Fallo(
          MotivoFallo.validacion,
          'El nombre debe tener al menos 2 caracteres.',
        );
      }
      if (await repo.existeNombre(nombre.trim(), excludirId: id)) {
        return const Fallo(
          MotivoFallo.nombreDuplicado,
          'Ya existe una categoría con ese nombre.',
        );
      }
      final actual = await repo.obtenerPorId(id);
      if (actual == null) {
        return const Fallo(
          MotivoFallo.validacion,
          'La categoría ya no existe.',
        );
      }
      await repo.actualizar(actual.copyWith(
        nombre: nombre.trim(),
        descripcion: descripcion?.trim(),
        actualizadoEn: DateTime.now(),
      ));
      return const Exito();
    } catch (e) {
      return Fallo(
        MotivoFallo.persistencia,
        'Error al actualizar la categoría: $e',
      );
    }
  }

  Future<Resultado> eliminar(int id) async {
    try {
      await ref.read(repositorioCategoriasProvider).eliminar(id);
      return const Exito();
    } catch (e) {
      return Fallo(
        MotivoFallo.persistencia,
        'No se pudo eliminar la categoría: $e',
      );
    }
  }
}

final categoriasProvider =
    AsyncNotifierProvider<CategoriasNotifier, CategoriasState>(
  CategoriasNotifier.new,
  name: 'categoriasProvider',
);

/// Catálogo completo de categorías, en vivo.
///
/// Para lo que necesita todas: el panel lateral de Productos y el selector de
/// categoría del formulario. La grilla de Categorías no lo usa — esa va
/// paginada contra la base de datos.
final catalogoCategoriasProvider = StreamProvider<List<Categoria>>(
  name: 'catalogoCategoriasProvider',
  (ref) => ref.watch(repositorioCategoriasProvider).observarTodas(),
);

/// Categorías de la página actual.
final categoriasFiltradasProvider = Provider<List<Categoria>>(
  name: 'categoriasFiltradasProvider',
  (ref) => ref.watch(categoriasProvider).value?.items ?? const [],
);

/// Texto activo del buscador de categorías.
final busquedaCategoriasProvider = Provider<String>(
  name: 'busquedaCategoriasProvider',
  (ref) =>
      ref.watch(categoriasProvider.select((s) => s.value?.textoBusqueda ?? '')),
);

/// Cuántos productos tiene cada categoría, indexado por id de categoría.
///
/// Sale de un `GROUP BY` en SQLite, no de recorrer el catálogo en memoria.
/// El `distinct` compara el contenido del mapa: Drift re-emite ante cualquier
/// cambio en la tabla, y sin esto la grilla se reconstruiría aunque ningún
/// conteo hubiera cambiado.
final conteoProductosPorCategoriaProvider = StreamProvider<Map<int, int>>(
  name: 'conteoProductosPorCategoriaProvider',
  (ref) => ref
      .watch(repositorioProductosProvider)
      .observarConteoPorCategoria()
      .distinct(_mismoConteo),
);

bool _mismoConteo(Map<int, int> a, Map<int, int> b) {
  if (a.length != b.length) return false;
  for (final entrada in a.entries) {
    if (b[entrada.key] != entrada.value) return false;
  }
  return true;
}
