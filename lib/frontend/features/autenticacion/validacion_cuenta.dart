/// Las validaciones de formulario que comparten el alta del primer
/// administrador y el alta de cuentas desde Configuración.
///
/// Son de cortesía: la unicidad real la garantizan el `UNIQUE` de `usuarios`
/// y el del correo en `personas` (`REGLAS_BD.md` §3.1). Lo que hacen aquí es
/// evitar un viaje a la base para decir algo que se sabe con mirar el texto.
library;

/// Mínimo y máximo salen de `TablaUsuario.usuario`, que es
/// `withLength(min: 3, max: 50)`.
String? validarUsuario(String? valor) {
  final limpio = (valor ?? '').trim();
  if (limpio.length < 3) {
    return 'El usuario debe tener al menos 3 caracteres.';
  }
  if (limpio.length > 50) return 'El usuario no puede pasar de 50 caracteres.';
  if (limpio.contains(RegExp(r'\s'))) {
    return 'El usuario no puede llevar espacios.';
  }
  return null;
}

/// Con `@` y un punto después basta: validar correos a fondo con una expresión
/// regular rechaza direcciones legítimas, y la que manda es la que recibe.
String? validarCorreoObligatorio(String? valor) {
  final limpio = (valor ?? '').trim();
  if (limpio.isEmpty) return 'El correo es obligatorio.';
  return _pareceCorreo(limpio) ? null : 'Ese correo no se ve bien escrito.';
}

/// Igual que [validarCorreoObligatorio] pero deja pasar el campo vacío.
String? validarCorreoOpcional(String? valor) {
  final limpio = (valor ?? '').trim();
  if (limpio.isEmpty) return null;
  return _pareceCorreo(limpio) ? null : 'Ese correo no se ve bien escrito.';
}

bool _pareceCorreo(String valor) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(valor);
