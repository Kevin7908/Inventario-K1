import '../../persona/modelo/persona.dart'; // Asegúrate que esta ruta sea la correcta

class Cliente extends Persona {
  final int id;
  final String? cedula;
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
  final String? fechaNacimiento;
  final String? notas;
  final bool activo;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

  const Cliente({
    required this.id,
    this.cedula,
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

  static const _omitido = Object();

  Cliente copyWith({
    int? id,
    Object? cedula = _omitido,
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
      cedula: cedula == _omitido ? this.cedula : cedula as String?,
      nombres: nombres ?? this.nombres,
      apellidos: apellidos == _omitido ? this.apellidos : apellidos as String?,
      telefono: telefono == _omitido ? this.telefono : telefono as String?,
      email: email == _omitido ? this.email : email as String?,
      direccion: direccion == _omitido ? this.direccion : direccion as String?,
      ciudad: ciudad == _omitido ? this.ciudad : ciudad as String?,
      fechaNacimiento: fechaNacimiento == _omitido
          ? this.fechaNacimiento
          : fechaNacimiento as String?,
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
    cedula,
    direccion,
    ciudad,
    fechaNacimiento,
    notas,
    activo,
    creadoEn,
    actualizadoEn,
  ];
}
