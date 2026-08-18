import '../../persona/modelo/persona.dart';

/// Un técnico del taller.
///
/// Igual que `Cliente`, expone la identidad aplanada aunque en la base viva en
/// `personas`. `nombreCompleto` e [iniciales] ya no se calculan aquí: los
/// hereda de [Persona], que es donde estaban duplicados.
class Tecnico extends Persona {
  const Tecnico({
    this.id,
    this.personaId,
    this.tipoDocumento = TipoDocumento.cc,
    this.documento,
    required this.nombres,
    this.apellidos,
    this.telefono,
    this.email,
    this.especializacionId,
    this.salarioBase,
    required this.activo,
    required this.creadoEn,
  });

  final int? id;

  @override
  final int? personaId;

  final TipoDocumento tipoDocumento;

  @override
  final String? documento;
  @override
  final String nombres;
  @override
  final String? apellidos;
  @override
  final String? telefono;
  @override
  final String? email;

  final int? especializacionId;
  final double? salarioBase;
  final bool activo;
  final DateTime creadoEn;

  /// La parte del técnico que se guarda en `personas`.
  DatosPersona get datosPersona => DatosPersona(
        personaId: personaId,
        tipoDocumento: tipoDocumento,
        documento: documento,
        nombres: nombres,
        apellidos: apellidos,
        telefono: telefono,
        email: email,
      );

  Tecnico copyWith({
    int? id,
    int? personaId,
    TipoDocumento? tipoDocumento,
    String? documento,
    String? nombres,
    String? apellidos,
    String? telefono,
    String? email,
    int? especializacionId,
    double? salarioBase,
    bool? activo,
    DateTime? creadoEn,
  }) {
    return Tecnico(
      id: id ?? this.id,
      personaId: personaId ?? this.personaId,
      tipoDocumento: tipoDocumento ?? this.tipoDocumento,
      documento: documento ?? this.documento,
      nombres: nombres ?? this.nombres,
      apellidos: apellidos ?? this.apellidos,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      especializacionId: especializacionId ?? this.especializacionId,
      salarioBase: salarioBase ?? this.salarioBase,
      activo: activo ?? this.activo,
      creadoEn: creadoEn ?? this.creadoEn,
    );
  }

  @override
  List<Object?> get props => [
        ...super.props,
        id,
        tipoDocumento,
        especializacionId,
        salarioBase,
        activo,
        creadoEn,
      ];
}
