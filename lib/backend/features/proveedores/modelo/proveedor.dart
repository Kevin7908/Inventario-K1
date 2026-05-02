class Proveedor {
  final int? id;
  final String nombre;
  final String? nitCedula;
  final String? contacto;
  final String? telefono;
  final String? email;
  final String? direccion;
  final String? ciudad;
  final String? notas;
  final bool activo;
  final String colorHex;
  final String icono;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

  const Proveedor({
    this.id,
    required this.nombre,
    this.nitCedula,
    this.contacto,
    this.telefono,
    this.email,
    this.direccion,
    this.ciudad,
    this.notas,
    required this.activo,
    required this.colorHex,
    required this.icono,
    this.creadoEn,
    this.actualizadoEn,
  });
  Proveedor copyWith({
    final int? id,
    final String? nombre,
    final String? nitCedula,
    final String? contacto,
    final String? telefono,
    final String? email,
    final String? direccion,
    final String? ciudad,
    final String? notas,
    final bool? activo,
    final String? colorHex,
    final String? icono,
    final DateTime? creadoEn,
    final DateTime? actualizadoEn,
  }) {
    return Proveedor(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      nitCedula: nitCedula ?? this.nitCedula,
      contacto: contacto ?? this.contacto,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      direccion: direccion ?? this.direccion,
      ciudad: ciudad ?? this.ciudad,
      notas: notas ?? this.notas,
      activo: activo ?? this.activo,
      colorHex: colorHex ?? this.colorHex,
      icono: icono ?? this.icono,
      creadoEn: creadoEn ?? this.creadoEn,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Proveedor && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
