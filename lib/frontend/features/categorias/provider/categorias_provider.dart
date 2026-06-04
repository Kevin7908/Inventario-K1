import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/categorias/modelo/categoria.dart';
import '../../../../backend/features/categorias/repositorio/repositorio_categorias.dart';
import '../../../../backend/features/categorias/repositorio/repositorio_categorias_impl.dart';
import '../../../../backend/share/database/app_db_provider.dart';
import '../../../../backend/share/utils/sku_utils.dart';
import '../../productos/provider/productos_provider.dart';

final repositorioCategoriasProvider = Provider<RepositorioCategorias>(
  name: 'repositorioCategoriasProvider',
  (ref) => RepositorioCategoriasImpl(ref.watch(appDatabaseProvider)),
);

class CategoriasState {
  final List<Categoria> categorias;
  final String textoBusqueda;

  const CategoriasState({required this.categorias, this.textoBusqueda = ''});

  List<Categoria> get filtradas {
    if (textoBusqueda.isEmpty) return categorias;
    final t = textoBusqueda.toLowerCase();
    return categorias.where((c) => c.nombre.toLowerCase().contains(t)).toList();
  }

  CategoriasState copyWith({List<Categoria>? categorias, String? textoBusqueda}) =>
      CategoriasState(
        categorias: categorias ?? this.categorias,
        textoBusqueda: textoBusqueda ?? this.textoBusqueda,
      );
}

class CategoriasNotifier extends AsyncNotifier<CategoriasState> {
  @override
  Future<CategoriasState> build() async {
    final repo = ref.watch(repositorioCategoriasProvider);
    final completer = Completer<CategoriasState>();

    final sub = repo.observarTodas().listen(
      (lista) {
        if (!completer.isCompleted) {
          completer.complete(CategoriasState(categorias: lista));
        } else {
          state = AsyncData(CategoriasState(
            categorias: lista,
            textoBusqueda: state.value?.textoBusqueda ?? '',
          ));
        }
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    ref.onDispose(sub.cancel);
    return completer.future;
  }

  void buscar(String texto) {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(s.copyWith(textoBusqueda: texto));
  }

  Future<String?> crear({
    required String nombre,
    String? descripcion,
    String colorHex = '#3B82F6',
    String icono = 'category',
  }) async {
    try {
      final repo = ref.read(repositorioCategoriasProvider);
      if (nombre.trim().isEmpty) return 'El nombre no puede estar vacío';
      if (nombre.trim().length < 2) return 'El nombre debe tener al menos 2 caracteres';
      if (await repo.existeNombre(nombre.trim())) return 'Ya existe una categoría con ese nombre';
      await repo.crear(Categoria(
        nombre: nombre.trim(),
        descripcion: descripcion?.trim(),
        colorHex: colorHex,
        icono: icono,
        creadoEn: DateTime.now(),
        actualizadoEn: DateTime.now(),
      ));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> actualizar({
    required int id,
    required String nombre,
    String? descripcion,
    String? colorHex,
    String? icono,
  }) async {
    try {
      final repo = ref.read(repositorioCategoriasProvider);
      if (nombre.trim().isEmpty) return 'El nombre no puede estar vacío';
      if (nombre.trim().length < 2) return 'El nombre debe tener al menos 2 caracteres';
      if (await repo.existeNombre(nombre.trim(), excludirId: id)) {
        return 'Ya existe una categoría con ese nombre';
      }
      final actual = state.value!.categorias.firstWhere((c) => c.id == id);
      await repo.actualizar(actual.copyWith(
        nombre: nombre.trim(),
        descripcion: descripcion?.trim(),
        colorHex: colorHex,
        icono: icono,
        actualizadoEn: DateTime.now(),
      ));

      // Si el nombre cambió, regenera el SKU de todos sus productos.
      if (nombre.trim().toLowerCase() != actual.nombre.toLowerCase()) {
        await _actualizarSkusProductos(id, nombre.trim());
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> _actualizarSkusProductos(
    int categoriaId,
    String nuevoNombreCategoria,
  ) async {
    final repoProductos = ref.read(repositorioProductosProvider);

    final productosCategoria =
        await repoProductos.obtenerPorCategoria(categoriaId);
    if (productosCategoria.isEmpty) return;

    // Obtiene todos los demás productos para detectar conflictos de prefijo.
    final todos = await repoProductos.obtenerTodos();
    final otrosProductos =
        todos.where((p) => p.categoriaId != categoriaId).toList();

    final nuevoPrefijo = prefijoPara(nuevoNombreCategoria, otrosProductos);

    for (final p in productosCategoria) {
      // Mantiene el número secuencial del SKU actual (parte después del último guión).
      final partes = p.sku.split('-');
      if (partes.length < 2) continue; // SKU sin formato estándar → no tocar
      final numero = partes.last;
      await repoProductos.actualizar(p.copyWith(sku: '$nuevoPrefijo-$numero'));
    }
  }

  Future<String?> eliminar(int id) async {
    try {
      await ref.read(repositorioCategoriasProvider).eliminar(id);
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

final categoriasProvider =
    AsyncNotifierProvider<CategoriasNotifier, CategoriasState>(
  CategoriasNotifier.new,
  name: 'categoriasProvider',
);
