// frontend/features/proveedores/view_model/proveedores_view_model.dart

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../backend/features/proveedores/modelo/proveedor.dart';
import '../../../../backend/features/proveedores/repositorio/repositorio_proveedores.dart';

enum EstadoProveedores { inicial, cargando, cargado, error }

class ProveedoresViewModel extends ChangeNotifier {
  final RepositorioProveedores _repositorio;
  late StreamSubscription<List<Proveedor>> _suscripcion;

  ProveedoresViewModel(this._repositorio) {
    _cambiarEstado(EstadoProveedores.cargando);
    _suscripcion = _repositorio.observarTodas().listen(
      (lista) {
        _proveedores = lista;
        _cambiarEstado(EstadoProveedores.cargado);
      },
      onError: (e) {
        _mensajeError = 'Error al cargar proveedores: ${e.toString()}';
        _cambiarEstado(EstadoProveedores.error);
      },
    );
  }

  // ── Estado ────────────────────────────────────────────────────────────────

  EstadoProveedores _estado = EstadoProveedores.inicial;
  EstadoProveedores get estado => _estado;

  String? _mensajeError;
  String? get mensajeError => _mensajeError;

  bool get estaCargando => _estado == EstadoProveedores.cargando;

  // ── Datos ─────────────────────────────────────────────────────────────────

  List<Proveedor> _proveedores = [];

  String _consultaBusqueda = '';
  String get consultaBusqueda => _consultaBusqueda;

  // Filtro por estado activo: null = todos, true = activos, false = inactivos
  bool? _filtroActivo;
  bool? get filtroActivo => _filtroActivo;

  List<Proveedor> get proveedores => _proveedoresFiltrados;

  List<Proveedor> get _proveedoresFiltrados {
    var lista = _proveedores;

    // Filtro por activo
    if (_filtroActivo != null) {
      lista = lista.where((p) => p.activo == _filtroActivo).toList();
    }

    // Filtro por búsqueda
    if (_consultaBusqueda.isNotEmpty) {
      final consulta = _consultaBusqueda.toLowerCase();
      lista = lista.where((p) {
        return p.nombre.toLowerCase().contains(consulta) ||
            (p.nitCedula?.toLowerCase().contains(consulta) ?? false) ||
            (p.ciudad?.toLowerCase().contains(consulta) ?? false) ||
            (p.contacto?.toLowerCase().contains(consulta) ?? false);
      }).toList();
    }

    return List.unmodifiable(lista);
  }

  // Acciones

  Future<void> cargarProveedores() async {
    await _suscripcion.cancel();
    _cambiarEstado(EstadoProveedores.cargando);
    _suscripcion = _repositorio.observarTodas().listen(
      (lista) {
        _proveedores = lista;
        _cambiarEstado(EstadoProveedores.cargado);
      },
      onError: (e) {
        _mensajeError = 'Error al cargar proveedores: ${e.toString()}';
        _cambiarEstado(EstadoProveedores.error);
      },
    );
  }

  void buscar(String consulta) {
    _consultaBusqueda = consulta;
    notifyListeners();
  }

  void filtrarPorActivo(bool? valor) {
    _filtroActivo = valor;
    notifyListeners();
  }

  Future<bool> crearProveedor({
    required String nombre,
    String? nitCedula,
    String? contacto,
    String? telefono,
    String? email,
    String? direccion,
    String? ciudad,
    String? notas,
    bool activo = true,
    String colorHex = '#3B82F6',
    String icono = 'store',
  }) async {
    final error = await _validar(nombre, nitCedula: nitCedula);
    if (error != null) {
      _mensajeError = error;
      notifyListeners();
      return false;
    }

    _cambiarEstado(EstadoProveedores.cargando);
    try {
      final nuevo = Proveedor(
        nombre: nombre.trim(),
        nitCedula: nitCedula?.trim(),
        contacto: contacto?.trim(),
        telefono: telefono?.trim(),
        email: email?.trim(),
        direccion: direccion?.trim(),
        ciudad: ciudad?.trim(),
        notas: notas?.trim(),
        activo: activo,
        colorHex: colorHex,
        icono: icono,
        creadoEn: DateTime.now(),
        actualizadoEn: DateTime.now(),
      );
      await _repositorio.crear(nuevo);
      return true;
    } catch (e) {
      _mensajeError = 'Error al crear proveedor: ${e.toString()}';
      _cambiarEstado(EstadoProveedores.error);
      return false;
    }
  }

  Future<bool> actualizarProveedor({
    required int id,
    required String nombre,
    String? nitCedula,
    String? contacto,
    String? telefono,
    String? email,
    String? direccion,
    String? ciudad,
    String? notas,
    bool? activo,
    String? colorHex,
    String? icono,
  }) async {
    final error = await _validar(nombre, nitCedula: nitCedula, excludirId: id);
    if (error != null) {
      _mensajeError = error;
      notifyListeners();
      return false;
    }

    _cambiarEstado(EstadoProveedores.cargando);
    try {
      final actual = _proveedores.firstWhere((p) => p.id == id);
      final actualizado = actual.copyWith(
        nombre: nombre.trim(),
        nitCedula: nitCedula?.trim(),
        contacto: contacto?.trim(),
        telefono: telefono?.trim(),
        email: email?.trim(),
        direccion: direccion?.trim(),
        ciudad: ciudad?.trim(),
        notas: notas?.trim(),
        activo: activo,
        colorHex: colorHex,
        icono: icono,
        actualizadoEn: DateTime.now(),
      );
      await _repositorio.actualizar(actualizado);
      return true;
    } catch (e) {
      _mensajeError = 'Error al actualizar proveedor: ${e.toString()}';
      _cambiarEstado(EstadoProveedores.error);
      return false;
    }
  }

  Future<bool> eliminarProveedor(int id) async {
    _cambiarEstado(EstadoProveedores.cargando);
    try {
      await _repositorio.eliminar(id);
      _proveedores.removeWhere((p) => p.id == id);
      return true;
    } catch (e) {
      _mensajeError = 'Error al eliminar proveedor: ${e.toString()}';
      _cambiarEstado(EstadoProveedores.error);
      return false;
    }
  }

  void limpiarError() {
    _mensajeError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _suscripcion.cancel();
    super.dispose();
  }

  // Privados

  void _cambiarEstado(EstadoProveedores nuevoEstado) {
    _estado = nuevoEstado;
    notifyListeners();
  }

  Future<String?> _validar(
    String nombre, {
    String? nitCedula,
    int? excludirId,
  }) async {
    if (nombre.trim().isEmpty) return 'El nombre no puede estar vacío';
    if (nombre.trim().length < 2) {
      return 'El nombre debe tener al menos 2 caracteres';
    }
    final existeNombre = await _repositorio.existeNombre(
      nombre.trim(),
      excludirId: excludirId,
    );
    if (existeNombre) return 'Ya existe un proveedor con ese nombre';

    if (nitCedula != null && nitCedula.trim().isNotEmpty) {
      final existeNit = await _repositorio.existeNit(
        nitCedula.trim(),
        excludirId: excludirId,
      );
      if (existeNit) return 'Ya existe un proveedor con ese NIT/Cédula';
    }

    return null;
  }
}
