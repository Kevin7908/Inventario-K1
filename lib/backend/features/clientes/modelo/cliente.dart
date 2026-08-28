import '../../persona/modelo/persona.dart';

/// Un cliente del taller.
///
/// Expone los datos de identidad aplanados —`documento`, `nombres`,
/// `telefono`…— aunque en la base vivan en `personas`: para quien consume el
/// modelo, un cliente sigue teniendo nombre y cédula. Lo que cambió es que ya
/// no son *suyos*, sino de la persona detrás, y por eso están en [Persona].
class Cliente extends Persona {
  const Cliente({
    required this.id,
    this.personaId,
    this.tipoDocumento = TipoDocumento.cc,
    this.documento,
    required this.nombres,
    this.apellidos,
    this.telefono,
    this.email,
    this.direccion,
    this.ciudad,
    this.fechaNacimiento,
    this.notas,
    required this.activo,
    this.creadoEn,
    this.actualizadoEn,
  });

  /// Id de la fila en `clientes`. `0` mientras no se haya guardado.
  final int id;

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

  final String? direccion;
  final String? ciudad;
  final DateTime? fechaNacimiento;
  final String? notas;
  final bool activo;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

  /// La parte del cliente que se guarda en `personas`.
  ///
  /// El repositorio la escribe primero y usa el id que devuelve como
  /// `persona_id` de la fila de `clientes`.
  DatosPersona get datosPersona => DatosPersona(
        personaId: personaId,
        tipoDocumento: tipoDocumento,
        documento: documento,
        nombres: nombres,
        apellidos: apellidos,
        telefono: telefono,
        email: email,
        direccion: direccion,
        ciudad: ciudad,
      );

  static const _omitido = Object();

  Cliente copyWith({
    int? id,
    Object? personaId = _omitido,
    TipoDocumento? tipoDocumento,
    Object? documento = _omitido,
    String? nombres,
    Object? apellidos = _omitido,
    Object? telefono = _omitido,
    Object? email = _omitido,
    Object? direccion = _omitido,
    Object? ciudad = _omitido,
    Object? fechaNacimiento = _omitido,
    Object? notas = _omitido,
    bool? activo,
    Object? creadoEn = _omitido,
    Object? actualizadoEn = _omitido,
  }) {
    return Cliente(
      id: id ?? this.id,
      personaId: personaId == _omitido ? this.personaId : personaId as int?,
      tipoDocumento: tipoDocumento ?? this.tipoDocumento,
      documento: documento == _omitido ? this.documento : documento as String?,
      nombres: nombres ?? this.nombres,
      apellidos: apellidos == _omitido ? this.apellidos : apellidos as String?,
      telefono: telefono == _omitido ? this.telefono : telefono as String?,
      email: email == _omitido ? this.email : email as String?,
      direccion: direccion == _omitido ? this.direccion : direccion as String?,
      ciudad: ciudad == _omitido ? this.ciudad : ciudad as String?,
      fechaNacimiento: fechaNacimiento == _omitido
          ? this.fechaNacimiento
          : fechaNacimiento as DateTime?,
      notas: notas == _omitido ? this.notas : notas as String?,
      activo: activo ?? this.activo,
      creadoEn: creadoEn == _omitido ? this.creadoEn : creadoEn as DateTime?,
      actualizadoEn: actualizadoEn == _omitido
          ? this.actualizadoEn
          : actualizadoEn as DateTime?,
    );
  }

  @override
  List<Object?> get props => [
        ...super.props,
        id,
        tipoDocumento,
        direccion,
        ciudad,
        fechaNacimiento,
        notas,
        activo,
        creadoEn,
        actualizadoEn,
      ];
}
