import 'package:flutter/foundation.dart';

import '../../../../backend/features/unidades_medida/modelo/unidad_medida.dart';
import '../../../../backend/features/unidades_medida/repositorio/repositorio_unidades_medida.dart';

enum EstadoUnidadesMedida { inicial, cargando, cargado, error }

// ViewModel de Unidades de Medida
// Recibe el repositorio por inyección (viene del locator en la Vista).
class UnidadesMedidaViewModel extends ChangeNotifier {
  final RepositorioUnidadesMedida _repositorio;

  UnidadesMedidaViewModel(this._repositorio) {
    cargarUnidades();
  }

  // Estado
  EstadoUnidadesMedida _estado = EstadoUnidadesMedida.inicial;
  EstadoUnidadesMedida get estado => _estado;

  String? _mensajeError;
  String? get mensajeError => _mensajeError;

  bool get estaCargando => _estado == EstadoUnidadesMedida.cargando;

  // Datos
  List<UnidadMedida> _unidades = [];

  String _consultaBusqueda = '';
  String get consultaBusqueda => _consultaBusqueda;

  String _filtroTipo = 'todos';
  String get filtroTipo => _filtroTipo;

  List<UnidadMedida> get unidades => _unidadesFiltradas;

  List<UnidadMedida> get _unidadesFiltradas {
    var lista = List<UnidadMedida>.from(_unidades);
    if (_filtroTipo != 'todos') {
      lista = lista.where((u) => u.tipo == _filtroTipo).toList();
    }
    if (_consultaBusqueda.isNotEmpty) {
      final consulta = _consultaBusqueda.toLowerCase();
      lista = lista
          .where(
            (u) =>
                u.nombre.toLowerCase().contains(consulta) ||
                u.abreviatura.toLowerCase().contains(consulta),
          )
          .toList();
    }
    return lista;
  }

  UnidadMedida? _unidadSeleccionada;
  UnidadMedida? get unidadSeleccionada => _unidadSeleccionada;

  // Acciones

  Future<void> cargarUnidades() async {
    _cambiarEstado(EstadoUnidadesMedida.cargando);
    try {
      _unidades = await _repositorio.obtenerTodas();
      _cambiarEstado(EstadoUnidadesMedida.cargado);
    } catch (e) {
      _mensajeError = 'Error al cargar unidades: ${e.toString()}';
      _cambiarEstado(EstadoUnidadesMedida.error);
    }
  }

  void buscar(String consulta) {
    _consultaBusqueda = consulta;
    notifyListeners();
  }

  void filtrarPorTipo(String tipo) {
    _filtroTipo = tipo;
    notifyListeners();
  }

  void seleccionarUnidad(UnidadMedida? unidad) {
    _unidadSeleccionada = unidad;
    notifyListeners();
  }

  void limpiarSeleccion() {
    _unidadSeleccionada = null;
    notifyListeners();
  }

  Future<bool> crearUnidad({
    required String nombre,
    required String abreviatura,
    String tipo = 'unidad',
    String? descripcion,
  }) async {
    final error = await _validar(nombre, abreviatura);
    if (error != null) {
      _mensajeError = error;
      notifyListeners();
      return false;
    }

    _cambiarEstado(EstadoUnidadesMedida.cargando);
    try {
      final nueva = UnidadMedida(
        nombre: nombre.trim(),
        abreviatura: abreviatura.trim(),
        tipo: tipo,
        descripcion: descripcion?.trim(),
        creadoEn: DateTime.now(),
        actualizadoEn: DateTime.now(),
      );
      final creada = await _repositorio.crear(nueva);
      _unidades.add(creada);
      _cambiarEstado(EstadoUnidadesMedida.cargado);
      return true;
    } catch (e) {
      _mensajeError = 'Error al crear unidad: ${e.toString()}';
      _cambiarEstado(EstadoUnidadesMedida.error);
      return false;
    }
  }

  Future<bool> actualizarUnidad({
    required int id,
    required String nombre,
    required String abreviatura,
    String? tipo,
    String? descripcion,
  }) async {
    final error = await _validar(nombre, abreviatura, excludirId: id);
    if (error != null) {
      _mensajeError = error;
      notifyListeners();
      return false;
    }

    _cambiarEstado(EstadoUnidadesMedida.cargando);
    try {
      final actual = _unidades.firstWhere((u) => u.id == id);
      final actualizada = actual.copyWith(
        nombre: nombre.trim(),
        abreviatura: abreviatura.trim(),
        tipo: tipo,
        descripcion: descripcion?.trim(),
        actualizadoEn: DateTime.now(),
      );
      final resultado = await _repositorio.actualizar(actualizada);
      final indice = _unidades.indexWhere((u) => u.id == id);
      _unidades[indice] = resultado;
      _cambiarEstado(EstadoUnidadesMedida.cargado);
      return true;
    } catch (e) {
      _mensajeError = 'Error al actualizar unidad: ${e.toString()}';
      _cambiarEstado(EstadoUnidadesMedida.error);
      return false;
    }
  }

  Future<bool> eliminarUnidad(int id) async {
    _cambiarEstado(EstadoUnidadesMedida.cargando);
    try {
      await _repositorio.eliminar(id);
      _unidades.removeWhere((u) => u.id == id);
      if (_unidadSeleccionada?.id == id) _unidadSeleccionada = null;
      _cambiarEstado(EstadoUnidadesMedida.cargado);
      return true;
    } catch (e) {
      _mensajeError = 'Error al eliminar unidad: ${e.toString()}';
      _cambiarEstado(EstadoUnidadesMedida.error);
      return false;
    }
  }

  void limpiarError() {
    _mensajeError = null;
    notifyListeners();
  }

  // Privados

  void _cambiarEstado(EstadoUnidadesMedida nuevoEstado) {
    _estado = nuevoEstado;
    notifyListeners();
  }

  Future<String?> _validar(
    String nombre,
    String abreviatura, {
    int? excludirId,
  }) async {
    if (nombre.trim().isEmpty) return 'El nombre no puede estar vacío';
    if (abreviatura.trim().isEmpty)
      return 'La abreviatura no puede estar vacía';
    if (await _repositorio.existeNombre(
      nombre.trim(),
      excludirId: excludirId,
    )) {
      return 'Ya existe una unidad con ese nombre';
    }
    if (await _repositorio.existeAbreviatura(
      abreviatura.trim(),
      excludirId: excludirId,
    )) {
      return 'Ya existe una unidad con esa abreviatura';
    }
    return null;
  }
}
