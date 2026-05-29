import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../../backend/features/productos/repositorio/repositorio_producto.dart';
import '../../../../backend/features/productos/repositorio/repositorio_producto_impl.dart';
import '../../../../backend/share/database/app_db_provider.dart';

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
  });

  final List<Producto> todos;
  final String busqueda;
  final FiltroStock filtroStock;

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

  ProductosState copyWith({
    List<Producto>? todos,
    String? busqueda,
    FiltroStock? filtroStock,
  }) =>
      ProductosState(
        todos:       todos       ?? this.todos,
        busqueda:    busqueda    ?? this.busqueda,
        filtroStock: filtroStock ?? this.filtroStock,
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

  // Mutaciones — retornan null en éxito o mensaje de error

  Future<String?> crear(Producto producto) async {
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
