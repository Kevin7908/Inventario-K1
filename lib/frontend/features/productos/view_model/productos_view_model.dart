import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../../backend/features/productos/repositorio/repositorio_producto.dart';

// Enums públicos

enum EstadoProductos { inicial, cargando, cargado, error }

enum FiltroStock { todos, enStock, stockBajo, sinStock }

//ViewModel

class ProductosViewModel extends ChangeNotifier {
  final RepositorioProducto _repositorio;

  ProductosViewModel(this._repositorio) {
    _iniciarStream();
  }

  // Estado interno

  EstadoProductos _estado = EstadoProductos.cargando;
  List<Producto> _productos = [];
  List<Producto> _productosFiltrados = [];
  String _consultaBusqueda = '';
  FiltroStock _filtroStock = FiltroStock.todos;
  String? _mensajeError;

  /// Suscripción al stream de Drift. Se cancela en dispose().
  StreamSubscription<List<Producto>>? _subscription;

  // Getters públicos

  EstadoProductos get estado => _estado;
  bool get estaCargando => _estado == EstadoProductos.cargando;
  String? get mensajeError => _mensajeError;
  String get consultaBusqueda => _consultaBusqueda;
  FiltroStock get filtroStock => _filtroStock;

  /// O(1): devuelve la lista ya calculada. Nunca itera en build.
  List<Producto> get productos => _productosFiltrados;

  // Stream reactivo

  /// Suscribe al stream de Drift. Cualquier cambio en la BD (INSERT, UPDATE,
  /// DELETE) emite automáticamente una nueva lista  _reaccionarAlStream.
  void _iniciarStream() {
    _subscription = _repositorio.observarTodos().listen(
      _reaccionarAlStream,
      onError: _manejarErrorStream,
    );
  }

  void _reaccionarAlStream(List<Producto> nuevaLista) {
    _productos = nuevaLista;
    _estado = EstadoProductos.cargado;
    _mensajeError = null;
    _aplicarFiltros();
    notifyListeners();
  }

  void _manejarErrorStream(Object error) {
    _mensajeError = 'Error al escuchar productos: $error';
    _estado = EstadoProductos.error;
    notifyListeners();
  }


