class UsuarioYaExisteException implements Exception {
  final String mensaje;
  const UsuarioYaExisteException([
    this.mensaje = 'El correo ya está registrado.',
  ]);
  @override
  String toString() => mensaje;
}

class CredencialesInvalidasException implements Exception {
  final String mensaje;
  const CredencialesInvalidasException([
    this.mensaje = 'Correo o contraseña incorrectos.',
  ]);
  @override
  String toString() => mensaje;
}

class AccesoDesactivadoException implements Exception {
  final String mensaje;
  const AccesoDesactivadoException([
    this.mensaje = 'Tu acceso ha sido desactivado por el administrador.',
  ]);
  @override
  String toString() => mensaje;
}

class SinPermisosException implements Exception {
  final String mensaje;
  const SinPermisosException([
    this.mensaje = 'No tienes permisos para realizar esta acción.',
  ]);
  @override
  String toString() => mensaje;
}
