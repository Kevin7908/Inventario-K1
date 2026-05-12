import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../../backend/features/clientes/repositorio/repositorio_cliente.dart';



enum EstadoClientes { cargando, cargado, error }

// Se suscribe al stream del repositorio en el constructor para reactividad.
class ClientesViewModel extends ChangeNotifier {
  final RepositorioClientes _repositorio;

  EstadoClientes _estado = EstadoClientes.cargando;
  List<Cliente> _clientes = [];
  List<Cliente> _clientesFiltrados = [];
  String? _mensajeError;
  bool _procesando = false;
  String _textoBusqueda = '';

  StreamSubscription<List<Cliente>>? _suscripcion;

  EstadoClientes get estado => _estado;
  List<Cliente> get clientes => _clientesFiltrados;
  String? get mensajeError => _mensajeError;
  bool get procesando => _procesando;
  String get textoBusqueda => _textoBusqueda;
  bool get hayClientes => _clientesFiltrados.isNotEmpty;

  ClientesViewModel(this._repositorio) {
    _iniciarStream();
  }

  void _iniciarStream() {
    _estado = EstadoClientes.cargando;
    notifyListeners();

    _suscripcion = _repositorio.observarTodos().listen(
      (lista) {
        _clientes = lista;
        _aplicarFiltro();
        _estado = EstadoClientes.cargado;
        notifyListeners();
      },
      onError: (e) {
        _mensajeError = e.toString();
        _estado = EstadoClientes.error;
        notifyListeners();
      },
    );
  }

  // Busqueda 
  void buscar(String texto) {
    _textoBusqueda = texto;
    _aplicarFiltro();
    notifyListeners();
  }

  void _aplicarFiltro() {
    if (_textoBusqueda.isEmpty) {
      _clientesFiltrados = List.from(_clientes);
      return;
    }
    final termino = _textoBusqueda.toLowerCase();
    _clientesFiltrados = _clientes.where((c) {
      return c.nombreCompleto.toLowerCase().contains(termino) ||
          (c.cedula?.toLowerCase().contains(termino) ?? false) ||
          (c.telefono?.toLowerCase().contains(termino) ?? false) ||
          (c.email?.toLowerCase().contains(termino) ?? false) ||
          (c.ciudad?.toLowerCase().contains(termino) ?? false);
    }).toList();
  }

  void limpiarBusqueda() => buscar('');


  /// Crea un nuevo cliente. Devuelve null si tuvo exito o el mensaje de error.
  Future<String?> crear(Cliente cliente) async {
    _procesando = true;
    notifyListeners();
    try {
      await _repositorio.crear(cliente);
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _procesando = false;
      notifyListeners();
    }
  }

  /// Actualiza un cliente existente.
  Future<String?> actualizar(Cliente cliente) async {
    _procesando = true;
    notifyListeners();
    try {
      await _repositorio.actualizar(cliente);
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _procesando = false;
      notifyListeners();
    }
  }

  /// Elimina un cliente por id.
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