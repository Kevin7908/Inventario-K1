import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../backend/features/categorias/modelo/categoria.dart';
import '../../../../backend/features/categorias/repositorio/repositorio_categorias.dart';

enum EstadoCategorias { inicial, cargando, cargado, error }

// ViewModel de Categorías
// Recibe el repositorio por inyección (viene del locator en la Vista).
// NUNCA importa get_it directamente — eso es responsabilidad de la Vista.
class CategoriasViewModel extends ChangeNotifier {
  final RepositorioCategorias _repositorio;

  CategoriasViewModel(this._repositorio) {
    _cambiarEstado(EstadoCategorias.cargando);
    _suscripcion = _repositorio.observarTodas().listen(
      (lista) {
        _categorias = lista;
        _cambiarEstado(EstadoCategorias.cargado);
      },
      onError: (e) {
        _mensajeError = 'Error al cargar categorías: ${e.toString()}';
        _cambiarEstado(EstadoCategorias.error);
      },
    );
  }

  // Estado
  EstadoCategorias _estado = EstadoCategorias.inicial;
  EstadoCategorias get estado => _estado;

  String? _mensajeError;
  String? get mensajeError => _mensajeError;

  bool get estaCargando => _estado == EstadoCategorias.cargando;

  // Datos
  List<Categoria> _categorias = [];
  StreamSubscription<List<Categoria>>? _suscripcion;

  String _consultaBusqueda = '';
  String get consultaBusqueda => _consultaBusqueda;

  List<Categoria> get categorias => _categoriasFiltradas;

  List<Categoria> get _categoriasFiltradas {
    if (_consultaBusqueda.isEmpty) return List.unmodifiable(_categorias);
    final consulta = _consultaBusqueda.toLowerCase();
    return _categorias
        .where((c) => c.nombre.toLowerCase().contains(consulta))
        .toList();
  }

  Categoria? _categoriaSeleccionada;
  Categoria? get categoriaSeleccionada => _categoriaSeleccionada;

  // Acciones
  Future<void> cargarCategorias() async {
    await _suscripcion?.cancel();
    _cambiarEstado(EstadoCategorias.cargando);
    _suscripcion = _repositorio.observarTodas().listen(
      (lista) {
        _categorias = lista;
        _cambiarEstado(EstadoCategorias.cargado);
      },
      onError: (e) {
        _mensajeError = 'Error al cargar categorías: ${e.toString()}';
        _cambiarEstado(EstadoCategorias.error);
      },
    );
  }

  void buscar(String consulta) {
    _consultaBusqueda = consulta;
    notifyListeners();
  }

  void seleccionarCategoria(Categoria? categoria) {
    _categoriaSeleccionada = categoria;
    notifyListeners();
  }

  void limpiarSeleccion() {
    _categoriaSeleccionada = null;
    notifyListeners();
  }

  Future<bool> crearCategoria({
    required String nombre,
    String? descripcion,
    String colorHex = '#3B82F6',
    String icono = 'category',
  }) async {
    final errorValidacion = await _validarNombre(nombre);
    if (errorValidacion != null) {
      _mensajeError = errorValidacion;
      notifyListeners();
      return false;
    }

    _cambiarEstado(EstadoCategorias.cargando);
    try {
      final nueva = Categoria(
        nombre: nombre.trim(),
        descripcion: descripcion?.trim(),
        colorHex: colorHex,
        icono: icono,
        creadoEn: DateTime.now(),
        actualizadoEn: DateTime.now(),
      );
      await _repositorio.crear(nueva);
      return true;
    } catch (e) {
      _mensajeError = 'Error al crear categoría: ${e.toString()}';
      _cambiarEstado(EstadoCategorias.error);
      return false;
    }
  }

  Future<bool> actualizarCategoria({
    required int id,
    required String nombre,
    String? descripcion,
    String? colorHex,
    String? icono,
  }) async {
    final errorValidacion = await _validarNombre(nombre, excludirId: id);
    if (errorValidacion != null) {
      _mensajeError = errorValidacion;
      notifyListeners();
      return false;
    }

    _cambiarEstado(EstadoCategorias.cargando);
    try {
      final actual = _categorias.firstWhere((c) => c.id == id);
      final actualizada = actual.copyWith(
        nombre: nombre.trim(),
        descripcion: descripcion?.trim(),
        colorHex: colorHex,
        icono: icono,
        actualizadoEn: DateTime.now(),
      );
      await _repositorio.actualizar(actualizada);
      return true;
    } catch (e) {
      _mensajeError = 'Error al actualizar categoría: ${e.toString()}';
      _cambiarEstado(EstadoCategorias.error);
      return false;
    }
  }

  Future<bool> eliminarCategoria(int id) async {
    _cambiarEstado(EstadoCategorias.cargando);
    try {
      await _repositorio.eliminar(id);
      if (_categoriaSeleccionada?.id == id) _categoriaSeleccionada = null;
      return true;
    } catch (e) {
      _mensajeError = 'Error al eliminar categoría: ${e.toString()}';
      _cambiarEstado(EstadoCategorias.error);
      return false;
    }
  }

  void limpiarError() {
    _mensajeError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    super.dispose();
  }

  // Privados

  void _cambiarEstado(EstadoCategorias nuevoEstado) {
    _estado = nuevoEstado;
    notifyListeners();
  }

  Future<String?> _validarNombre(String nombre, {int? excludirId}) async {
    if (nombre.trim().isEmpty) return 'El nombre no puede estar vacío';
    if (nombre.trim().length < 2) {
      return 'El nombre debe tener al menos 2 caracteres';
    }

    final existe = await _repositorio.existeNombre(
      nombre.trim(),
      excludirId: excludirId,
    );
    if (existe) return 'Ya existe una categoría con ese nombre';
    return null;
  }
}
