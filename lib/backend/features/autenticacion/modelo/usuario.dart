import '../../../share/dominio/rol_usuario.dart';

/// Una cuenta de acceso a la app.
///
/// `nombre` y `email` se leen de `personas`: la cuenta no los guarda por su
/// cuenta. No extiende `Persona` porque de la identidad solo usa esos dos
/// campos, y lo suyo es `usuario`, `rol` y `passwordHash`.
class Usuario {
  const Usuario({
    required this.id,
    required this.personaId,
    required this.nombre,
    required this.usuario,
    required this.email,
    required this.rol,
    required this.estaActivo,
    required this.creadoEn,
  });

  final int id;

  /// Id de la fila en `personas`. Lo que comparte con los demás roles.
  final int personaId;

  final String nombre;
  final String usuario;

  /// Cadena vacía si la persona no tiene correo. Sin él no se puede recuperar
  /// la contraseña, y la pantalla de Usuarios lo señala.
  final String email;

  final RolUsuario rol;
  final bool estaActivo;
  final DateTime creadoEn;

  /// El hash **no** está aquí a propósito: este modelo viaja a la vista, y lo
  /// único que hace falta arriba es saber quién entró. Comparar contraseñas es
  /// trabajo del repositorio.
  bool get esAdmin => rol == RolUsuario.admin;

  bool get tieneCorreo => email.isNotEmpty;

  /// Iniciales para el avatar: la primera letra del primer nombre y la del
  /// último apellido.
  String get iniciales {
    final partes = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();

    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
    return (partes.first.substring(0, 1) + partes.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Usuario &&
          other.id == id &&
          other.nombre == nombre &&
          other.usuario == usuario &&
          other.email == email &&
          other.rol == rol &&
          other.estaActivo == estaActivo;

  @override
  int get hashCode => Object.hash(id, nombre, usuario, email, rol, estaActivo);

  @override
  String toString() =>
      'Usuario(id: $id, nombre: $nombre, usuario: $usuario, '
      'email: $email, rol: ${rol.codigo}, estaActivo: $estaActivo)';
}
