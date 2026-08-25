import '../modelo/usuario.dart';

/// Cómo terminó un intento de entrar a la app.
///
/// Es un tipo sellado y no una excepción con mensaje porque la vista necesita
/// **distinguir** los casos para reaccionar distinto: credenciales malas
/// vuelven a pedir la contraseña, una cuenta desactivada manda a hablar con el
/// administrador. Con un `String` habría que comparar textos para saberlo
/// (`CLAUDE.md` §7).
sealed class ResultadoAcceso {
  const ResultadoAcceso();
}

final class AccesoConcedido extends ResultadoAcceso {
  const AccesoConcedido(this.usuario);

  final Usuario usuario;
}

/// No existe ese usuario/correo, o la contraseña no coincide.
///
/// **Los dos casos dan el mismo resultado a propósito.** Distinguirlos le
/// diría a cualquiera qué usuarios existen, que es la mitad del trabajo de
/// quien intenta entrar sin permiso.
final class CredencialesIncorrectas extends ResultadoAcceso {
  const CredencialesIncorrectas();
}

/// La cuenta existe y la contraseña es correcta, pero está desactivada.
final class CuentaDesactivada extends ResultadoAcceso {
  const CuentaDesactivada();
}

/// Cómo terminó la creación de una cuenta.
sealed class ResultadoCuenta {
  const ResultadoCuenta();
}

final class CuentaCreada extends ResultadoCuenta {
  const CuentaCreada(this.usuario);

  final Usuario usuario;
}

final class UsuarioEnUso extends ResultadoCuenta {
  const UsuarioEnUso();
}

final class CorreoEnUso extends ResultadoCuenta {
  const CorreoEnUso();
}

/// El documento ya está en `personas` con otra cuenta asociada, o la base
/// rechazó la escritura.
final class CuentaNoGuardada extends ResultadoCuenta {
  const CuentaNoGuardada(this.detalle);

  final String detalle;
}
