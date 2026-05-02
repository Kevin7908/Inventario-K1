import 'package:flutter/foundation.dart';

import '../../../../backend/features/autenticacion/excepciones/excepciones_auth.dart';
import '../../../../backend/features/autenticacion/modelo/usuario.dart';
import '../../../../backend/features/autenticacion/repositorio/repositorio_auth.dart';
import '../../../../backend/share/servicios/servicio_email.dart';

enum EstadoAuth { inicial, cargando, autenticado, error, accesoDenegado }

class AuthViewModel extends ChangeNotifier {
  final RepositorioAuth _repositorio;
  final ServicioEmail _servicioEmail;

  AuthViewModel(this._repositorio, this._servicioEmail);

  // ─── Estado interno ───────────────────────────────────────────────────────

  EstadoAuth _estado = EstadoAuth.inicial;
  Usuario? _usuarioActual;
  String? _mensajeError;

  EstadoAuth get estado => _estado;
  Usuario? get usuarioActual => _usuarioActual;
  String? get mensajeError => _mensajeError;

  bool get estaCargando => _estado == EstadoAuth.cargando;
  bool get estaAutenticado => _estado == EstadoAuth.autenticado;
  bool get estaActivo => _usuarioActual?.estaActivo ?? false;
  bool get esAdmin => _usuarioActual?.esAdmin ?? false;

  // ─── Login ────────────────────────────────────────────────────────────────

  Future<void> iniciarSesion({
    required String usuario,
    required String password,
  }) async {
    if (estaCargando) return;

    _estado = EstadoAuth.cargando;
    _mensajeError = null;
    notifyListeners();

    try {
      final usuarioObj = await _repositorio.verificarCredenciales(
        usuario: usuario.trim(),
        passwordPlano: password,
      );

      _usuarioActual = usuarioObj;
      _estado = EstadoAuth.autenticado;
    } on AccesoDesactivadoException catch (e) {
      _estado = EstadoAuth.accesoDenegado;
      _mensajeError = e.mensaje;
      _servicioEmail
          .enviarNotificacionAccesoDenegado(
            email: _usuarioActual?.email ?? '',
            nombre: usuario.trim(),
          )
          .ignore();
    } on CredencialesInvalidasException catch (e) {
      _estado = EstadoAuth.error;
      _mensajeError = e.mensaje;
    } catch (e, st) {
      debugPrint('AuthViewModel.iniciarSesion: $e\n$st');
      _estado = EstadoAuth.error;
      _mensajeError = 'Ocurrió un error inesperado. Intenta de nuevo.';
    } finally {
      notifyListeners();
    }
  }

  // ─── Registro ─────────────────────────────────────────────────────────────

  Future<bool> registrarUsuario({
    required String nombre,
    required String usuario,
    required String email,
    required String password,
    bool esAdmin = false,
  }) async {
    if (estaCargando) return false;

    _estado = EstadoAuth.cargando;
    _mensajeError = null;
    notifyListeners();

    try {
      final usuarioObj = await _repositorio.registrarUsuario(
        nombre: nombre.trim(),
        usuario: usuario.trim(),
        email: email.trim(),
        passwordPlano: password,
        esAdmin: esAdmin,
      );

      _servicioEmail
          .enviarBienvenida(
            email: usuarioObj.email,
            nombre: usuarioObj.nombre,
          )
          .ignore();

      _estado = EstadoAuth.inicial;
      notifyListeners();
      return true;
    } on UsuarioYaExisteException catch (e) {
      _estado = EstadoAuth.error;
      _mensajeError = e.mensaje;
      notifyListeners();
      return false;
    } catch (e, st) {
      debugPrint('AuthViewModel.registrarUsuario: $e\n$st');
      _estado = EstadoAuth.error;
      _mensajeError = 'Error al registrar el usuario.';
      notifyListeners();
      return false;
    }
  }

  // ─── Cambiar estado activo (solo admin) ───────────────────────────────────

  Future<bool> cambiarEstadoUsuario({
    required int usuarioId,
    required bool nuevoEstado,
    required String emailUsuario,
    required String nombreUsuario,
  }) async {
    if (_usuarioActual == null || !_usuarioActual!.esAdmin) {
      _mensajeError = 'Solo un administrador puede realizar esta acción.';
      notifyListeners();
      return false;
    }

    try {
      await _repositorio.cambiarEstadoActivo(
        adminId: _usuarioActual!.id!,
        usuarioId: usuarioId,
        nuevoEstado: nuevoEstado,
      );

      _servicioEmail
          .enviarNotificacionEstadoCuenta(
            email: emailUsuario,
            nombre: nombreUsuario,
            estaActivo: nuevoEstado,
          )
          .ignore();

      return true;
    } on SinPermisosException catch (e) {
      _mensajeError = e.mensaje;
      notifyListeners();
      return false;
    } catch (e, st) {
      debugPrint('AuthViewModel.cambiarEstadoUsuario: $e\n$st');
      _mensajeError = 'Error al cambiar el estado del usuario.';
      notifyListeners();
      return false;
    }
  }

  // ─── Cerrar sesión ────────────────────────────────────────────────────────

  Future<void> cerrarSesion() async {
    _usuarioActual = null;
    _estado = EstadoAuth.inicial;
    _mensajeError = null;
    notifyListeners();
  }

  // ─── Utilidades ──────────────────────────────────────────────────────────

  void limpiarError() {
    if (_mensajeError != null) {
      _mensajeError = null;
      notifyListeners();
    }
  }

  Stream<List<Usuario>> observarUsuarios() {
    return _repositorio.observarTodosUsuarios();
  }
}