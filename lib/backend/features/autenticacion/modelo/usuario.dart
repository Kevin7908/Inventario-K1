class Usuario {
  final int? id;
  final String nombre;
  final String usuario; 
  final String email;
  final String passwordHash;
  final bool esAdmin;
  final bool estaActivo;
  final DateTime creadoEn;

  const Usuario({
    this.id,
    required this.nombre,
    required this.usuario,
    required this.email,
    required this.passwordHash,
    this.esAdmin = false,
    this.estaActivo = true,
    required this.creadoEn,
  });

  Usuario copyWith({
    int? id,
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