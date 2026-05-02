import 'dart:math';

/// Resultado de una solicitud de código de verificación.
enum ResultadoEnvioCodigo {
  enviado,
  emailYaRegistrado,
  errorEnvio,
}

/// Modelo interno que guarda un código y su fecha de expiración.
class _EntradaCodigo {
  final String codigo;
  final DateTime expira;

  _EntradaCodigo(this.codigo, this.expira);

  bool get estaVigente => DateTime.now().isBefore(expira);
}

/// Servicio en memoria para generar, almacenar y validar códigos OTP de 6 dígitos.
///
/// - Los códigos expiran a los 10 minutos.
/// - Máximo 3 intentos fallidos por email antes de invalidar el código.
/// - No persiste en disco: si la app se reinicia, el código se pierde.
///
/// Uso:
/// ```dart
/// final codigo = servicioVerificacion.generarCodigo(email);
/// // enviar código por correo...
/// final valido = servicioVerificacion.validarCodigo(email, codigoIngresado);
/// ```
class ServicioVerificacion {
  /// email.toLowerCase() → entrada con código y expiración
  final Map<String, _EntradaCodigo> _codigos = {};

  /// Contador de intentos fallidos por email
  final Map<String, int> _intentosFallidos = {};

  static const _maxIntentos = 3;
  static const _minutosExpiracion = 10;

  final Random _rng = Random.secure();

  // ─── Generar código ────────────────────────────────────────────────────────

  /// Genera un código OTP de 6 dígitos para el [email] dado.
  /// Si ya existía uno previo, lo sobreescribe (re-envío).
  /// Retorna el código generado para que el llamador lo envíe por correo.
  String generarCodigo(String email) {
    final clave = email.toLowerCase().trim();

    // Generar número entre 100000 y 999999
    final codigo = (100000 + _rng.nextInt(900000)).toString();

    _codigos[clave] = _EntradaCodigo(
      codigo,
      DateTime.now().add(const Duration(minutes: _minutosExpiracion)),
    );

    // Resetear intentos al generar un código nuevo
    _intentosFallidos.remove(clave);

    return codigo;
  }

  // ─── Validar código ────────────────────────────────────────────────────────

  /// Valida el [codigoIngresado] para el [email] dado.
  ///
  /// Retorna [ResultadoValidacion] con el resultado:
  /// - [ResultadoValidacion.valido] si el código es correcto y vigente.
  /// - [ResultadoValidacion.invalido] si el código no coincide.
  /// - [ResultadoValidacion.expirado] si pasaron los 10 minutos.
  /// - [ResultadoValidacion.maxIntentosAlcanzado] si se superaron 3 intentos.
  /// - [ResultadoValidacion.noExiste] si nunca se generó un código.
  ResultadoValidacion validarCodigo(String email, String codigoIngresado) {
    final clave = email.toLowerCase().trim();
    final entrada = _codigos[clave];

    if (entrada == null) return ResultadoValidacion.noExiste;
    if (!entrada.estaVigente) {
      _limpiar(clave);
      return ResultadoValidacion.expirado;
    }

    final intentos = _intentosFallidos[clave] ?? 0;
    if (intentos >= _maxIntentos) {
      _limpiar(clave);
      return ResultadoValidacion.maxIntentosAlcanzado;
    }

    if (entrada.codigo == codigoIngresado.trim()) {
      // Código correcto → limpiar para que no se pueda reutilizar
      _limpiar(clave);
      return ResultadoValidacion.valido;
    }

    // Código incorrecto → incrementar intentos
    _intentosFallidos[clave] = intentos + 1;
    return ResultadoValidacion.invalido;
  }

  // ─── Tiempo restante ───────────────────────────────────────────────────────

  /// Segundos restantes para que expire el código, o 0 si no existe/expiró.
  int segundosRestantes(String email) {
    final clave = email.toLowerCase().trim();
    final entrada = _codigos[clave];
    if (entrada == null || !entrada.estaVigente) return 0;
    return entrada.expira.difference(DateTime.now()).inSeconds;
  }

  /// Intentos fallidos restantes antes de invalidar el código.
  int intentosRestantes(String email) {
    final clave = email.toLowerCase().trim();
    final intentos = _intentosFallidos[clave] ?? 0;
    return (_maxIntentos - intentos).clamp(0, _maxIntentos);
  }

  // ─── Limpiar ───────────────────────────────────────────────────────────────

  void _limpiar(String clave) {
    _codigos.remove(clave);
    _intentosFallidos.remove(clave);
  }

  /// Limpia manualmente el código de un email (ej: al cancelar el registro).
  void cancelar(String email) {
    _limpiar(email.toLowerCase().trim());
  }
}

// ─── Enum de resultado de validación ─────────────────────────────────────────

enum ResultadoValidacion {
  valido,
  invalido,
  expirado,
  maxIntentosAlcanzado,
  noExiste;

  String get mensaje {
    switch (this) {
      case ResultadoValidacion.valido:
        return 'Código verificado correctamente.';
      case ResultadoValidacion.invalido:
        return 'Código incorrecto. Verifica e intenta de nuevo.';
      case ResultadoValidacion.expirado:
        return 'El código ha expirado. Solicita uno nuevo.';
      case ResultadoValidacion.maxIntentosAlcanzado:
        return 'Demasiados intentos fallidos. Solicita un código nuevo.';
      case ResultadoValidacion.noExiste:
        return 'No hay un código activo para este correo.';
    }
  }
}