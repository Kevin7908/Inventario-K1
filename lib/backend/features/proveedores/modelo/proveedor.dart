import '../../persona/modelo/persona.dart';

/// Un proveedor del taller.
///
/// No extiende [Persona] a propósito: casi siempre es una empresa, y llamar
/// `nombres` a la razón social y `documento` al NIT haría peor su código. En
/// la base sí comparte la tabla `personas` con los demás roles —`nombre` va a
/// `personas.nombres` y `nitCedula` a `personas.documento` con
/// `tipo_documento = 'NIT'`—, que es lo que evita tener el mismo teléfono
/// escrito en dos sitios.
class Proveedor {
  const Proveedor({
    this.id,
    this.personaId,
    required this.nombre,
    this.nitCedula,
    this.contacto,
    this.telefono,
    this.email,
    this.direccion,
    this.ciudad,
    this.notas,
    required this.activo,
    this.creadoEn,
    this.actualizadoEn,
  });

  final int? id;

  /// Id de la fila en `personas`. Lo que comparte con los demás roles.
  final int? personaId;

  /// Razón social, o nombre de la persona si es natural.
  final String nombre;

  final String? nitCedula;

  /// Nombre de la persona con la que se habla en esa empresa. Es un dato de
  /// agenda, no alguien con quien el taller tenga relación propia.
  final String? contacto;

  final String? telefono;
  final String? email;
  final String? direccion;
  final String? ciudad;
  final String? notas;
  final bool activo;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

  /// La parte del proveedor que se guarda en `personas`.
  DatosPersona get datosPersona => DatosPersona(
        personaId: personaId,
        tipoDocumento: TipoDocumento.nit,
        documento: nitCedula,
        nombres: nombre,
        telefono: telefono,
        email: email,
        direccion: direccion,
        ciudad: ciudad,
      );

  Proveedor copyWith({
    int? id,
    int? personaId,
    String? nombre,
    String? nitCedula,
    String? contacto,
    String? telefono,
    String? email,
    String? direccion,
    String? ciudad,
    String? notas,
    bool? activo,
    DateTime? creadoEn,
    DateTime? actualizadoEn,
  }) {
    return Proveedor(
      id: id ?? this.id,
      personaId: personaId ?? this.personaId,
      nombre: nombre ?? this.nombre,
      nitCedula: nitCedula ?? this.nitCedula,
      contacto: contacto ?? this.contacto,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      direccion: direccion ?? this.direccion,
      ciudad: ciudad ?? this.ciudad,
      notas: notas ?? this.notas,
      activo: activo ?? this.activo,
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
