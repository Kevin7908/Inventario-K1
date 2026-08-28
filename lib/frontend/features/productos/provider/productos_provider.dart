import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../../backend/features/productos/repositorio/repositorio_producto.dart';
import '../../../../backend/features/productos/repositorio/repositorio_producto_impl.dart';
import '../../../../backend/share/database/app_db_provider.dart';
import '../../../../core/resultado.dart';
import '../../autenticacion/provider/auth_providers.dart';

// Repositorio

final repositorioProductosProvider = Provider<RepositorioProducto>(
  name: 'repositorioProductosProvider',
  (ref) => RepositorioProductosImpl(
    ref.watch(appDatabaseProvider),
    // Quién firma lo que este repositorio escriba. Es una dependencia
    // del constructor, no un registro global (`CLAUDE.md` §3).
    ref.watch(sesionActualProvider),
  ),
);

// Enums públicos

enum FiltroStock { todos, enStock, stockBajo, sinStock }

// Estado

/// Estado del catálogo: **solo la página visible**, más los filtros y el total.
///
/// Ya no guarda el catálogo entero: el filtrado, el conteo y el recorte los
/// hace SQLite. Quien necesite todos los productos —el POS, los buscadores de
/// factura y orden— usa [catalogoCompletoProvider].
final class ProductosState {
  const ProductosState({
    this.items = const [],
    this.total = 0,
    this.pagina = 0,
    this.tamanoPagina = 25,
    this.busqueda = '',
    this.filtroStock = FiltroStock.todos,
    this.filtroCategoriaId,
  });

  /// Productos de la página actual.
  final List<Producto> items;

  /// Total de productos que cumplen el filtro, en todas las páginas.
  final int total;

  /// Página actual, de base cero.
  final int pagina;
  final int tamanoPagina;

  final String busqueda;
  final FiltroStock filtroStock;

  /// Categoría por la que se filtra. `null` = todas las categorías.
  final int? filtroCategoriaId;

  int get totalPaginas => total <= 0 ? 1 : (total + tamanoPagina - 1) ~/ tamanoPagina;

  bool get hayFiltro =>
      busqueda.isNotEmpty ||
      filtroCategoriaId != null ||
      filtroStock != FiltroStock.todos;

  /// Traduce los filtros de la interfaz a los que entiende el repositorio.
  FiltroProductos get filtro => FiltroProductos(
        busqueda: busqueda,
        categoriaId: filtroCategoriaId,
        soloEnStock: filtroStock == FiltroStock.enStock,
        soloStockBajo: filtroStock == FiltroStock.stockBajo,
        soloSinStock: filtroStock == FiltroStock.sinStock,
      );

  /// Centinela para distinguir "no tocar [filtroCategoriaId]" de "ponerlo en
  /// null" (= quitar el filtro de categoría), que con `??` serían lo mismo.
  static const Object _sinCambio = Object();

  ProductosState copyWith({
    List<Producto>? items,
    int? total,
    int? pagina,
    int? tamanoPagina,
    String? busqueda,
    FiltroStock? filtroStock,
    Object? filtroCategoriaId = _sinCambio,
  }) =>
      ProductosState(
        items:        items        ?? this.items,
        total:        total        ?? this.total,
        pagina:       pagina       ?? this.pagina,
        tamanoPagina: tamanoPagina ?? this.tamanoPagina,
        busqueda:     busqueda     ?? this.busqueda,
        filtroStock:  filtroStock  ?? this.filtroStock,
        filtroCategoriaId: identical(filtroCategoriaId, _sinCambio)
            ? this.filtroCategoriaId
            : filtroCategoriaId as int?,
      );
}

// Notifier

class ProductosNotifier extends AsyncNotifier<ProductosState> {
  late final RepositorioProducto _repo;
  StreamSubscription<PaginaProductos>? _sub;

