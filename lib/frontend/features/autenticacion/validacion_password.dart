import '../../../backend/features/autenticacion/repositorio/repositorio_auth.dart';

/// Se reexporta para que una vista que valida contraseñas no tenga que
/// importar además el repositorio solo por el número.
export '../../../backend/features/autenticacion/repositorio/repositorio_auth.dart'
    show minimoCaracteresPassword;

/// La regla de contraseña para los formularios.
///
/// La usan la recuperación y el alta de cuentas. El mínimo sale de
/// [minimoCaracteresPassword], que es el que aplica el repositorio: aquí solo
/// se adelanta el aviso para no mandar a la base algo que va a rebotar.
String? validarPassword(String? valor) {
  if (valor == null || valor.length < minimoCaracteresPassword) {
    return 'La contraseña debe tener al menos $minimoCaracteresPassword '
        'caracteres.';
  }
  return null;
}