  // Recalcula _productosFiltrados. Se llama SOLO cuando:
  //   1. Drift emite una nueva lista (nuevo dato de BD).
  //   2. El usuario cambia el texto de búsqueda.
  //   3. El usuario cambia el filtro de stock.
  void _aplicarFiltros() {
    var lista = _productos;

    // Filtro de texto — solo itera si hay query real
    if (_consultaBusqueda.isNotEmpty) {
      final q = _consultaBusqueda.toLowerCase();
      lista = lista.where((p) {
        return p.nombre.toLowerCase().contains(q) ||
            p.sku.toLowerCase().contains(q) ||
            (p.categoriaNombre?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    // Filtro de stock
    switch (_filtroStock) {
      case FiltroStock.enStock:
        lista = lista
            .where((p) => p.estadoStock == EstadoStock.enStock)
            .toList();
      case FiltroStock.stockBajo:
        lista = lista
            .where((p) => p.estadoStock == EstadoStock.stockBajo)
            .toList();
      case FiltroStock.sinStock:
        lista = lista
            .where((p) => p.estadoStock == EstadoStock.sinStock)
            .toList();
      case FiltroStock.todos:
        // Sin filtro adicional — lista ya está asignada arriba
        break;
    }

    _productosFiltrados = lista;
  }

  // Filtros y búsqueda

  /// Actualiza el texto de búsqueda con guard de igualdad
  /// si el valor no cambió realmente (protege contra debounce redundante).
  void buscar(String query) {
    final trimmed = query.trim();
    if (_consultaBusqueda == trimmed) return;
    _consultaBusqueda = trimmed;
    _aplicarFiltros();
    notifyListeners();
  }

  void filtrarPorStock(FiltroStock filtro) {
    if (_filtroStock == filtro) return;
    _filtroStock = filtro;
    _aplicarFiltros();
    notifyListeners();
  }

  Future<bool> crearProducto({
    required String sku,
    required String nombre,
    String? descripcion,
    int? categoriaId,
    String? categoriaNombre,
    int? unidadMedidaId,
    String? unidadMedidaNombre,
    int? proveedorId,
    String? proveedorNombre,
    required double precioCompra,
    required double precioVenta,
    double? precioVentaTaller,
    double stockActual = 0,
    double stockMinimo = 0,
    String? ubicacionBodega,
    String? imagenUrl,
    bool aplicaIva = true,
    bool activo = true,
  }) async {
    _mensajeError = null;

    if (await _repositorio.existeSku(sku)) {
      _mensajeError = 'El SKU "$sku" ya está en uso.';
      notifyListeners();
      return false;
    }

    try {
      await _repositorio.crear(Producto(
        sku: sku,
        nombre: nombre,
        descripcion: descripcion,
        categoriaId: categoriaId,
        categoriaNombre: categoriaNombre,
        unidadMedidaId: unidadMedidaId,
        unidadMedidaNombre: unidadMedidaNombre,
        proveedorId: proveedorId,
        proveedorNombre: proveedorNombre,
        precioCompra: precioCompra,
        precioVenta: precioVenta,
        precioVentaTaller: precioVentaTaller,
        stockActual: stockActual,
        stockMinimo: stockMinimo,
        ubicacionBodega: ubicacionBodega,
        imagenUrl: imagenUrl,
        aplicaIva: aplicaIva,
        activo: activo,
      ));
      // Drift emitirá el nuevo estado via stream → no hay notifyListeners aquí.
      return true;
    } catch (e) {
      _mensajeError = 'Error al crear el producto: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> actualizarProducto({
    required int id,
    required String sku,
    required String nombre,
    String? descripcion,
    int? categoriaId,
    String? categoriaNombre,
    int? unidadMedidaId,
    String? unidadMedidaNombre,
    int? proveedorId,
    String? proveedorNombre,
    required double precioCompra,
    required double precioVenta,
    double? precioVentaTaller,
    double stockActual = 0,
    double stockMinimo = 0,
    String? ubicacionBodega,
    String? imagenUrl,
    bool aplicaIva = true,
    bool activo = true,
  }) async {
    _mensajeError = null;

    if (await _repositorio.existeSku(sku, excludirId: id)) {
      _mensajeError = 'El SKU "$sku" ya está en uso por otro producto.';
      notifyListeners();
      return false;
    }

    try {
      await _repositorio.actualizar(Producto(
        id: id,
        sku: sku,
        nombre: nombre,
        descripcion: descripcion,
        categoriaId: categoriaId,
        categoriaNombre: categoriaNombre,
        unidadMedidaId: unidadMedidaId,
        unidadMedidaNombre: unidadMedidaNombre,
        proveedorId: proveedorId,
        proveedorNombre: proveedorNombre,
        precioCompra: precioCompra,
        precioVenta: precioVenta,
        precioVentaTaller: precioVentaTaller,
        stockActual: stockActual,
        stockMinimo: stockMinimo,
        ubicacionBodega: ubicacionBodega,
        imagenUrl: imagenUrl,
        aplicaIva: aplicaIva,
        activo: activo,
      ));
      // El stream de Drift actualizará la UI automáticamente.
      return true;
    } catch (e) {
      _mensajeError = 'Error al actualizar el producto: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> eliminarProducto(int id) async {
    _mensajeError = null;
    try {
      await _repositorio.eliminar(id);
      // El stream de Drift actualizará la UI automáticamente.
      return true;
    } catch (e) {
      _mensajeError = 'Error al eliminar el producto: $e';
      notifyListeners();
      return false;
    }
  }

  void limpiarError() {
    _mensajeError = null;
    notifyListeners();
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    // CRÍTICO: cancelar siempre el stream para evitar fugas de memoria.
    _subscription?.cancel();
    super.dispose();
  }
}