  @override
  Future<ProductosState> build() async {
    _repo = ref.watch(repositorioProductosProvider);
    ref.onDispose(() => _sub?.cancel());

    const inicial = ProductosState();
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
  void _suscribir(ProductosState estado) {
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

  void _aplicar(ProductosState nuevo) {
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

  void filtrarPorStock(FiltroStock filtro) {
    final actual = state.value;
    if (actual == null || actual.filtroStock == filtro) return;
    _aplicar(actual.copyWith(filtroStock: filtro, pagina: 0));
  }

  /// Filtra por categoría. `null` quita el filtro y muestra todas.
  void filtrarPorCategoria(int? categoriaId) {
    final actual = state.value;
    if (actual == null || actual.filtroCategoriaId == categoriaId) return;
    _aplicar(actual.copyWith(filtroCategoriaId: categoriaId, pagina: 0));
  }

  void irAPagina(int pagina) {
    final actual = state.value;
    if (actual == null || pagina == actual.pagina) return;
    if (pagina < 0 || pagina >= actual.totalPaginas) return;
    _aplicar(actual.copyWith(pagina: pagina));
  }

  // Generación de SKU a partir de la categoría seleccionada.
  //
  // Consulta el catálogo completo: el SKU debe ser único en toda la tabla,
  // no solo dentro de la página que se está viendo.

  // Mutaciones

  Future<Resultado> crear(Producto producto) async {
    if (await _repo.existeNombre(producto.nombre)) {
      return Fallo(
        MotivoFallo.nombreDuplicado,
        'Ya existe un producto con el nombre "${producto.nombre}".',
      );
    }
    // Al crear, el SKU viene vacío y lo asigna el repositorio con su
    // consecutivo; solo hay algo que comprobar si llegó uno puesto.
    if (producto.sku.trim().isNotEmpty && await _repo.existeSku(producto.sku)) {
      return Fallo(
        MotivoFallo.skuDuplicado,
        'El SKU "${producto.sku}" ya está en uso.',
      );
    }
    try {
      await _repo.crear(producto);
      return const Exito();
    } catch (e) {
      return Fallo(
        MotivoFallo.persistencia,
        'Error al crear el producto: $e',
      );
    }
  }

  Future<Resultado> actualizar(Producto producto) async {
    if (await _repo.existeNombre(producto.nombre, excludirId: producto.id)) {
      return Fallo(
        MotivoFallo.nombreDuplicado,
        'Ya existe un producto con el nombre "${producto.nombre}".',
      );
    }
    if (await _repo.existeSku(producto.sku, excludirId: producto.id)) {
      return Fallo(
        MotivoFallo.skuDuplicado,
        'El SKU "${producto.sku}" ya está en uso por otro producto.',
      );
    }
    try {
      await _repo.actualizar(producto);
      return const Exito();
    } catch (e) {
      return Fallo(
        MotivoFallo.persistencia,
        'Error al actualizar el producto: $e',
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
        'Error al eliminar el producto: $e',
      );
    }
  }
}

// Providers públicos

final productosProvider =
    AsyncNotifierProvider<ProductosNotifier, ProductosState>(
  ProductosNotifier.new,
  name: 'productosProvider',
);

/// Catálogo completo, en vivo.
///
/// Para lo que necesita buscar sobre **todo** el inventario: el punto de
/// venta y los buscadores de factura y de orden. La tabla de Productos no lo
/// usa — esa va paginada contra la base de datos.
final catalogoCompletoProvider = StreamProvider<List<Producto>>(
  name: 'catalogoCompletoProvider',
  (ref) => ref.watch(repositorioProductosProvider).observarTodos(),
);

/// Productos de la página actual.
final productosFiltradosProvider = Provider<List<Producto>>(
  name: 'productosFiltradosProvider',
  (ref) => ref.watch(productosProvider).value?.items ?? const [],
);

/// Conteos del catálogo entero, para el encabezado. Resueltos con COUNT en SQL.
final productosResumenProvider =
    StreamProvider<({int total, int enStock, int stockBajo, int sinStock})>(
  name: 'productosResumenProvider',
  (ref) => ref.watch(repositorioProductosProvider).observarResumen(),
);

/// Conteos por estado de stock **dentro del filtro activo**, para los chips.
///
/// Se separa de [productosResumenProvider] porque los números tienen que
/// coincidir con lo que la tabla muestra: con la categoría "Frenos" activa,
/// "Stock bajo 4" son los cuatro frenos bajos, no los de todo el catálogo.
/// El `select` devuelve un record —igualdad estructural—, así que cambiar de
/// chip no reabre esta consulta.
final conteoStockProvider =
    StreamProvider<({int total, int enStock, int stockBajo, int sinStock})>(
  name: 'conteoStockProvider',
  (ref) {
    final ambito = ref.watch(
      productosProvider.select(
        (s) => (
          busqueda: s.value?.busqueda ?? '',
          categoriaId: s.value?.filtroCategoriaId,
        ),
      ),
    );

    return ref.watch(repositorioProductosProvider).observarResumen(
          filtro: FiltroProductos(
            busqueda: ambito.busqueda,
            categoriaId: ambito.categoriaId,
          ),
        );
  },
);

/// `true` cuando hay búsqueda o algún filtro activo.
final hayFiltroProductosProvider = Provider<bool>(
  name: 'hayFiltroProductosProvider',
  (ref) => ref.watch(
    productosProvider.select((s) => s.value?.hayFiltro ?? false),
  ),
);
