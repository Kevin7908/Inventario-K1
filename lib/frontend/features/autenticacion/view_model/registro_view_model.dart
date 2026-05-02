import 'package:flutter/foundation.dart';

import '../../../../backend/features/autenticacion/excepciones/excepciones_auth.dart';
import '../../../../backend/features/autenticacion/repositorio/repositorio_auth.dart';
import '../../../../backend/share/servicios/servicio_email.dart';
import '../../../../backend/share/servicios/servicio_verificacion.dart';

// ─── Estados del flujo de registro ───────────────────────────────────────────

enum PasoRegistro {
  datosIniciales,
  verificandoCodigo,
  creandoPassword,
  completado,
}

enum EstadoRegistro { inactivo, cargando, error }

class RegistroViewModel extends ChangeNotifier {
  final RepositorioAuth _repositorio;
  final ServicioEmail _servicioEmail;
  final ServicioVerificacion _servicioVerificacion;

  RegistroViewModel(
    this._repositorio,
    this._servicioEmail,
    this._servicioVerificacion,
  );

  // ─── Estado interno ───────────────────────────────────────────────────────

  PasoRegistro _paso = PasoRegistro.datosIniciales;
  EstadoRegistro _estado = EstadoRegistro.inactivo;
  String? _mensajeError;

  /// Datos retenidos entre pasos
  String _nombreGuardado = '';
  String _usuarioGuardado = '';   // ← NUEVO: username único
  String _emailGuardado = '';

  // ─── Getters públicos ─────────────────────────────────────────────────────

  PasoRegistro get paso => _paso;
  EstadoRegistro get estado => _estado;
  String? get mensajeError => _mensajeError;
  String get nombreGuardado => _nombreGuardado;
  String get usuarioGuardado => _usuarioGuardado;   // ← NUEVO
  String get emailGuardado => _emailGuardado;

  bool get estaCargando => _estado == EstadoRegistro.cargando;

  int get segundosRestantes =>
      _servicioVerificacion.segundosRestantes(_emailGuardado);

  int get intentosRestantes =>
      _servicioVerificacion.intentosRestantes(_emailGuardado);

  // ─── PASO 1: Enviar código OTP ────────────────────────────────────────────

  /// Valida unicidad de email Y usuario, genera el OTP y lo envía.
  Future<void> enviarCodigoVerificacion({
    required String nombre,
    required String usuario,     // ← NUEVO parámetro
    required String email,
  }) async {
    if (estaCargando) return;

    _setEstado(EstadoRegistro.cargando);

    try {
      // Verificar que el email no esté ya en uso
      final porEmail = await _repositorio.obtenerPorEmail(email);
      if (porEmail != null) {
        _setError('Este correo ya está registrado. Inicia sesión.');
        return;
      }

      // Verificar que el nombre de usuario no esté ya en uso
      final porUsuario = await _repositorio.obtenerPorUsuario(usuario);
      if (porUsuario != null) {
        _setError('Ese nombre de usuario ya está tomado. Elige otro.');
        return;
      }

      // Guardar datos para los siguientes pasos
      _nombreGuardado = nombre.trim();
      _usuarioGuardado = usuario.toLowerCase().trim();
      _emailGuardado = email.toLowerCase().trim();

      // Generar código en memoria y enviar correo
      final codigo = _servicioVerificacion.generarCodigo(_emailGuardado);
      await _servicioEmail.enviarCodigoVerificacion(
        email: _emailGuardado,
        codigo: codigo,
        nombre: _nombreGuardado,
      );

      _paso = PasoRegistro.verificandoCodigo;
      _setEstado(EstadoRegistro.inactivo);
    } on Exception catch (e) {
      _setError(
        e.toString().contains('MailerException')
            ? 'No se pudo enviar el correo. Verifica tu conexión.'
            : 'Error inesperado. Intenta de nuevo.',
      );
    }
  }

  // ─── PASO 2: Verificar código OTP ────────────────────────────────────────

  Future<void> verificarCodigo(String codigo) async {
    if (estaCargando) return;

    _setEstado(EstadoRegistro.cargando);
    await Future.delayed(const Duration(milliseconds: 400));

    final resultado = _servicioVerificacion.validarCodigo(
      _emailGuardado,
      codigo,
    );

    if (resultado == ResultadoValidacion.valido) {
      _paso = PasoRegistro.creandoPassword;
      _setEstado(EstadoRegistro.inactivo);
    } else {
      _setError(resultado.mensaje);
    }
  }

  // ─── PASO 2: Reenviar código ──────────────────────────────────────────────

  Future<void> reenviarCodigo() async {
    if (estaCargando || _emailGuardado.isEmpty) return;

    _setEstado(EstadoRegistro.cargando);

    try {
      final codigo = _servicioVerificacion.generarCodigo(_emailGuardado);
      await _servicioEmail.enviarCodigoVerificacion(
        email: _emailGuardado,
        codigo: codigo,
        nombre: _nombreGuardado,
      );
      _mensajeError = null;
      _setEstado(EstadoRegistro.inactivo);
    } catch (_) {
      _setError('No se pudo reenviar el código. Intenta de nuevo.');
    }
  }

  // ─── PASO 3: Crear usuario ────────────────────────────────────────────────

  /// Crea el usuario con nombre + usuario + email + password.
  Future<bool> crearUsuario({required String password}) async {
    if (estaCargando) return false;

    _setEstado(EstadoRegistro.cargando);

    try {
      await _repositorio.registrarUsuario(
        nombre: _nombreGuardado,
        usuario: _usuarioGuardado,   // ← pasa el username único
        email: _emailGuardado,
        passwordPlano: password,
      );

      _servicioEmail
          .enviarBienvenida(email: _emailGuardado, nombre: _nombreGuardado)
          .ignore();

      _paso = PasoRegistro.completado;
      _setEstado(EstadoRegistro.inactivo);
      return true;
    } on UsuarioYaExisteException catch (e) {
      _setError(e.mensaje);
      return false;
    } catch (_) {
      _setError('Error al crear la cuenta. Intenta de nuevo.');
      return false;
    }
  }

  // ─── Navegación ───────────────────────────────────────────────────────────

  void volverADatosIniciales() {
    _servicioVerificacion.cancelar(_emailGuardado);
    _paso = PasoRegistro.datosIniciales;
    _mensajeError = null;
    notifyListeners();
  }

  void reiniciar() {
    _servicioVerificacion.cancelar(_emailGuardado);
    _paso = PasoRegistro.datosIniciales;
    _nombreGuardado = '';
    _usuarioGuardado = '';
    _emailGuardado = '';
    _mensajeError = null;
    _estado = EstadoRegistro.inactivo;
    notifyListeners();
  }

  void limpiarError() {
    if (_mensajeError != null) {
      _mensajeError = null;
      notifyListeners();
    }
  }

  // ─── Helpers privados ─────────────────────────────────────────────────────

  void _setEstado(EstadoRegistro nuevoEstado) {
    _estado = nuevoEstado;
    notifyListeners();
  }

  void _setError(String mensaje) {
    _estado = EstadoRegistro.error;
    _mensajeError = mensaje;
    notifyListeners();
  }
}