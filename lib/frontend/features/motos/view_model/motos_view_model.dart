import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../../backend/features/motos/modelo/moto.dart';
import '../../../../backend/features/motos/repositorio/repositorio_motos.dart';

enum EstadoMotos { cargando, cargado, error }

/// ViewModel reactivo para el módulo de Motos.
/// Se suscribe al stream del repositorio en el constructor.
class MotosViewModel extends ChangeNotifier {
  final RepositorioMotos _repositorio;

  EstadoMotos _estado = EstadoMotos.cargando;
  List<Moto> _motos = [];
  List<Moto> _motosFiltradas = [];
  String? _mensajeError;
  bool _procesando = false;
  String _textoBusqueda = '';

  StreamSubscription<List<Moto>>? _suscripcion;

  EstadoMotos get estado => _estado;
  List<Moto> get motos => _motosFiltradas;
  String? get mensajeError => _mensajeError;
  bool get procesando => _procesando;
  String get textoBusqueda => _textoBusqueda;
  bool get hayMotos => _motosFiltradas.isNotEmpty;

  MotosViewModel(this._repositorio) {
    _iniciarStream();
  }

  void _iniciarStream() {
    _estado = EstadoMotos.cargando;
    notifyListeners();

    _suscripcion = _repositorio.observarTodos().listen(
      (lista) {
        _motos = lista;
        _aplicarFiltro();
        _estado = EstadoMotos.cargado;
        notifyListeners();
      },
      onError: (e) {
        _mensajeError = e.toString();
        _estado = EstadoMotos.error;
        notifyListeners();
      },
    );
  }

  // Búsqueda local

  void buscar(String texto) {
    _textoBusqueda = texto;
    _aplicarFiltro();
    notifyListeners();
  }

  void _aplicarFiltro() {
    if (_textoBusqueda.isEmpty) {
      _motosFiltradas = List.from(_motos);
      return;
    }
    final termino = _textoBusqueda.toLowerCase();
    _motosFiltradas = _motos.where((m) {
      return m.marca.toLowerCase().contains(termino) ||
          m.modelo.toLowerCase().contains(termino) ||
          (m.placa?.toLowerCase().contains(termino) ?? false) ||
          (m.color?.toLowerCase().contains(termino) ?? false) ||
          (m.vin?.toLowerCase().contains(termino) ?? false) ||
          (m.nombreCliente?.toLowerCase().contains(termino) ?? false);
    }).toList();
  }

  void limpiarBusqueda() => buscar('');

  //CRUD 

  /// Crea una nueva moto. Devuelve null si tuvo éxito o el mensaje de error.
  Future<String?> crear(Moto moto) async {
    _procesando = true;
    notifyListeners();
    try {
      await _repositorio.crear(moto);
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _procesando = false;
      notifyListeners();
    }
  }

  /// Actualiza una moto existente.
  Future<String?> actualizar(Moto moto) async {
    _procesando = true;
    notifyListeners();
    try {
      await _repositorio.actualizar(moto);
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _procesando = false;
      notifyListeners();
    }
  }

  /// Elimina una moto por id.
  Future<String?> eliminar(int id) async {
    _procesando = true;
    notifyListeners();
    try {
      await _repositorio.eliminar(id);
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _procesando = false;
      notifyListeners();
    }
  }

  // Dispose 

  @override
  void dispose() {
    _suscripcion?.cancel();
    super.dispose();
  }
}