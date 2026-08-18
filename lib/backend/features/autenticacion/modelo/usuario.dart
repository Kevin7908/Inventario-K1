/// Una cuenta de acceso a la app.
///
/// `nombre` y `email` se leen de `personas`: la cuenta no los guarda por su
/// cuenta. No extiende `Persona` porque de la identidad solo usa esos dos
/// campos, y lo suyo es `usuario` y `passwordHash`.
class Usuario {
  const Usuario({
    this.id,
    this.personaId,
    required this.nombre,
    required this.usuario,
    required this.email,
    required this.passwordHash,
    this.esAdmin = false,
    this.estaActivo = true,
    required this.creadoEn,
  });

  final int? id;

  /// Id de la fila en `personas`. Lo que comparte con los demás roles.
  final int? personaId;

  final String nombre;
  final String usuario;
  final String email;
  final String passwordHash;
  final bool esAdmin;
  final bool estaActivo;
  final DateTime creadoEn;

  Usuario copyWith({
    int? id,
    int? personaId,
    String? nombre,
    String? usuario,
    String? email,
    String? passwordHash,
    bool? esAdmin,
    bool? estaActivo,
    DateTime? creadoEn,
  }) {
    return Usuario(
      id: id ?? this.id,
      personaId: personaId ?? this.personaId,
      nombre: nombre ?? this.nombre,
      usuario: usuario ?? this.usuario,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      esAdmin: esAdmin ?? this.esAdmin,
      estaActivo: estaActivo ?? this.estaActivo,
      creadoEn: creadoEn ?? this.creadoEn,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Usuario && id != null && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Usuario(id: $id, nombre: $nombre, usuario: $usuario, '
      'email: $email, esAdmin: $esAdmin, estaActivo: $estaActivo)';
}
