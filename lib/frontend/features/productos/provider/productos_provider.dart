import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../../backend/features/productos/repositorio/repositorio_producto.dart';
import '../../../../backend/features/productos/repositorio/repositorio_producto_impl.dart';
import '../../../../backend/share/database/app_db_provider.dart';
import '../../../../backend/share/utils/sku_utils.dart';

// Repositorio

final repositorioProductosProvider = Provider<RepositorioProducto>(
  name: 'repositorioProductosProvider',
  (ref) => RepositorioProductosImpl(ref.watch(appDatabaseProvider)),
);

// Enums públicos

enum FiltroStock { todos, enStock, stockBajo, sinStock }

// Estado

final class ProductosState {
  const ProductosState({
    this.todos = const [],
    this.busqueda = '',
    this.filtroStock = FiltroStock.todos,
    this.filtroCategoriaId,
  });

  final List<Producto> todos;
  final String busqueda;
  final FiltroStock filtroStock;

  /// Categoría por la que se filtra. `null` = todas las categorías.
  final int? filtroCategoriaId;

  /// Lista filtrada — se computa solo cuando cambia el estado.
  List<Producto> get filtrados {
    var lista = todos;

    if (busqueda.isNotEmpty) {
      final q = busqueda.toLowerCase();
      lista = lista.where((p) {
        return p.nombre.toLowerCase().contains(q) ||
            p.sku.toLowerCase().contains(q) ||
            (p.categoriaNombre?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    if (filtroCategoriaId != null) {
      lista =
          lista.where((p) => p.categoriaId == filtroCategoriaId).toList();
    }

    switch (filtroStock) {
      case FiltroStock.enStock:
        return lista
            .where((p) => p.estadoStock == EstadoStock.enStock)
            .toList();
      case FiltroStock.stockBajo:
        return lista
            .where((p) => p.estadoStock == EstadoStock.stockBajo)
            .toList();
      case FiltroStock.sinStock:
        return lista
            .where((p) => p.estadoStock == EstadoStock.sinStock)
            .toList();
      case FiltroStock.todos:
        return lista;
    }
  }

  /// Centinela para distinguir "no tocar [filtroCategoriaId]" de "ponerlo en
  /// null" (= quitar el filtro de categoría), que con `??` serían lo mismo.
  static const Object _sinCambio = Object();

  ProductosState copyWith({
    List<Producto>? todos,
    String? busqueda,
    FiltroStock? filtroStock,
    Object? filtroCategoriaId = _sinCambio,
  }) =>
      ProductosState(
        todos:       todos       ?? this.todos,
        busqueda:    busqueda    ?? this.busqueda,
        filtroStock: filtroStock ?? this.filtroStock,
        filtroCategoriaId: identical(filtroCategoriaId, _sinCambio)
            ? this.filtroCategoriaId
            : filtroCategoriaId as int?,
      );
}

// Notifier

class ProductosNotifier extends AsyncNotifier<ProductosState> {
  late final RepositorioProducto _repo;

  @override
  Future<ProductosState> build() async {
    _repo = ref.watch(repositorioProductosProvider);

    final sub = _repo.observarTodos().listen(
      (lista) {
        final actual = state.value;
        state = AsyncData(
          actual != null
              ? actual.copyWith(todos: lista)
              : ProductosState(todos: lista),
        );
      },
      onError: (Object e, StackTrace st) => state = AsyncError(e, st),
    );
    ref.onDispose(sub.cancel);

    return ProductosState(todos: await _repo.obtenerTodos());
  }

  // Filtros

  void buscar(String query) {
    final actual = state.value;
    if (actual == null) return;
    final trimmed = query.trim();
    if (actual.busqueda == trimmed) return;
    state = AsyncData(actual.copyWith(busqueda: trimmed));
  }

  void filtrarPorStock(FiltroStock filtro) {
    final actual = state.value;
    if (actual == null || actual.filtroStock == filtro) return;
    state = AsyncData(actual.copyWith(filtroStock: filtro));
  }

  /// Filtra por categoría. `null` quita el filtro y muestra todas.
  void filtrarPorCategoria(int? categoriaId) {
    final actual = state.value;
    if (actual == null || actual.filtroCategoriaId == categoriaId) return;
    state = AsyncData(actual.copyWith(filtroCategoriaId: categoriaId));
  }

  // Generación de SKU a partir de la categoría seleccionada
  String generarSku(String nombreCategoria) {
    final todos = state.value?.todos ?? [];
    final base = normalizarCategoria(nombreCategoria);
    if (base.isEmpty) return 'PRD-001';

    // Encuentra el prefijo más corto (mínimo 3 letras) que no esté siendo
    // usado por una categoría diferente. Si hay conflicto, agrega una letra más.
    final catLower = nombreCategoria.toLowerCase();
    var prefijo = base.substring(0, base.length.clamp(0, 3));
    for (var len = 3; len <= base.length; len++) {
      final candidato = base.substring(0, len);
      final conflicto = todos.any((p) {
        // Ignora productos de la misma categoría
        if ((p.categoriaNombre ?? '').toLowerCase() == catLower) return false;
        // ¿Algún producto de otra categoría ya usa este prefijo?
        return RegExp('^${RegExp.escape(candidato)}-(\\d+)\$')
            .hasMatch(p.sku.toUpperCase());
      });
      prefijo = candidato;
      if (!conflicto) break;
    }

    // Máximo número existente con este prefijo → +1
    final patron = RegExp('^${RegExp.escape(prefijo)}-(\\d+)\$');
    var maximo = 0;
    for (final p in todos) {
      final match = patron.firstMatch(p.sku.toUpperCase());
      if (match != null) {
        final n = int.tryParse(match.group(1)!) ?? 0;
        if (n > maximo) maximo = n;
      }
    }
    return '$prefijo-${(maximo + 1).toString().padLeft(3, '0')}';
  }

  // Mutaciones — retornan null en éxito o mensaje de error
  Future<String?> crear(Producto producto) async {
    if (await _repo.existeNombre(producto.nombre)) {
      return 'Ya existe un producto con el nombre "${producto.nombre}".';
    }
    if (await _repo.existeSku(producto.sku)) {
      return 'El SKU "${producto.sku}" ya está en uso.';
    }
    try {
      await _repo.crear(producto);
      return null;
    } catch (e) {
      return 'Error al crear el producto: $e';
    }
  }

  Future<String?> actualizar(Producto producto) async {
    if (await _repo.existeNombre(producto.nombre, excludirId: producto.id)) {
      return 'Ya existe un producto con el nombre "${producto.nombre}".';
    }
    if (await _repo.existeSku(producto.sku, excludirId: producto.id)) {
      return 'El SKU "${producto.sku}" ya está en uso por otro producto.';
    }
    try {
      await _repo.actualizar(producto);
      return null;
    } catch (e) {
      return 'Error al actualizar el producto: $e';
    }
  }

  Future<String?> eliminar(int id) async {
    try {
      await _repo.eliminar(id);
      return null;
    } catch (e) {
      return 'Error al eliminar el producto: $e';
    }
  }
}

// Providers públicos

final productosProvider =
    AsyncNotifierProvider<ProductosNotifier, ProductosState>(
  ProductosNotifier.new,
  name: 'productosProvider',
);

/// Lista ya filtrada — solo rebuilda cuando la lista filtrada cambia.
final productosFiltradosProvider = Provider<List<Producto>>(
  name: 'productosFiltradosProvider',
  (ref) => ref.watch(productosProvider).value?.filtrados ?? const [],
);
